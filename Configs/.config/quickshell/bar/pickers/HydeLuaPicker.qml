import QtQuick
import Quickshell
import Quickshell.Io

// Base type of the pickers backed by one of HyDE's Lua selectors (animations, workflows, layouts,
// shaders): a picker is a `pragma Singleton` file whose root is `HydeLuaPicker { module: "…" }`.
//
// The list and the current option come from HyDE's own selector, the same Lua module its rofi menu
// uses (~/.local/lib/hyde/<module>.lua, through `hyde-shell <module>`):
//   --list    → "icon name :: description" followed by "  path" (the key is the file name without
//               extension, which is what HyDE uses as `key`);
//   --current → "icon name: description" (state in ~/.local/state/hyde/lua_state/<module>.lua, with
//               the staterc as fallback).
// Applying is `hyde-shell <module> --set <key>` (Hyde.hydeSet), exactly what rofi.<module>.lua calls
// after a choice.
Singleton {
    id: root

    // HyDE module name ("animations", "workflows", "layouts", "shaders").
    property string module: ""
    // Extension stripped from the option files to get their key (".lua", ".frag").
    property string ext: ".lua"
    // Run `hyprctl reload` after the first choice (see Hyde.hydeSet). The shaders module applies
    // itself (hyprctl keyword decoration:screen_shader), so it turns this off.
    property bool firstReload: true

    // Picker contract (see pickers/Pickers.qml).
    readonly property string name: module
    property string title: ""
    property string placeholder: "Search…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    // [{ key, title, subtitle, glyph }] in HyDE's order.
    property var _list: []
    property string _currentKey: ""
    property bool _loading: false
    property bool _again: false

    // Rereads the list and the current option (called whenever the picker opens).
    function refresh() {
        if (reader.running) {
            // A read is already running: repeat it at the end, the files may have changed.
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
                glyph: it.glyph,
                badge: it.key === cur ? "Current" : ""
            });
        // No search: the current option first, the rest in HyDE's order.
        if (q === "")
            return Fuzzy.currentFirst(_list, cur).map(decorate);
        const scored = [];
        for (const it of _list) {
            const s = Math.max(Fuzzy.score(q, it.title), Fuzzy.score(q, it.key) * 0.9, (it.subtitle.toLowerCase().includes(q) ? 35 : 0));
            if (s > 0)
                scored.push({
                    s: s,
                    it: it
                });
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.map(e => decorate(e.it));
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        // Optimistic: the next refresh() confirms it.
        _currentKey = item.key;
        Hyde.hydeSet(module, item.key, firstReload);
    }

    function _parse(text) {
        const marker = "\n@@CURRENT@@\n";
        const at = text.indexOf(marker);
        const listing = at >= 0 ? text.slice(0, at) : text;
        const curLine = at >= 0 ? text.slice(at + marker.length).split("\n")[0].trim() : "";

        const list = [];
        let last = null;
        for (const line of listing.split("\n")) {
            if (line.startsWith("  ")) {
                // Path line of the previous item: the key is the file name without extension.
                const path = line.trim();
                if (last && path !== "") {
                    let base = path.slice(path.lastIndexOf("/") + 1);
                    if (base.endsWith(ext))
                        base = base.slice(0, base.length - ext.length);
                    last.key = base;
                }
                continue;
            }
            const sep = line.indexOf(" :: ");
            if (sep < 0)
                continue;
            const head = line.slice(0, sep);
            const sp = head.indexOf(" ");
            const glyph = sp >= 0 ? head.slice(0, sp) : "";
            const title = (sp >= 0 ? head.slice(sp + 1) : head).trim();
            last = {
                // Without a path (built-in item) HyDE also accepts the name in --set.
                key: title,
                title: title,
                // HyDE separates the description's sentences with " // ".
                subtitle: line.slice(sep + 4).trim().replace(/\s*\/\/\s*/g, " · "),
                glyph: glyph
            };
            list.push(last);
        }

        let current = "";
        for (const it of list) {
            const prefix = (it.glyph !== "" ? it.glyph + " " : "") + it.title + ":";
            if (curLine.startsWith(prefix) || curLine.startsWith(it.title + ":")) {
                current = it.key;
                break;
            }
        }

        _list = list;
        _currentKey = current;
        _loading = false;
    }

    // One run: list, marker, current.
    property Process reader: Process {
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                root.refresh();
            }
        }
        command: ["sh", "-c", 'hyde-shell "$1" --list 2>/dev/null; printf "\\n@@CURRENT@@\\n"; hyde-shell "$1" --current 2>/dev/null', "sh", root.module]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }
}
