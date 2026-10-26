pragma Singleton
import QtQuick
import Quickshell

// The look of the control centre, handed over by whichever shell is running.
//
// The control centre's main page (tiles, sliders, media row, header, icons) is drawn by shared
// components, so the island, the HyDE bar and the minimal bar show the same thing. What they cannot
// share is a colour or a font: each shell has its own theme. So the shell binds these from its
// Shell.qml (colours from its theme, the font, how its animations are scaled) and the shared
// components read them here, never one shell's Theme. Only one shell runs at a time; the defaults
// below only matter in a test.
Singleton {
    // Surfaces and borders.
    property color background: "#101418"
    property color surface: "#1a2026"
    property color border: Qt.rgba(1, 1, 1, 0.1)
    property color hover: Qt.rgba(1, 1, 1, 0.08)
    property color pressed: Qt.rgba(1, 1, 1, 0.12)

    // Text and icons.
    property color foreground: "#e4ecef"
    property color dim: "#9bb0b9"
    property color faint: "#6b7f88"
    property color icon: "#e4ecef"

    // Accent: a filled tile or slider, and what is drawn on top of it.
    property color accent: "#4fd1c0"
    property color accentContent: "#00201c"
    property color danger: "#ff8f86"

    // Fonts. `nerdFont` draws the private-use glyphs of the Nerd Fonts set.
    property string fontFamily: ""
    property string nerdFont: ""
    property real fontSize: 13

    // Layout.
    property int tileHeight: 56
    // At most one brightness change per this many milliseconds (every change is a process).
    property int sliderThrottleMs: 80

    // Milliseconds in, milliseconds out: a shell scales or switches off its animations here.
    property var duration: ms => ms
}
