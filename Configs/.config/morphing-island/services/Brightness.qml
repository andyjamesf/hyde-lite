pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Brightness of the laptop panel (external monitors have no backlight). Quickshell has no native
// API for this, so:
//  - reading: the sysfs file, with FileView;
//  - change detection: the kernel emits a "change" uevent on every backlight write, read with
//    `udevadm monitor` (a long-running process, no polling), which also catches keys and scripts;
//  - writing: brightnessctl, because sysfs is only writable by root (brightnessctl goes through logind).
// changedByUser ignores hypridle's dimming (it drops to 1% and restores on return): changes from or
// to ≤ OsdConfig.dimmingThreshold % never count.
Singleton {
    id: root

    property string _device: ""
    property real _max: 0
    property int _percent: -1

    readonly property bool available: _device !== "" && _percent >= 0
    readonly property int percent: Math.max(0, _percent)

    signal changedByUser

    function set(p) {
        if (_device === "")
            return;
        p = Math.max(1, Math.min(100, Math.round(p)));
        _apply(p); // immediate feedback; the uevent confirms right after
        Quickshell.execDetached(["brightnessctl", "-q", "-d", _device, "set", `${p}%`]);
    }

    function up() {
        set(percent + OsdConfig.brightnessStep);
    }

    function down() {
        set(percent - OsdConfig.brightnessStep);
    }

    function _apply(p) {
        const previous = _percent;
        if (p === previous)
            return;
        _percent = p;
        // First reading: not a change.
        if (previous < 0)
            return;
        if (previous <= OsdConfig.dimmingThreshold || p <= OsdConfig.dimmingThreshold)
            return;
        changedByUser();
    }

    // Output: "amdgpu_bl1,backlight,65535,100%,65535" (device, class, current, %, max).
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (root._device !== "")
                    return;
                const f = line.split(",");
                if (f.length >= 5) {
                    root._max = parseFloat(f[4]);
                    root._device = f[0];
                }
            }
        }
    }

    FileView {
        id: current
        path: root._device ? `/sys/class/backlight/${root._device}/brightness` : ""
        printErrors: false
        onLoaded: {
            if (root._max > 0)
                root._apply(Math.round(parseFloat(text()) * 100 / root._max));
        }
    }

    Process {
        running: root._device !== ""
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("change"))
                    current.reload();
            }
        }
    }
}
