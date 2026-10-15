pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config as Config

// Shared picker state (recently used emoji, glyphs and bookmarks) in a single file:
// ${XDG_STATE_HOME:-~/.local/state}/morphing-island/pickers.json. One FileView/JsonAdapter for all
// of them, so one picker's write never erases the other pickers' keys.
Singleton {
    id: root

    // Recent lists (read-only for callers: write through push()).
    readonly property var emoji: store.emoji
    readonly property var glyph: store.glyph
    readonly property var bookmarks: store.bookmarks

    // Puts `value` at the head of list `key` (no duplicates, at most PickersConfig.recents[key] items)
    // and saves.
    function push(key, value) {
        if (!["emoji", "glyph", "bookmarks"].includes(key) || value === undefined || value === null || value === "")
            return;
        const max = Config.PickersConfig.recents[key] ?? 40;
        const cur = store[key] ?? [];
        // Reassign the whole list: that is the only change the JsonAdapter notices.
        store[key] = [value].concat(cur.filter(v => v !== value)).slice(0, max);
        file.writeAdapter();
    }

    FileView {
        id: file
        path: `${Paths.islandState}/pickers.json`
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var emoji: []
            property var glyph: []
            property var bookmarks: []
        }
    }
}
