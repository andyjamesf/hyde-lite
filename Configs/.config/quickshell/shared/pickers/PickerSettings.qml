pragma Singleton
import QtQuick
import Quickshell

// What the shared pickers need to know, which is the one thing they cannot share: each shell keeps
// these in its own settings file (the bar in config/config.json under "pickers", the island in
// config/PickersConfig.qml), and binds them here from its Shell.qml. The defaults are the bar's.
//
// The pickers themselves (shared/pickers/Pick*.qml) read this and nothing else of either UI.
Singleton {
    id: root

    // Pickers that can be opened at all; a name missing from this list is not offered anywhere.
    property var enabled: ["themes", "wallpapers", "windows", "files", "web", "emoji", "glyph", "bookmarks", "quickapps", "games", "wallbash", "palette", "animations", "hyprlock", "workflows", "shaders", "layouts", "menu"]
    // The HyDE menu picker's rows, in order.
    property var menu: []
    // How many rows each picker returns at most, by picker name.
    property var maxResults: ({})
    // The file picker's roots and filters.
    property var files: ({})
    // Apps offered by the quick-apps picker when nothing is pinned.
    property var quickAppsFallback: []
    // How many recent entries each picker remembers.
    property var recents: ({})
    // The web picker's search engines.
    property var webLabels: ({})
    property var webPreferred: []
    // Wait before pasting into the window that had focus, in milliseconds.
    property int pasteDelayMs: 60
    // Extra pickers written in QML by the owner.
    property var qml: ({})

    // The font the glyph picker shows its characters in: both shells have one, under different
    // names (the bar's mono font, the island's Nerd Font).
    property string glyphFont: "monospace"

    // Where a picker keeps what it remembers (pickers.json). Each shell has its own.
    property string statePath: ""
}
