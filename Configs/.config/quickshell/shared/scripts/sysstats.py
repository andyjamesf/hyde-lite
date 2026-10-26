#!/usr/bin/env python3
"""PC statistics for the island's System page (services/SysStats.qml), one JSON line every
INTERVAL seconds (default 2) while it runs. Only /proc and /sys are read (no extra packages).

    sysstats.py [INTERVAL]

Each line: {
  "cpu": {"model", "percent", "cores": [percent…], "freq": MHz, "load": [1, 5, 15 min]},
  "memory": {"used", "total", "apps", "cache", "free", "available", "shared",
             "swapUsed", "swapTotal"},                               (bytes)
  "temps": [{"name", "celsius"}…],                                   (one per sensor chip)
  "gpu": {"percent", "vramUsed", "vramTotal"} or null,
  "disks": [{"mount", "used", "total"}…],
  "net": {"rx", "tx"},                                               (bytes per second)
  "diskio": {"read", "write"},                                       (bytes per second)
  "power": watts drawn from the battery (0 on AC) or null,
  "uptime": seconds, "counts": {"processes", "threads"},
  "processes": [{"pid", "name", "cpu", "memory", "threads"}…]        (top 10 by CPU)
  "processesByMemory": […]                                            (top 10 by memory)
}
"""
import glob
import json
import os
import sys
import time

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
TICKS = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
# hwmon chip → friendly name (others keep their own name).
CHIPS = {"k10temp": "CPU", "coretemp": "CPU", "zenpower": "CPU", "amdgpu": "GPU", "nvme": "SSD",
         "spd5118": "Memory", "acpitz": "Board", "iwlwifi_1": "Wi-Fi", "mt7921_phy0": "Wi-Fi"}


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def cpu_times():
    out = []
    for line in read("/proc/stat").splitlines():
        if line.startswith("cpu"):
            v = [int(x) for x in line.split()[1:]]
            idle = v[3] + v[4]
            out.append((sum(v), idle))
    return out


def cpu_model():
    for line in read("/proc/cpuinfo").splitlines():
        if line.startswith("model name"):
            return line.split(":", 1)[1].strip()
    return ""


def freq_mhz():
    vals = [int(read(p, "0")) for p in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq")]
    return round(sum(vals) / len(vals) / 1000) if vals else 0


def memory():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        m[k] = int(v.split()[0]) * 1024
    total, free = m.get("MemTotal", 0), m.get("MemFree", 0)
    cache = m.get("Buffers", 0) + m.get("Cached", 0) + m.get("SReclaimable", 0) - m.get("Shmem", 0)
    return {"used": total - m.get("MemAvailable", 0), "total": total,
            # Split for the bar: programs, disk cache (freed when needed) and truly free.
            "apps": max(0, total - free - cache), "cache": max(0, cache), "free": free,
            "available": m.get("MemAvailable", 0), "shared": m.get("Shmem", 0),
            "swapUsed": m.get("SwapTotal", 0) - m.get("SwapFree", 0), "swapTotal": m.get("SwapTotal", 0)}


def temps():
    out = []
    for hw in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        chip = read(f"{hw}/name")
        if chip.startswith(("BAT", "ucsi")):
            continue
        values = []
        for t in sorted(glob.glob(f"{hw}/temp*_input")):
            v = read(t)
            if v.lstrip("-").isdigit():
                label = read(t.replace("_input", "_label"))
                values.append((label, int(v) / 1000))
        if not values:
            continue
        # The chip's main reading: Tctl/edge/Composite when labelled, else the first.
        main = next((v for label, v in values if label in ("Tctl", "Tdie", "edge", "Composite", "Package id 0")), values[0][1])
        name = CHIPS.get(chip, chip)
        if any(o["name"] == name for o in out):
            name = f"{name} ({chip})"
        out.append({"name": name, "celsius": round(main, 1)})
    return out


def gpu():
    for card in sorted(glob.glob("/sys/class/drm/card*/device")):
        busy = read(f"{card}/gpu_busy_percent")
        if busy.isdigit():
            return {"percent": int(busy), "vramUsed": int(read(f"{card}/mem_info_vram_used", "0")),
                    "vramTotal": int(read(f"{card}/mem_info_vram_total", "0"))}
    return None


def disks():
    out, seen = [], set()
    for line in read("/proc/mounts").splitlines():
        dev, mount, fs = line.split()[:3]
        if not dev.startswith("/dev/") or fs in ("squashfs", "iso9660") or mount.startswith(("/boot", "/efi", "/snap", "/var/lib/docker")):
            continue
        try:
            st = os.statvfs(mount)
        except OSError:
            continue
        key = (st.f_blocks, st.f_bfree)
        if key in seen:  # btrfs subvolumes of one filesystem
            continue
        seen.add(key)
        total = st.f_blocks * st.f_frsize
        out.append({"mount": mount, "used": total - st.f_bavail * st.f_frsize, "total": total})
    return out[:4]


def net_bytes():
    rx = tx = 0
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        if name.strip() == "lo":
            continue
        v = rest.split()
        rx, tx = rx + int(v[0]), tx + int(v[8])
    return rx, tx


def disk_bytes():
    r = w = 0
    for line in read("/proc/diskstats").splitlines():
        v = line.split()
        name = v[2]
        # Whole disks only (nvme0n1, sda), not partitions.
        if (name.startswith("nvme") and "p" not in name[4:]) or (name[:2] in ("sd", "vd") and not name[-1].isdigit()):
            r, w = r + int(v[5]) * 512, w + int(v[9]) * 512
    return r, w


def power():
    for bat in glob.glob("/sys/class/power_supply/BAT*"):
        if read(f"{bat}/status") != "Discharging":
            return 0
        p = read(f"{bat}/power_now")
        if p.isdigit():
            return round(int(p) / 1e6, 1)
        cur, volt = read(f"{bat}/current_now"), read(f"{bat}/voltage_now")
        if cur.isdigit() and volt.isdigit():
            return round(int(cur) * int(volt) / 1e12, 1)
    return None


def proc_times():
    out = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        s = read(f"/proc/{d}/stat")
        if not s:
            continue
        name = s[s.find("(") + 1:s.rfind(")")]
        v = s[s.rfind(")") + 2:].split()
        # utime + stime, resident memory, threads.
        out[d] = (name, int(v[11]) + int(v[12]), int(v[21]) * PAGE, int(v[17]))
    return out


def main():
    model = cpu_model()
    prev_cpu, prev_net, prev_io, prev_procs, prev_t = cpu_times(), net_bytes(), disk_bytes(), proc_times(), time.monotonic()
    ncpu = max(1, len(prev_cpu) - 1)
    # The first reading comes quickly (the page shows it at once); then every INTERVAL.
    wait = min(INTERVAL, 0.35)
    while True:
        time.sleep(wait)
        wait = INTERVAL
        now = time.monotonic()
        dt = max(0.001, now - prev_t)
        cpu = cpu_times()
        pct = [round(100 * (1 - (i2 - i1) / max(1, t2 - t1)), 1) for (t1, i1), (t2, i2) in zip(prev_cpu, cpu, strict=False)]
        net, io, procs = net_bytes(), disk_bytes(), proc_times()
        every = []
        threads = 0
        for pid, (name, ticks, rss, nthreads) in procs.items():
            threads += nthreads
            before = prev_procs.get(pid)
            used = ticks - before[1] if before and before[0] == name else 0
            every.append({"pid": int(pid), "name": name, "cpu": round(100 * used / TICKS / dt / ncpu, 1), "memory": rss, "threads": nthreads})
        by_cpu = sorted(every, key=lambda p: (-p["cpu"], -p["memory"]))[:10]
        by_mem = sorted(every, key=lambda p: -p["memory"])[:10]
        # A thread name ("MainThread", "Web Content") says little: use the program's file name.
        for p in {id(x): x for x in by_cpu + by_mem}.values():
            argv0 = read(f"/proc/{p['pid']}/cmdline").split("\0")[0]
            if argv0:
                p["name"] = os.path.basename(argv0.split()[0]) or p["name"]
        la = read("/proc/loadavg").split()[:3]
        print(json.dumps({
            "cpu": {"model": model, "percent": pct[0] if pct else 0, "cores": pct[1:], "freq": freq_mhz(),
                    "load": [float(x) for x in la]},
            "memory": memory(), "temps": temps(), "gpu": gpu(), "disks": disks(),
            "net": {"rx": round((net[0] - prev_net[0]) / dt), "tx": round((net[1] - prev_net[1]) / dt)},
            "diskio": {"read": round((io[0] - prev_io[0]) / dt), "write": round((io[1] - prev_io[1]) / dt)},
            "power": power(), "uptime": int(float(read("/proc/uptime", "0").split()[0])),
            "processes": by_cpu, "processesByMemory": by_mem,
            "counts": {"processes": len(procs), "threads": threads},
        }), flush=True)
        prev_cpu, prev_net, prev_io, prev_procs, prev_t = cpu, net, io, procs, now


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
