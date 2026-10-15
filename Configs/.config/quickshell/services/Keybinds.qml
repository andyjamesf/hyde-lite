pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland keybindings for the launcher's "Keys" mode (replaces HyDE's keybinds_hint, which opened
// in rofi). Read from `hyprctl binds -j`; only those with a description. HyDE's description carries the
// category in square brackets: "[Launcher|Apps] browser" → category "Launcher · Apps".
Singleton {
    id: root

    property var entries: []
    property bool loading: false

    // Hyprland modmask bits, in the order they are written.
    readonly property var mods: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var keyNames: ({
            "slash": "/",
            "backslash": "\\",
            "comma": ",",
            "period": ".",
            "semicolon": ";",
            "apostrophe": "'",
            "grave": "`",
            "minus": "-",
            "equal": "=",
            "bracketleft": "[",
            "bracketright": "]",
            "space": "Space",
            "return": "Enter",
            "escape": "Esc",
            "tab": "Tab",
            "delete": "Delete",
            "backspace": "Backspace",
            "print": "Print",
            "left": "←",
            "right": "→",
            "up": "↑",
            "down": "↓",
            "mouse:272": "Left click",
            "mouse:273": "Right click",
            "mouse:274": "Middle click",
            "mouse_up": "Scroll ↑",
            "mouse_down": "Scroll ↓",
            "alt_l": "Left Alt",
            "alt_r": "Right Alt",
            "super_l": "Super",
            "super_r": "Super",
            "xf86audioraisevolume": "Volume +",
            "xf86audiolowervolume": "Volume −",
            "xf86audiomute": "Mute",
            "xf86audiomicmute": "Mic mute",
            "xf86audioplay": "Play",
            "xf86audiopause": "Pause",
            "xf86audionext": "Next track",
            "xf86audioprev": "Previous track",
            "xf86monbrightnessup": "Brightness +",
            "xf86monbrightnessdown": "Brightness −"
        })

    function keyName(key) {
        const k = String(key);
        const named = keyNames[k.toLowerCase()];
        if (named)
            return named;
        if (/^code:\d+$/.test(k))
            return `Key ${k.slice(5)}`;
        if (k.length === 1)
            return k.toUpperCase();
        if (/^XF86/.test(k))
            return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        return k.charAt(0).toUpperCase() + k.slice(1).toLowerCase();
    }

    // [ "Super", "Shift", "T" ]
    function keysOf(b) {
        const parts = mods.filter(m => (b.modmask & m[0]) !== 0).map(m => m[1]);
        parts.push(keyName(b.key));
        return parts;
    }

    // Keys that are only modifiers (e.g. releasing Alt at the end of Alt+Tab): they are part of another
    // binding and aren't pressed on their own, so they don't appear in the list.
    readonly property var modifierKeys: ["alt_l", "alt_r", "super_l", "super_r", "control_l", "control_r", "shift_l", "shift_r"]

    // One entry per action: different combinations for the same thing (Super+Q and Alt+F4 to close the
    // window) go on the same row, in `combos`.
    function parse(json) {
        const byAction = {};
        const out = [];
        for (const b of JSON.parse(json)) {
            if (!b.has_description || !b.description || modifierKeys.includes(String(b.key).toLowerCase()))
                continue;
            const m = /^\[([^\]]*)\]\s*(.*)$/.exec(b.description);
            const category = m ? m[1].split("|").join(" · ") : "";
            const text = (m ? m[2] : b.description).trim();
            const keys = keysOf(b);
            const id = `${category}|${text}`;
            let entry = byAction[id];
            if (!entry) {
                entry = byAction[id] = {
                    title: text.charAt(0).toUpperCase() + text.slice(1),
                    category: category,
                    combos: [],
                    dispatcher: b.dispatcher,
                    arg: b.arg,
                    haystack: `${text} ${category}`.toLowerCase()
                };
                out.push(entry);
            }
            if (!entry.combos.some(c => c.join("+") === keys.join("+"))) {
                entry.combos.push(keys);
                entry.haystack += " " + keys.join(" ").toLowerCase();
            }
        }
        return out;
    }

    // Every word of the query must appear (in the description, the category or the keys).
    function search(query) {
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        return words.length ? entries.filter(e => words.every(w => e.haystack.includes(w))) : entries;
    }

    // With the Lua config, each binding is the "__lua" dispatcher with the function's number in the
    // Lua registry (HyDE's `hyprctl dispatch __lua N` no longer works: dispatch now
    // takes Lua code). Only a number is accepted, so arbitrary text is never evaluated.
    function run(entry) {
        if (entry.dispatcher === "__lua") {
            if (/^\d+$/.test(entry.arg))
                Quickshell.execDetached(["hyprctl", "eval", `debug.getregistry()[${entry.arg}]()`]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", entry.dispatcher, entry.arg]);
        }
    }

    function refresh() {
        loading = true;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = root.parse(text);
                } catch (e) {
                    console.warn("keybinds:", e);
                }
                root.loading = false;
            }
        }
    }
}
