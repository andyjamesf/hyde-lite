pragma Singleton
import QtQuick

// HyDE layouts picker (port of rofi.layouts.lua). These are Hyprland window layouts
// (general:layout — Dwindle, Master, Monocle, Scrolling…), not keyboard layouts. HyDE's selector
// merges the files from ~/.config/hypr/lua/layouts, ~/.local/share/hypr/lua/layouts,
// /usr/local/share/… and /usr/share/… and reads the state from
// ~/.local/state/hyde/lua_state/layouts.lua (or HYPR_LAYOUT in the staterc). Applying is the same
// `hyde-shell layouts --set` rofi reaches (it writes the Lua state and the legacy
// ~/.config/hypr/layouts.conf); see HydeLuaPicker.
HydeLuaPicker {
    module: "layouts"
    title: "Layouts"
    placeholder: "Search layouts…"
}
