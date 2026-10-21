pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness. Quickshell has no native API, so:
// - reading: the sysfs file, with FileView;
// - change detection: the kernel emits a "change" uevent on every backlight write
//   (tested on this laptop), read with `udevadm monitor` — avoids polling, and also catches
//   changes made by the keys/HyDE (brightnesscontrol.sh);
// - writing: brightnessctl, because sysfs is only writable by root (brightnessctl uses logind).
Singleton {
    id: root

    property string device
    property real max: 0
    property real percent: -1
    readonly property bool available: device !== "" && percent >= 0

    readonly property string icon: percent < 34 ? "brightness_low" : percent < 67 ? "brightness_medium" : "brightness_high"

    function set(p) {
        p = Math.max(1, Math.min(100, Math.round(p)));
        percent = p; // immediate feedback; the uevent confirms right after
        Quickshell.execDetached(["brightnessctl", "-q", "set", `${p}%`]);
    }

    function change(delta) {
        set(percent + delta);
    }

    // "amdgpu_bl1,backlight,65535,100%,65535"
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split(",");
                root.device = f[0];
                root.max = parseFloat(f[4]);
            }
        }
    }

    FileView {
        id: current
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: if (root.max > 0)
            root.percent = Math.round(parseFloat(text()) * 100 / root.max)
    }

    Process {
        running: root.device !== ""
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    current.reload();
            }
        }
    }
}
