pragma Singleton
import QtQuick
import Quickshell

// Registry of the launcher's pickers: HyDE's rofi screens ported to the shell (the same pickers as
// the Morphing Island's). Each picker is a singleton pickers/Pick<Name>.qml with this contract:
//   name, title, placeholder, loading
//   glyph          Nerd Font character (row icon in the HyDE menu picker) or a drawing name; the
//                  launcher's own icon for each picker is `icons` below (Material Symbols)
//   grid           optional: a grid of tiles instead of a list
//   tile           optional: tile size for grids, Qt.size(w, h) (default square)
//   keepOpen       optional: the launcher stays open on activate
//   textFont       optional: font family for the rows' `text`
//   emptyText      optional: shown for an empty search with no rows
//   refresh()      called whenever the picker opens
//   items(query)   [{ key, title, subtitle, icon, text, glyph, badge }], best first
//   activate(item) performs the action (the launcher closes first, unless keepOpen)
// Only the pickers in PickerSettings.enabled (each shell binds that from its own settings) can be
// opened. Open one with `qs ipc call launcher pick <name>`.
Singleton {
    id: root

    // Pickers only one shell has: the bar's wallpaper picker, the island's theme import. Each
    // binds its own from Shell.qml, and they are offered exactly like the shared ones.
    property var extra: ({})

    readonly property var providers: Object.assign({}, _shared, extra)

    readonly property var _shared: ({
            "themes": PickHydeThemes,
            "windows": PickWindows,
            "files": PickFiles,
            "web": PickWeb,
            "emoji": PickEmoji,
            "glyph": PickGlyph,
            "bookmarks": PickBookmarks,
            "quickapps": PickQuickApps,
            "games": PickGames,
            "wallbash": PickWallbash,
            "palette": PickPalette,
            "animations": PickAnimations,
            "hyprlock": PickHyprlock,
            "workflows": PickWorkflows,
            "shaders": PickShaders,
            "layouts": PickLayouts,
            "menu": PickMenu
        })
    // The launcher's icon for each picker (Material Symbols names).
    readonly property var icons: ({
            "themes": "palette",
            "wallpapers": "wallpaper",
            "windows": "select_window",
            "files": "folder_open",
            "web": "travel_explore",
            "emoji": "mood",
            "glyph": "emoji_symbols",
            "bookmarks": "bookmarks",
            "quickapps": "bolt",
            "games": "sports_esports",
            "wallbash": "format_paint",
            "palette": "palette",
            "animations": "animation",
            "hyprlock": "lock",
            "workflows": "tune",
            "shaders": "filter_vintage",
            "layouts": "dashboard",
            "menu": "widgets"
        })
    // Enabled picker names.
    readonly property var names: Object.keys(providers).filter(n => PickerSettings.enabled.includes(n))

    // The enabled picker with that name, or null.
    function get(name) {
        return name && Object.prototype.hasOwnProperty.call(providers, name) && PickerSettings.enabled.includes(name) ? providers[name] : null;
    }
}
