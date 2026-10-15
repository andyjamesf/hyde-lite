pragma Singleton
import QtQuick
import Quickshell
import qs.core
import qs.config as Config

// Picker of pickers: lists every screen that came from HyDE's rofi menus (including those without a
// shortcut of their own, such as themes, workflows, shaders or layouts). Choosing one opens it in
// the same launcher without closing the island — the equivalent of the bar's HyDE menu.
// Order, descriptions and icons: PickersConfig.menu in config/PickersConfig.qml.
Singleton {
    id: root

    readonly property string name: "menu"
    readonly property string title: "HyDE"
    readonly property string placeholder: "Search HyDE menus…"
    readonly property string glyph: "picker"
    readonly property bool loading: false
    readonly property bool grid: false
    readonly property bool keepOpen: true

    function refresh() {}

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const out = [];
        for (const entry of Config.PickersConfig.menu) {
            // Pickers.get() is null for unknown or disabled pickers.
            const p = Pickers.get(entry.name);
            if (!p || p === root)
                continue;
            const description = String(entry.description ?? "");
            const hay = `${p.title} ${description} ${entry.name}`.toLowerCase();
            if (q !== "" && !q.split(/\s+/).every(w => hay.includes(w)))
                continue;
            // One Nerd Font icon per picker (several have no glyph of their own, or a launcher
            // drawing instead of a character).
            const isKind = /^[a-z]+$/.test(p.glyph ?? "");
            out.push({
                "key": entry.name,
                "title": p.title,
                "subtitle": description,
                "icon": "",
                "text": "",
                "glyph": entry.glyph || (isKind ? "" : (p.glyph ?? "")),
                "badge": ""
            });
        }
        return out;
    }

    // Opens the chosen picker in the same launcher (the island stays open: keepOpen).
    function activate(item) {
        LauncherState.query = "";
        LauncherState.provider = item.key;
    }
}
