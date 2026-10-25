pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config
import qs.shared.services

// Loads the plugins in ~/.local/share/morphing-island/plugins: one .qml file each, rooted at
// components/IslandPlugin.qml, which says what it is called, whether it has anything to show, its
// hint, its icon and what a click does.
//
// The core asks here for any status icon id it does not know itself, so a plugin needs no edit to
// StatusZone, Shortcuts or anything else -- only its id in StatusPillConfig.icons, to say where in
// the row it goes.
//
// Loading is at startup and on demand (`reload()`), not watched: a plugin is code, and code that
// reloads itself under a running shell is a good way to lose the shell. `qs` restarts in a second.
Singleton {
    id: root

    // Deliberately outside the shell's own directory. Quickshell turns every folder under the
    // config root into a QML module and compiles it at load: a plugin dropped in there that does
    // not compile takes the whole shell down with it, which is exactly what happened the first time
    // this lived in ~/.config/morphing-island/plugins. Out here a bad plugin is just a bad plugin,
    // reported and skipped.
    readonly property string dir: `${Paths.islandData}/plugins`

    // id → the loaded IslandPlugin. Replaced whole on every load, so bindings on it update.
    property var byName: ({})
    // Names that failed, with the reason: shown by `names` callers and reported once.
    property var failures: []
    readonly property var names: Object.keys(byName)

    function find(name) {
        return byName[name] ?? null;
    }
    function has(name) {
        return byName[name] !== undefined;
    }
    function available(name) {
        return byName[name]?.available ?? false;
    }
    function hint(name) {
        return byName[name]?.hint ?? "";
    }
    function icon(name) {
        return byName[name]?.icon ?? null;
    }
    function activate(name, button) {
        const p = byName[name];
        if (p)
            p.activate(button);
    }

    function reload() {
        lister.running = true;
    }

    function _load(paths) {
        const next = {};
        const bad = [];
        for (const path of paths) {
            if (path === "")
                continue;
            // The file name is the id unless the plugin names itself.
            const fallback = path.replace(/^.*\//, "").replace(/\.qml$/, "");
            const c = Qt.createComponent(`file://${path}`, Component.PreferSynchronous);
            if (c.status === Component.Error) {
                bad.push(`${fallback}: ${c.errorString().trim()}`);
                continue;
            }
            const obj = c.createObject(root);
            if (!obj) {
                bad.push(`${fallback}: it did not load`);
                continue;
            }
            if (obj.name === "")
                obj.name = fallback;
            next[obj.name] = obj;
            obj.started();
        }
        root.byName = next;
        root.failures = bad;
        for (const b of bad)
            Errors.report("plugins", b);
    }

    Process {
        id: lister
        running: true
        // A plugin is one file; a directory that is not there is not a failure, it is the normal
        // state of a shell with no plugins.
        // -L on purpose: a plugin kept in the dotfiles repo is a symlink here, and plain `-type f`
        // does not match one, so every tracked plugin would be invisible.
        command: ["sh", "-c", '[ -d "$1" ] || exit 0\nfind -L "$1" -maxdepth 1 -name "*.qml" -type f | sort', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root._load(text.split("\n"))
        }
    }
}
