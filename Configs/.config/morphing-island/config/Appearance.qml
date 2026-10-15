pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Fonts. `fontSize` can be changed in the Settings screen (Prefs key "appearance.fontSize").
Singleton {
    // Main UI font family (any installed family name, see `fc-list : family`). Default "Inter".
    readonly property string font: "Inter"
    // Base text size in pixels; larger/smaller texts are derived from it. Range 11–18, default 13.
    readonly property int fontSize: Prefs.get("appearance.fontSize", 13)
    // Nerd Font family for glyph icons (launcher rows, picker headers, power actions…).
    // Default "JetBrainsMono Nerd Font".
    readonly property string nerdFont: "JetBrainsMono Nerd Font"
    // Font for icon glyphs; defaults to the Nerd Font above.
    readonly property string iconFont: nerdFont
    // Monospace family (password dots in the polkit dialog, command lines). Default "monospace".
    readonly property string monoFont: "monospace"
}
