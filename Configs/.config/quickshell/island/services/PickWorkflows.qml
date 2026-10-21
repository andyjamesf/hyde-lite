pragma Singleton
import QtQuick

// HyDE workflows picker (port of rofi.workflows.lua). A workflow is a Hyprland performance/effects
// profile (Default, Editing, Gaming, Powersaver, Snappy). HyDE's selector merges the files from
// ~/.config/hypr/workflows, ~/.local/share/hypr/lua/workflows, /usr/local/share/… and /usr/share/…
// and reads the state from ~/.local/state/hyde/lua_state/workflows.lua (or HYPR_WORKFLOW in the
// staterc). Applying is the same `hyde-shell workflows --set` rofi reaches, plus the `hyprctl reload`
// rofi.workflows.lua does when the state file did not exist yet (see HydeLuaPicker).
HydeLuaPicker {
    module: "workflows"
    title: "Workflows"
    placeholder: "Search workflows…"
}
