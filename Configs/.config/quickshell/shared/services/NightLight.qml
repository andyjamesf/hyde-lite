pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light through HyDE's own script (`hyde-shell hyprsunset`), exactly like HyDE's keyboard
// shortcut, so every way of turning it on always agrees. Shared by every UI of this configuration.
//
// This is the island's service. The bar had written its own, which asked the script for its state
// (`hyprsunset -rq`) after every action and whenever a panel opened: it could not see a change made
// by HyDE's own shortcut until something asked again, and it pulled in a UI component (JsonStream)
// to parse the answer. Watching the state file costs nothing and is never stale.
//
// The state is HyDE's file ${XDG_STATE_HOME}/hyde/hyprsunset, "temperature|gamma|on|identity"
// (e.g. "4000|100|1|6000"). It is watched: a change made anywhere (the HyDE shortcut, the HyDE shell)
// shows here at once, without polling.
//
// Why not talk to hyprsunset directly: its `identity` command resets the colours but keeps
// reporting the last temperature, so "is it on?" can't be read from the daemon; and HyDE's script
// re-applies its own saved state whenever it runs, undoing any change it doesn't know about.
Singleton {
    id: root

    // The temperature to apply when turning night light on while HyDE's saved one is neutral,
    // in kelvin. The island binds it from config/ControlCenter.qml.
    property int temperature: 4000

    // hyprsunset is installed (HyDE starts its daemon).
    property bool available: false
    readonly property bool active: _on
    // Temperature HyDE applies when on, in kelvin.
    readonly property int currentTemperature: _temp
    // What a widget shows when the pointer rests on it.
    readonly property string tooltip: !available ? "Night light is not installed" : _on ? `Night light on · ${_temp} K` : "Night light off"

    property bool _on: false
    property int _temp: 0

    function refresh() {
        state.reload();
    }

    function set(on) {
        if (on === _on)
            return;
        // HyDE's saved temperature may be neutral (≥ 6000 K, its default): turning on would then
        // change nothing visible, so apply root.temperature first.
        const warm = Math.max(1000, Math.min(20000, Math.round(root.temperature)));
        const script = on && (_temp <= 0 || _temp >= 6000) ? `hyde-shell hyprsunset -q --cm temp -s ${warm} && hyde-shell hyprsunset -q -t` : "hyde-shell hyprsunset -q -t";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    function toggle() {
        set(!_on);
    }

    // Sets the colour temperature (kelvin) and turns night light on if it was off.
    function setTemperature(kelvin) {
        const k = Math.max(1000, Math.min(20000, Math.round(kelvin)));
        Quickshell.execDetached(["sh", "-c", `hyde-shell hyprsunset -q --cm temp -s ${k}` + (_on ? "" : " && hyde-shell hyprsunset -q -t")]);
    }

    FileView {
        id: state
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/hyde/hyprsunset`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const f = text().trim().split("|");
            root._temp = parseInt(f[0]) || 0;
            root._on = f[2] === "1";
        }
        // No file yet: HyDE hasn't used night light; it starts off.
        onLoadFailed: root._on = false
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset >/dev/null && command -v hyde-shell >/dev/null"]
        onExited: code => root.available = code === 0
    }
}
