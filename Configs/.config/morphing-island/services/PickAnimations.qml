pragma Singleton
import QtQuick

// Hyprland animations picker (port of `hyde-shell rofi.animations`). List, current option and
// applying come from HyDE's animations.lua selector (see HydeLuaPicker); the config reload that
// follows runs the chosen preset again (dynamic.lua / hyprland.lua, with dofile). The Island presets
// (island, island-vertical, island-fade) are the fast, discreet ones.
HydeLuaPicker {
    module: "animations"
    title: "Animations"
    placeholder: "Search animations…"
}
