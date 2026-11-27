#!/usr/bin/env python3
"""Emit KDE Connect paired-device snapshots when its D-Bus state changes."""
import ctypes
import json
import os
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
        try:
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
                pass
            devices.append(dict(id=ident, name=str(name), type=str(kind), reachable=reachable,
                                battery=battery, charging=charging))
        except (RuntimeError, ValueError, TypeError):
            continue
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
    import re
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


def monitor_events(proc):
    """Yield relevant monitor lines using only unbuffered fd reads."""
    fd = proc.stdout.fileno()
    os.set_blocking(fd, False)
    buffer = b""
    while True:
        ready, _, _ = select.select([fd], [], [], 1)
        if not ready:
            if proc.poll() is not None:
                return
            continue
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            continue
        if not chunk:
            return
        buffer += chunk
        while b"\n" in buffer:
            raw, buffer = buffer.split(b"\n", 1)
            line = raw.decode("utf-8", "replace")
            if relevant_line(line):
                yield line


def debounce(proc, first_event, window=0.15, maximum=0.5):
    """Coalesce a burst, with a hard deadline under a continuous event stream."""
    started = first_event
    deadline = min(started + window, started + maximum)
    fd = proc.stdout.fileno()
    buffer = b""
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            break
        try:
            chunk = os.read(fd, 65536)
        except BlockingIOError:
            continue
        if not chunk:
            return False
        buffer += chunk
        while b"\n" in buffer:
            raw, buffer = buffer.split(b"\n", 1)
            line = raw.decode("utf-8", "replace")
            owner = owner_event(line)
            if owner:
                return owner
            if relevant_line(line):
                deadline = min(time.monotonic() + window, started + maximum)
    return True


def main():
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    if not shutil.which("kdeconnect-cli") or not shutil.which("busctl"):
        emit({"installed": False, "devices": []})
        return 0
    previous = None
    restart_delay = 1
    owner_missing = False
    while True:
        if not owner_missing:
            try:
                state = snapshot()
            except (RuntimeError, ValueError, OSError):
                state = {"installed": True, "devices": []}
            previous = emit_if_changed(state, previous)
        proc = spawn(["gdbus", "monitor", "--session", "--dest", BUS], stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            first = None
            for line in monitor_events(proc):
                owner = owner_event(line)
                if owner == "owned":
                    owner_missing = False
                    try:
                        state = snapshot()
                    except (RuntimeError, ValueError, OSError):
                        state = {"installed": True, "devices": []}
                    previous = emit_if_changed(state, previous)
                    first = None
                    continue
                if owner == "missing":
                    owner_missing = True
                    previous = emit_if_changed({"installed": True, "devices": []}, previous)
                    first = None
                    continue
                if first is None:
                    first = time.monotonic()
                    result = debounce(proc, first)
                    if result == "missing":
                        owner_missing = True
                        previous = emit_if_changed({"installed": True, "devices": []}, previous)
                        first = None
                        continue
                    if result == "owned":
                        owner_missing = False
                        try:
                            state = snapshot()
                        except (RuntimeError, ValueError, OSError):
                            state = {"installed": True, "devices": []}
                        previous = emit_if_changed(state, previous)
                        first = None
                        continue
                    if not result:
                        break
                    if owner_missing:
                        first = None
                        continue
                    try:
                        state = snapshot()
                    except (RuntimeError, ValueError, OSError):
                        state = {"installed": True, "devices": []}
                    previous = emit_if_changed(state, previous)
                    first = None
        finally:
            children.discard(proc)
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    proc.kill()
        # The monitor itself reports when the well-known name disappears or returns.
        time.sleep(min(restart_delay, 30))
        restart_delay = min(restart_delay * 2, 30)


if __name__ == "__main__":
    sys.exit(main())
