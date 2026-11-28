#!/usr/bin/env python3
"""Emit KDE Connect paired-device snapshots when its D-Bus state changes."""
import ctypes
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import time

BUS = "org.kde.kdeconnect"
BASE = "/modules/kdeconnect"
DAEMON_IFACE = "org.kde.kdeconnect.daemon"
DEVICE_IFACE = "org.kde.kdeconnect.device"
BATTERY_IFACE = "org.kde.kdeconnect.device.battery"
children = set()
PDEATHSIG = getattr(signal, "SIGKILL", 9)


def _parent_death_signal():
    """Make every subprocess inherit a kernel-enforced parent death signal."""
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(1, PDEATHSIG, 0, 0, 0) != 0:  # PR_SET_PDEATHSIG
        os._exit(127)
    # Cover the race where the parent dies before prctl is installed.
    if os.getppid() == 1:
        os.kill(os.getpid(), PDEATHSIG)


def spawn(args, **kwargs):
    proc = subprocess.Popen(args, preexec_fn=_parent_death_signal, **kwargs)
    children.add(proc)
    return proc


def run(args, timeout=5):
    """Run an argument vector; return stdout, or raise RuntimeError."""
    proc = spawn(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
    finally:
        children.discard(proc)
    if proc.returncode:
        raise RuntimeError(err.strip() or "busctl command failed")
    return out.strip()


def busctl_json(*args):
    try:
        return json.loads(run(["busctl", "--user", "--json=short", *args]))["data"]
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise ValueError("malformed busctl JSON output") from exc


def prop(path, interface, name):
    return busctl_json("get-property", BUS, path, interface, name)


def snapshot():
    ids = busctl_json("call", BUS, BASE, DAEMON_IFACE, "devices", "bb", "false", "true")
    # busctl call replies put the method's out arguments in data; devices has
    # one out argument, an array of device ids.
    if isinstance(ids, list) and len(ids) == 1 and isinstance(ids[0], list):
        ids = ids[0]
    if not isinstance(ids, list) or not all(isinstance(i, str) for i in ids):
        raise ValueError("malformed device list output")
    devices = []
    for ident in ids:
        path = BASE + "/devices/" + ident
        # A required property that cannot be read raises: the snapshot would be incomplete.
        if not prop(path, DEVICE_IFACE, "isPaired"):
            continue
        name = prop(path, DEVICE_IFACE, "name")
        kind = prop(path, DEVICE_IFACE, "type")
        reachable = bool(prop(path, DEVICE_IFACE, "isReachable"))
        battery, charging = -1, False
        try:
            bat = path + "/battery"
            if prop(bat, BATTERY_IFACE, "hasBattery"):
                battery = int(prop(bat, BATTERY_IFACE, "charge"))
                charging = bool(prop(bat, BATTERY_IFACE, "isCharging"))
        except (RuntimeError, ValueError, TypeError):
            pass  # no battery object is a normal answer
        devices.append(dict(id=ident, name=str(name), type=str(kind), reachable=reachable,
                            battery=battery, charging=charging))
    return {"installed": True, "devices": sorted(devices, key=lambda d: (d["name"].casefold(), d["id"]))}


def terminate(*_):
    for child in tuple(children):
        try:
            child.terminate()
        except OSError:
            pass
    for child in tuple(children):
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
        except OSError:
            pass
    raise SystemExit(0)


def state_key(state):
    return json.dumps(state, sort_keys=True, separators=(",", ":"))


def emit(state):
    print(json.dumps(state, separators=(",", ":"), ensure_ascii=True), flush=True)


def emit_if_changed(state, previous):
    key = state_key(state)
    if key != previous:
        emit(state)
        return key
    return previous


def relevant_line(line):
    if owner_event(line):
        return True
    match = re.match(r"^\S+: (\S+)\.(\w+) \(", line)
    if not match:
        return False
    interface, signal_name = match.groups()
    if interface == DAEMON_IFACE:
        return signal_name in {"deviceAdded", "deviceRemoved", "deviceVisibilityChanged",
                               "deviceListChanged", "pairingRequestsChanged"}
    if interface == DEVICE_IFACE:
        return signal_name in {"reachableChanged", "pairStateChanged", "nameChanged",
                               "typeChanged", "pluginsChanged"}
    if interface == BATTERY_IFACE:
        return signal_name == "refreshed"
    if interface == "org.freedesktop.DBus.Properties" and signal_name == "PropertiesChanged":
        match = re.match(r"^(/modules/kdeconnect/devices/\S+): .*PropertiesChanged \('([^']+)'", line)
        return bool(match and match.group(1).startswith(BASE + "/devices/")
                    and match.group(2) in {DEVICE_IFACE, BATTERY_IFACE})
    return False


def owner_event(line):
    if line == "The name org.kde.kdeconnect does not have an owner":
        return "missing"
    if line.startswith("The name org.kde.kdeconnect is owned by "):
        return "owned" if line.rsplit(" ", 1)[-1].startswith(":") else None
    return None


class Scheduler:
    """Decides when the next snapshot is due. Times are seconds from a monotonic clock."""
    STARTUP = 1.0  # fallback if the monitor never announces the owner
    QUIET = 0.15   # a burst of signals is coalesced until this long after the last one...
    LIMIT = 0.5    # ...but never later than this after the first one

    def __init__(self, now):
        self.owner_missing = False
        self.due = now + self.STARTUP
        self.first = None
        self.retry = 1

    def line(self, text, now):
        """Take one monitor line; True when the empty state must be published."""
        owner = owner_event(text)
        if owner == "missing":
            self.owner_missing = True
            self.succeeded()
            return True
        if owner == "owned":
            self.owner_missing = False
            self.succeeded()
            self.due = now
        elif not self.owner_missing and relevant_line(text):
            if self.first is None:
                self.first = now
            self.due = min(now + self.QUIET, self.first + self.LIMIT)
        return False

    def succeeded(self):
        self.due = None
        self.first = None
        self.retry = 1

    def failed(self, now):
        self.first = None
        self.due = now + self.retry
        self.retry = min(self.retry * 2, 30)

    def timeout(self, now):
        return None if self.due is None else max(0, self.due - now)

    def ready(self, now):
        return self.due is not None and now >= self.due


def watch(proc, previous):
    """Follow one monitor process until it ends. The only reader of its pipe, so lines stay in order."""
    fd = proc.stdout.fileno()
    schedule = Scheduler(time.monotonic())
    buffer = b""
    while True:
        # With nothing due this blocks until the next line: no idle wake-ups.
        readable, _, _ = select.select([fd], [], [], schedule.timeout(time.monotonic()))
        if readable:
            chunk = os.read(fd, 65536)
            if not chunk:
                return previous
            buffer += chunk
            while b"\n" in buffer:
                raw, buffer = buffer.split(b"\n", 1)
                if schedule.line(raw.decode("utf-8", "replace"), time.monotonic()):
                    previous = emit_if_changed({"installed": True, "devices": []}, previous)
        if schedule.ready(time.monotonic()):
            try:
                # An incomplete snapshot raises: the last good state stays and it is tried again.
                previous = emit_if_changed(snapshot(), previous)
                schedule.succeeded()
            except (RuntimeError, ValueError, OSError):
                schedule.failed(time.monotonic())


def main():
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    if not all(shutil.which(tool) for tool in ("kdeconnect-cli", "busctl", "gdbus")):
        emit({"installed": False, "devices": []})
        return 0
    previous = None
    restart_delay = 1
    while True:
        # The monitor starts before the first snapshot, so no change falls between the two.
        proc = spawn(["gdbus", "monitor", "--session", "--dest", BUS], stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            previous = watch(proc, previous)
        finally:
            children.discard(proc)
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    proc.kill()
        time.sleep(restart_delay)
        restart_delay = min(restart_delay * 2, 30)


if __name__ == "__main__":
    sys.exit(main())
