pragma Singleton
import QtQuick

// Hyprland animations picker (port of `hyde-shell rofi.animations`). List, current option and
// applying come from HyDE's animations.lua selector (see HydeLuaPicker). Hyprland reloads
// lua_state/animations.lua on its own when it changes (hot-reloaded `require`).
HydeLuaPicker {
    module: "animations"
    title: "Animations"
    placeholder: "Search animations…"
}
