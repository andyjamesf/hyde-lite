pragma Singleton
import QtQuick
import Quickshell
import qs.components

// Night light through HyDE's hyprsunset (keeps HyDE's state and presets).
// There is no change signal: the state is read at startup, after each action and when some
// panel showing it opens (refresh()).
Singleton {
    id: root

    readonly property bool active: state.alt !== "" && state.alt !== "inactive"
    readonly property string tooltip: state.tooltip

    function refresh() {
        state.refresh();
    }

    function run(args) {
        Utils.run(`hyde-shell hyprsunset ${args}`);
        refreshSoon.restart();
    }

    function toggle() {
        run("-t");
    }

    function setTemperature(kelvin) {
        run(`--cm temp -s ${kelvin}`);
    }

    JsonStream {
        id: state
        exec: "hyde-shell hyprsunset -rq"
        interval: -1
    }

    Timer {
        id: refreshSoon
        interval: 700
        onTriggered: state.refresh()
    }
}
