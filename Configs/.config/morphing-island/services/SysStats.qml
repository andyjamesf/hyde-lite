pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PC statistics for the System page (components/CcSystemPage.qml) and its detached window
// (core/StatsWindow.qml), from scripts/sysstats.py. The script only runs while one of them is on
// screen (pageShown or detached), every 2 seconds. The detached window, its screen and position are remembered
// (Prefs "stats.*"), so it comes back after a restart.
Singleton {
    id: root

    // The System page is on screen (set by it).
    property bool pageShown: false
    // The last reading (see scripts/sysstats.py), null until the first arrives.
    property var data: null
    // Process list order, shared by the page and the window: "cpu" or "memory".
    property string sortBy: "cpu"

    // The floating window: shown, on which screen, top-left corner in that screen's pixels.
    readonly property bool detached: Prefs.get("stats.detached", false)
    readonly property string screen: Prefs.get("stats.screen", "")
    readonly property int x: Prefs.get("stats.x", -1)
    readonly property int y: Prefs.get("stats.y", -1)
    readonly property bool compact: Prefs.get("stats.compact", false)

    function setCompact(on) {
        if (on)
            Prefs.set("stats.compact", true);
        else
            Prefs.reset("stats.compact");
    }

    function detach(screenName) {
        Prefs.set("stats.screen", screenName);
        Prefs.set("stats.detached", true);
    }
    function attach() {
        Prefs.reset("stats.detached");
    }
    function moveTo(px, py) {
        Prefs.set("stats.x", Math.round(px));
        Prefs.set("stats.y", Math.round(py));
    }

    // 1.2 GB, 850 MB…
    function bytes(n) {
        if (!(n > 0))
            return "0 B";
        const u = ["B", "KB", "MB", "GB", "TB"];
        const i = Math.min(u.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
        const v = n / Math.pow(1024, i);
        return `${v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)} ${u[i]}`;
    }

    Process {
        id: stats
        command: ["python3", Quickshell.shellPath("scripts/sysstats.py"), "2"]
        running: root.pageShown || root.detached
        Component.onCompleted: Errors.watch(stats, "system stats", "sysstats.py")
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.data = JSON.parse(line);
                } catch (e) {
                    Errors.report("system stats", "sysstats.py sent a line that could not be read");
                }
            }
        }
    }
}
