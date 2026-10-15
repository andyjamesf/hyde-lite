pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// "Quick apps" picker for the launcher (port of HyDE's quickapps.sh).
// In HyDE the list comes from the script's arguments (`hyde-shell quickapps <app1> <app2> …`),
// which HyDE takes from the `quickapps` key of the [desktop.app] section of
// ~/.config/hyde/config.toml (a string of space-separated names; the schema default is "kitty").
// Here that same key is read (a TOML array or commas work too); when it is missing,
// Config.pickers.quickAppsFallback is used. Each name resolves to a .desktop file (exact id or
// Quickshell's heuristic), which provides the name and icon — as quickapps.sh does with grep.
// activate() launches it with Launch.desktop, like HyDE; a name that matches no .desktop file is
// run as a command.
Singleton {
    id: root

    readonly property string name: "quickapps"
    readonly property string title: "Quick apps"
    readonly property string placeholder: "Search quick apps…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    // Used when config.toml has no [desktop.app].quickapps (HyDE's schema default).
    readonly property var fallbackApps: Config.pickers.quickAppsFallback

    property bool _loading: false
    property var _apps: []

    function refresh() {
        _loading = true;
        // Rereads config.toml on every opening (it is small) to pick up the user's changes.
        if (config.path === "")
            config.path = `${Hyde.configDir}/config.toml`;
        else
            config.reload();
    }

    // Extracts [desktop.app].quickapps from simple TOML (no library: only this key matters).
    function _parseConfig(text) {
        let section = "";
        let value = null;
        for (const raw of String(text).split("\n")) {
            const line = raw.replace(/^\s+|\s+$/g, "");
            const sec = line.match(/^\[\s*([^\]]+?)\s*\]$/);
            if (sec) {
                section = sec[1].replace(/["\s]/g, "");
                continue;
            }
            if (section !== "desktop.app")
                continue;
            const kv = line.match(/^quickapps\s*=\s*(.+)$/);
            if (!kv)
                continue;
            let v = kv[1];
            if (v.startsWith("[")) {
                // Array: ["kitty", "firefox"]
                value = (v.match(/"([^"]*)"|'([^']*)'/g) ?? []).map(s => s.slice(1, -1));
            } else {
                const m = v.match(/^"([^"]*)"|^'([^']*)'/);
                value = (m ? (m[1] ?? m[2]) : v.replace(/\s+#.*$/, "")).split(/[\s,]+/);
            }
        }
        const list = (value ?? fallbackApps).map(s => String(s).trim()).filter(s => s.length > 0);
        _apps = list.filter((s, i) => list.indexOf(s) === i);
        _loading = false;
    }

    function _entryFor(app) {
        return DesktopEntries.byId(app) ?? DesktopEntries.byId(app.replace(/\.desktop$/, "")) ?? DesktopEntries.heuristicLookup(app);
    }

    function _item(app) {
        const e = _entryFor(app);
        return {
            key: app,
            title: e?.name || app,
            subtitle: e ? (e.genericName || e.comment || `${e.id}.desktop`) : app,
            icon: e?.icon || "application-x-executable",
            text: "",
            badge: ""
        };
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const all = _apps.map(_item);
        if (q === "")
            return all;
        // Few items: a substring search is enough, keeping the configured order.
        return all.filter(i => `${i.title} ${i.subtitle} ${i.key}`.toLowerCase().includes(q));
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        const e = _entryFor(item.key);
        if (e)
            Launch.desktop(e.id);
        else
            Launch.run(["sh", "-c", item.key]);
    }

    FileView {
        id: config
        path: ""
        printErrors: false
        onLoaded: root._parseConfig(text())
        // No HyDE config.toml: use the default list.
        onLoadFailed: root._parseConfig("")
    }
}
