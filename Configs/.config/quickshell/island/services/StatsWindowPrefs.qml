pragma Singleton
import QtQuick
import Quickshell
import qs.island.services

// The detached statistics window of this shell: whether it is out, on which screen, where on it
// and how big (core/StatsWindow.qml draws it). All of it is remembered (Prefs "stats.*"), so the
// window comes back where it was after a restart.
//
// The numbers themselves are shared with the bar (shared/services/SysStats.qml); only a window
// that floats over the apps is this shell's own, so its settings live here.
Singleton {
    id: root

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
}
