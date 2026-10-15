pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// User overrides chosen in the Settings screen (and a few toggles such as peace mode or the hidden
// pill), stored as a flat key → value map in <XDG_STATE_HOME>/morphing-island/prefs.json.
//
// Config files read their effective values as `Prefs.get("pill.height", <file default>)`: a key that
// is absent from prefs.json means "use the value in the config file". Reset removes keys, so the file
// default applies again. The file is watched: editing it by hand applies live.
//
// Keys in use (see config/README.md): pill.height, pill.hoverExpand, pill.hidden,
// appearance.fontSize, animations.enabled, animations.speed, theme.name, notifications.peaceMode,
// idle.caffeine.
Singleton {
    id: root

    readonly property string path: `${Paths.islandState}/prefs.json`
    // Current overrides. Replaced as a whole on every change, so bindings that call get() update.
    property var values: ({})

    // Keys written by the old JsonAdapter (flat names) → new keys, with the old built-in defaults.
    // Only values that differ from those defaults are carried over (the rest were never chosen).
    readonly property var legacy: ({
            barHeight: ["pill.height", 36],
            fontSize: ["appearance.fontSize", 13],
            animations: ["animations.enabled", true],
            animationSpeed: ["animations.speed", 1],
            hoverExpand: ["pill.hoverExpand", true],
            theme: ["theme.name", "Midnight"],
            peaceMode: ["notifications.peaceMode", false],
            hidden: ["pill.hidden", false]
        })

    // Value of `key`, or `fallback` when the user never set it.
    function get(key, fallback) {
        const v = values[key];
        return v === undefined ? fallback : v;
    }

    function has(key) {
        return values[key] !== undefined;
    }

    // Sets an override (saved to disk after SettingsScreen.saveDebounceMs).
    function set(key, value) {
        if (values[key] === value)
            return;
        const next = Object.assign({}, values);
        next[key] = value;
        values = next;
        saveTimer.restart();
    }

    // Removes overrides: a key name or a list of names. The config file defaults apply again.
    function reset(keys) {
        const list = Array.isArray(keys) ? keys : [keys];
        const next = Object.assign({}, values);
        let changed = false;
        for (const k of list) {
            if (next[k] !== undefined) {
                delete next[k];
                changed = true;
            }
        }
        if (changed) {
            values = next;
            saveTimer.restart();
        }
    }

    function resetAll() {
        if (Object.keys(values).length === 0)
            return;
        values = {};
        saveTimer.restart();
    }

    // Writes pending changes now (e.g. before an IPC call returns).
    function flush() {
        if (saveTimer.running) {
            saveTimer.stop();
            write();
        }
    }

    function write() {
        const keys = Object.keys(values).sort();
        const sorted = {};
        for (const k of keys)
            sorted[k] = values[k];
        file.setText(JSON.stringify(sorted, null, 4) + "\n");
    }

    function parse(text) {
        let data = {};
        try {
            data = JSON.parse(text || "{}");
        } catch (e) {
            // A half-written or broken file keeps the current values (fixed by the next save).
            return;
        }
        if (typeof data !== "object" || data === null || Array.isArray(data))
            data = {};
        // Migration from the old flat format.
        let migrated = false;
        for (const old of Object.keys(legacy)) {
            if (!(old in data))
                continue;
            const [key, oldDefault] = legacy[old];
            if (data[key] === undefined && data[old] !== oldDefault)
                data[key] = data[old];
            delete data[old];
            migrated = true;
        }
        data = root.vet(data);
        if (JSON.stringify(data) !== JSON.stringify(values))
            values = data;
        if (migrated)
            write();
    }

    // Checks the file against config/PrefsSchema.qml and returns what is safe to use.
    //
    // This runs once per load and not inside get(), which is called from bindings all over the shell:
    // a cheap lookup there, and no reporting as a side effect of evaluating a binding.
    //
    // A value of the wrong type or outside its range is dropped, so the config file's own default
    // applies again -- the shell stays usable and the reason is said out loud, instead of drawing
    // itself wrong with no explanation. An unknown key is kept, because it may be a key this version
    // does not know yet, but it is reported too: a misspelled `pill.heigth` looks exactly like a
    // setting that does not work.
    function vet(data) {
        const faults = [];
        const safe = {};
        for (const key of Object.keys(data)) {
            if (PrefsSchema.keys[key] === undefined) {
                faults.push(`unknown key ${key}`);
                safe[key] = data[key];
                continue;
            }
            const fault = PrefsSchema.fault(key, data[key]);
            if (fault === "")
                safe[key] = data[key];
            else
                faults.push(fault);
        }
        if (faults.length > 0)
            Errors.report("settings", `prefs.json: ${faults.join("; ")}`);
        return safe;
    }

    // blockLoading makes text() available right away: the first frame already uses the saved values.
    Component.onCompleted: parse(file.text())

    Timer {
        id: saveTimer
        interval: SettingsScreen.saveDebounceMs
        onTriggered: root.write()
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.values = {};
        }
    }
}
