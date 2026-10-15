pragma Singleton
import QtQuick
import Quickshell
import qs.config as Config

// Registry of the launcher's pickers (HyDE's rofi screens ported to the island). Each picker is a
// singleton services/Pick<Name>.qml with this contract:
//   name, title, placeholder, glyph (a LauncherGlyph kind, a Nerd Font character or ""), loading
//   grid (optional: grid of tiles), keepOpen (optional: the island stays open on activate)
//   textFont (optional: font family for the rows' `text`), emptyText (optional: shown for an empty search)
//   refresh()      called whenever the picker opens
//   items(query)   [{ key, title, subtitle, icon, text, glyph, badge }], best first,
//                  ≤ Launcher.maxPickerResults (the view caps the rest)
//   activate(item) performs the action (the island closes first, unless keepOpen)
// Only the pickers listed in PickersConfig.enabled (config/PickersConfig.qml) can be opened.
// Open one with `qs -p ~/.config/morphing-island ipc call island pick <name>`.
Singleton {
    id: root

    readonly property var providers: ({
            "themes": PickHydeThemes,
            "themeimport": PickThemeImport,
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
    // Enabled picker names.
    readonly property var names: Object.keys(providers).filter(n => Config.PickersConfig.enabled.includes(n))

    // The enabled picker with that name, or null.
    function get(name) {
        return name && Object.prototype.hasOwnProperty.call(providers, name) && Config.PickersConfig.enabled.includes(name) ? providers[name] : null;
    }
}
