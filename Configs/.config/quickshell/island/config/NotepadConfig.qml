pragma Singleton
import QtQuick
import Quickshell

// Notepad (IslandState.notepad, components/NotepadView.qml): one plain-text scratch page that is
// always there, saved as you type. Opened with $mod+ALT+N or `island open notepad`.
Singleton {
    // Size of the page inside the island, in pixels. The text wraps to the width and scrolls past
    // the height. Defaults 520 x 380.
    readonly property int width: 520
    readonly property int height: 380
    // Milliseconds of quiet before what you typed is written to disk. Default 600.
    readonly property int saveDebounceMs: 600
    // Text size in pixels. 0 = follow Appearance.fontSize. Default 0.
    readonly property int fontSize: 0
    // Monospace, for pasted commands and lists to line up. Default true.
    readonly property bool monospace: true
    // Shown while the page is empty.
    readonly property string placeholder: "Notes, kept here and saved as you type."
}
