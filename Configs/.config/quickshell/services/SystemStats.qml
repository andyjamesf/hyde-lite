pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory, temperature and network traffic, read from /proc and /sys with FileView (no processes).
// The kernel doesn't signal when these values change, so a timer is unavoidable here; it only
// runs while some widget needs the data (`users` counter).
Singleton {
    id: root

    property int users: 0

    property real cpu: 0          // 0..1
    property real memory: 0       // 0..1
    property real memUsedBytes: 0
    property real temperature: 0  // °C
    property real rxRate: 0       // bytes/s
    property real txRate: 0

    property var _lastCpu: null
    property var _lastNet: null
    property string _tempPath: ""

    Timer {
        interval: Config.widgets.stats.interval
        running: root.users > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            if (root._tempPath)
                temp.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                const dt = total - root._lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root._lastCpu.idle) / dt : 0;
            }
            root._lastCpu = {
                idle,
                total
            };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number((new RegExp(`^${key}:\\s+(\\d+)`, "m").exec(text()) ?? [0, 0])[1]);
            const total = kb("MemTotal");
            const used = total - kb("MemAvailable");
            root.memory = total > 0 ? used / total : 0;
            root.memUsedBytes = used * 1024;
        }
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const [iface, data] = line.split(":");
                if (!data || iface.trim() === "lo")
                    continue;
                const f = data.trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            if (root._lastNet) {
                const dt = (now - root._lastNet.t) / 1000;
                root.rxRate = (rx - root._lastNet.rx) / dt;
                root.txRate = (tx - root._lastNet.tx) / dt;
            }
            root._lastNet = {
                rx,
                tx,
                t: now
            };
        }
    }

    FileView {
        id: temp
        path: root._tempPath
        onLoaded: root.temperature = Number(text()) / 1000
    }

    // Picks the CPU sensor (k10temp on AMD, coretemp on Intel) only once.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); case $n in k10temp|coretemp|zenpower|cpu_thermal) echo $h/temp1_input; exit;; esac; done"]
        stdout: SplitParser {
            onRead: line => root._tempPath = line.trim()
        }
    }
}
