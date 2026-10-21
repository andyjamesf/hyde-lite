pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock screen layout picker (port of `hyde-shell hyprlock --select`).
//
// List: as in hyprlock.sh's fn_select, the *.conf files in ~/.config/hypr/hyprlock (with -L) except
// theme.conf, by file name without extension, with "Theme Preference" first (uses the theme's
// theme.conf). Current: HYPRLOCK_LAYOUT in ~/.local/state/hyde/staterc (overridden by
// ~/.local/state/hyde/config when it exists).
//
// --select only works with rofi. HyDE's non-interactive equivalent is saving the choice with its
// set_conf and running `hyde-shell hyprlock --reload`, which regenerates hyprlock.conf from
// HYPRLOCK_LAYOUT (maps "Theme Preference" → theme, resolves fonts, builds the profile) and
// notifies. Difference from --select: it also sends USR2 to a running hyprlock (reloads it).
Singleton {
    id: root

    readonly property string name: "hyprlock"
    readonly property string title: "Lock screen layout"
    readonly property string placeholder: "Search lock screen layouts…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property string layoutDir: `${Paths.configHome}/hypr/hyprlock`
    readonly property string themeKey: "Theme Preference"

    // [{ key, title, subtitle }]
    property var _list: []
    property string _currentKey: ""
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
        const cur = _currentKey;
        const decorate = it => ({
                key: it.key,
                title: it.title,
                subtitle: it.subtitle,
                icon: "",
                text: "",
                badge: it.key === cur ? "Current" : ""
            });
        if (q === "")
            return Fuzzy.currentFirst(_list, cur).map(decorate);
        return _list.filter(it => it.title.toLowerCase().includes(q) || it.subtitle.toLowerCase().includes(q)).map(decorate);
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        _currentKey = item.key;
        // The regeneration must finish even if the shell restarts: Hyde.initRun goes through
        // Launch.run (its own unit, outside the shell's cgroup).
        Hyde.initRun('set_conf "HYPRLOCK_LAYOUT" "$1" && exec hyde-shell hyprlock --reload', [item.key]);
    }

    function _parse(text) {
        const marker = "@@CURRENT@@";
        const at = text.indexOf(marker);
        const listing = at >= 0 ? text.slice(0, at) : text;
        // Last assignment wins (config is read after staterc).
        const current = at >= 0 ? Hyde.confValue(text.slice(at + marker.length), "HYPRLOCK_LAYOUT", "") : "";

        const list = [
            {
                key: themeKey,
                title: themeKey,
                subtitle: "Use the current theme's lock screen"
            }
        ];
        const seen = new Set([themeKey]);
        for (const line of listing.split("\n")) {
            const path = line.trim();
            if (path === "" || !path.endsWith(".conf"))
                continue;
            const base = path.slice(path.lastIndexOf("/") + 1, -5);
            if (seen.has(base))
                continue;
            seen.add(base);
            list.push({
                key: base,
                title: base,
                subtitle: path.replace(Paths.home, "~")
            });
        }

        _list = list;
        _currentKey = current;
        _loading = false;
    }

    Process {
        id: reader
        command: ["sh", "-c", 'find -L "$1" -name "*.conf" ! -name "theme.conf" 2>/dev/null | sort -f; echo "@@CURRENT@@"; cat "$2" "$3" 2>/dev/null; true', "sh", root.layoutDir].concat(Hyde.stateFiles)
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
