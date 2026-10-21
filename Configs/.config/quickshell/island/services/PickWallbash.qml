pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallbash mode picker (port of `hyde-shell wallbashtoggle -m`).
//
// The options are wallbashtoggle.sh's fixed ones (wallbashModes=theme auto dark light); the index
// is stored as enableWallDcol in ~/.local/state/hyde/staterc (~/.local/state/hyde/config, when it
// exists, is read afterwards and wins, as in export_hyde_config). No value or an invalid one counts
// as 0 (theme), as in globalcontrol.sh.
//
// wallbashtoggle only has --menu (rofi) and --next/--prev, so applying replays the end of the
// script with HyDE's own functions: reload_flag=1, set_conf enableWallDcol <n>, theme.switch.sh and
// the same notification. theme.switch.sh rereads the staterc (it sources globalcontrol), so it
// picks up the new mode.
Singleton {
    id: root

    readonly property string name: "wallbash"
    readonly property string title: "Wallbash mode"
    readonly property string placeholder: "Search wallbash modes…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    // In wallbashModes order: the index is the value of enableWallDcol.
    readonly property var modes: [
        {
            key: "theme",
            title: "Theme",
            subtitle: "Use the colours shipped with the current theme",
            glyph: ""
        },
        {
            key: "auto",
            title: "Auto",
            subtitle: "Colours from the wallpaper, dark or light to match it",
            glyph: ""
        },
        {
            key: "dark",
            title: "Dark",
            subtitle: "Colours from the wallpaper, always dark",
            glyph: ""
        },
        {
            key: "light",
            title: "Light",
            subtitle: "Colours from the wallpaper, always light",
            glyph: ""
        }
    ]

    property int _current: 0
    property bool _loading: false
    property bool _again: false

    function refresh() {
        if (reader.running) {
            _again = true;
            return;
        }
        _loading = true;
        reader.running = true;
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const cur = modes[_current] ? modes[_current].key : "";
        const decorate = m => ({
                key: m.key,
                title: m.title,
                subtitle: m.subtitle,
                icon: "",
                text: "",
                glyph: m.glyph,
                badge: m.key === cur ? "Current" : ""
            });
        if (q === "")
            return Fuzzy.currentFirst(modes, cur).map(decorate);
        return modes.filter(m => m.key.includes(q) || m.title.toLowerCase().includes(q) || m.subtitle.toLowerCase().includes(q)).map(decorate);
    }

    function activate(item) {
        if (!item)
            return;
        const idx = modes.findIndex(m => m.key === item.key);
        if (idx < 0)
            return;
        _current = idx;
        // theme.switch.sh takes a while and must finish even if the island restarts: Hyde.initRun
        // goes through Launch.run (its own unit, outside the island's cgroup).
        Hyde.initRun('export reload_flag=1; set_conf "enableWallDcol" "$1"; "$LIB_DIR/hyde/theme.switch.sh"; notify-send -a "HyDE Alert" -i "$ICONS_DIR/Wallbash-Icon/hyde.png" " $2 mode"', [idx, item.key]);
    }

    function _parse(text) {
        // Last assignment wins (config is read after staterc).
        const value = parseInt(Hyde.confValue(text, "enableWallDcol", "0"));
        _current = value >= 0 && value < modes.length ? value : 0;
        _loading = false;
    }

    Process {
        id: reader
        command: ["sh", "-c", 'cat "$1" "$2" 2>/dev/null; true', "sh"].concat(Hyde.stateFiles)
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                root.refresh();
            }
        }
    }
}
