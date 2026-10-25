pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brightness of the laptop panel (external monitors have no backlight), shared by every UI of this
// configuration. Quickshell has no native API for it, so:
//  - reading: the sysfs file, with FileView;
//  - change detection: the kernel emits a "change" uevent on every backlight write, read with
//    `udevadm monitor` (a long-running process, no polling), which also catches the keys and any
//    script that writes the backlight;
//  - writing: brightnessctl, because sysfs is only writable by root (brightnessctl goes through
//    logind).
//
// The union of what the bar and the island each had: the bar had the Material icon and change(),
// the island the dimming filter, the changedByUser signal and up()/down(). Both shells had written
// the dimming filter separately — the island here and the bar in its own OSD service.
//
// `step` and `dimmingThreshold` are what a UI configures: a shared service has no settings file, so
// each shell binds them from its own (the bar from config.json, the island from OsdConfig).
Singleton {
    id: root

    property string _device: ""
    property real _max: 0
    property int _percent: -1

    readonly property bool available: _device !== "" && _percent >= 0
    readonly property int percent: Math.max(0, _percent)

    // How much up() and down() move, in percentage points.
    property int step: 5
    // hypridle dims the screen to about 1% and restores it when you come back. A change from or to
    // anything at or below this is that, not the owner, and does not raise changedByUser (which is
    // what the OSDs listen to, so the screen does not flash a brightness popup at idle). 0 disables
    // the filter.
    property int dimmingThreshold: 2

    // The owner changed the brightness (as opposed to the screen dimming by itself).
    signal changedByUser

    readonly property string icon: percent < 34 ? "brightness_low" : percent < 67 ? "brightness_medium" : "brightness_high"

    function set(p: real): void {
        if (_device === "")
            return;
        p = Math.max(1, Math.min(100, Math.round(p)));
        _apply(p); // immediate feedback; the uevent confirms right after
        Quickshell.execDetached(["brightnessctl", "-q", "-d", _device, "set", `${p}%`]);
    }

    function change(delta: real): void {
        set(percent + delta);
    }

    function up(): void {
        change(step);
    }

    function down(): void {
        change(-step);
    }

    function _apply(p) {
        const previous = _percent;
        if (p === previous)
            return;
        _percent = p;
        // The first reading is not a change.
        if (previous < 0)
            return;
        if (dimmingThreshold > 0 && (previous <= dimmingThreshold || p <= dimmingThreshold))
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
        onLoaded: if (root._max > 0)
            root._apply(Math.round(parseFloat(text()) * 100 / root._max))
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
