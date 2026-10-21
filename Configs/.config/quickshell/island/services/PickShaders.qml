pragma Singleton
import QtQuick

// HyDE screen shaders picker (port of rofi.shaders.lua). HyDE's selector merges the .frag files
// from ~/.config/hypr/shaders, ~/.local/share/hypr/shaders, /usr/local/share/… and /usr/share/…
// and reads the state from ~/.local/state/hyde/lua_state/shaders.lua (or HYPR_SHADER in the
// staterc). Applying is the same `hyde-shell shaders --set` rofi reaches: it compiles the shader to
// ~/.local/state/hyde/compiled.cache.glsl, writes the state and applies it right away with
// `hyprctl keyword decoration:screen_shader`, so no reload is needed. There is no preview while
// browsing (rofi uses `--test`).
HydeLuaPicker {
    module: "shaders"
    ext: ".frag"
    firstReload: false
    title: "Shaders"
    placeholder: "Search shaders…"
}
