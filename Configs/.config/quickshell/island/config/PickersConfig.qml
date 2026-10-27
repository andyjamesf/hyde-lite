pragma Singleton
import QtQuick
import Quickshell

// Picker tunables. A picker is a launcher screen with its own list (the ports of HyDE's rofi menus:
// windows, files, web search, emoji, glyphs, bookmarks, themes…). Each one is a singleton
// services/Pick<Name>.qml registered in services/Pickers.qml; open one with
// `qs ipc call island pick <name>`.
//
// NOTE: this singleton is also called `Pickers`, like the registry services/Pickers.qml. Files that
// import both qs.config and qs.services should import qs.config with a qualifier
// (`import qs.config as Config`, then `Config.PickersConfig.files.maxDepth`); otherwise the name resolves
// to whichever module is imported last.
//
// Paths may start with "~" (expanded to $HOME). Times are milliseconds. Launcher-wide values
// (sizes, prefixes, debounce, caps) are in config/Launcher.qml.
Singleton {
    // Pickers that can be opened (by IPC or from the HyDE menu). Removing a name disables it: `pick`
    // falls back to the normal launcher and the HyDE menu hides it. Default: all of them.
    readonly property var enabled: ["themes", "themeimport", "windows", "files", "web", "emoji", "glyph", "bookmarks", "quickapps", "games", "wallbash", "palette", "animations", "workflows", "shaders", "layouts", "menu"]

    // The HyDE menu picker ("menu"), in display order. Each entry: `name` (a picker from `enabled`),
    // `description` (row subtitle, also searched) and `glyph` (a Nerd Font character shown as the
    // row icon; "" uses the picker's own glyph if it is a character).
    readonly property var menu: [
        {
            "name": "themes",
            "description": "Switch the HyDE theme",
            "glyph": "󰏘"
        },
        {
            "name": "themeimport",
            "description": "Download more themes from the HyDE gallery",
            "glyph": "󰇚"
        },
        {
            "name": "windows",
            "description": "Switch to an open window",
            "glyph": ""
        },
        {
            "name": "files",
            "description": "Find and open a file in your home folder",
            "glyph": ""
        },
        {
            "name": "web",
            "description": "Search the web",
            "glyph": ""
        },
        {
            "name": "emoji",
            "description": "Type an emoji",
            "glyph": ""
        },
        {
            "name": "glyph",
            "description": "Type a Nerd Font glyph",
            "glyph": ""
        },
        {
            "name": "bookmarks",
            "description": "Open a browser bookmark",
            "glyph": ""
        },
        {
            "name": "quickapps",
            "description": "Launch one of HyDE's quick apps",
            "glyph": ""
        },
        {
            "name": "games",
            "description": "Launch a Steam or Lutris game",
            "glyph": ""
        },
        {
            "name": "wallbash",
            "description": "Theme colours: theme, auto, dark or light",
            "glyph": ""
        },
        {
            "name": "palette",
            "description": "Wallpaper palette: one of ten colour schemes, dark or light",
            "glyph": "󰏘"
        },
        {
            "name": "animations",
            "description": "Window animations",
            "glyph": ""
        },
        {
            "name": "workflows",
            "description": "Workflow presets (gaming, focus…)",
            "glyph": ""
        },
        {
            "name": "shaders",
            "description": "Screen shaders",
            "glyph": ""
        },
        {
            "name": "layouts",
            "description": "Window tiling layout",
            "glyph": ""
        }
    ]

    // File finder ("files"). Listed once per opening with `fd` (hidden files skipped, .gitignore
    // honoured) or `find` when fd is missing; searching then filters that list.
    readonly property var files: ({
            // Folders searched ("~" = home). Default ["~"].
            "roots": ["~"],
            // How deep to descend below each root. Levels, 1–12, default 6.
            "maxDepth": 6,
            // Stop listing after this many files and folders. 500–50000, default 5000.
            "maxEntries": 5000,
            // Most rows shown. 50–1000, default 200.
            "maxResults": 200,
            // Folder/file names skipped anywhere in the tree (hidden ones are always skipped).
            "excludes": ["node_modules", "__pycache__", "target", "build", "dist", "venv", "go", "snap", "Steam", "steamapps", "vendor"]
        })

    // Web search ("web"). Engines come from HyDE's websearch.lst files; these engines go first, in
    // this order (names as written in websearch.lst), and the rest follow in file order.
    readonly property var webPreferred: ["google", "duckduckgo", "youtube", "github", "wikipedia"]
    // Display names for common engines (others get their first letter capitalised).
    readonly property var webLabels: ({
            "google": "Google",
            "duckduckgo": "DuckDuckGo",
            "youtube": "YouTube",
            "github": "GitHub",
            "wikipedia": "Wikipedia",
            "archwiki": "ArchWiki",
            "archlinux": "Arch packages",
            "AUR": "AUR",
            "stackoverflow": "Stack Overflow",
            "stackexchange": "Stack Exchange",
            "superuser": "Super User",
            "tex": "TeX Stack Exchange",
            "softwareengineering": "Software Engineering SE",
            "OpenStreetMap": "OpenStreetMap",
            "searXNG": "SearXNG",
            "quickRef": "QuickRef",
            "lens.org": "Lens.org",
            "patents.google": "Google Patents",
            "worldwide.espacenet": "Espacenet",
            "chatGPT": "ChatGPT"
        })

    // How many recently used items each picker remembers (shown first with an empty search and
    // ranked higher when searching), stored in <XDG_STATE_HOME>/morphing-island/pickers.json.
    // 0–200; defaults emoji 40, glyph 40, bookmarks 10.
    readonly property var recents: ({
            "emoji": 40,
            "glyph": 40,
            "bookmarks": 10
        })

    // Most rows each picker returns. 50–1000; defaults windows 200, emoji 300, glyph 300,
    // bookmarks 200, games 200 (the launcher also caps at Launcher.maxPickerResults).
    readonly property var maxResults: ({
            "windows": 200,
            "emoji": 300,
            "glyph": 300,
            "bookmarks": 200,
            "games": 200
        })

    // Quick apps ("quickapps") when ~/.config/hyde/config.toml has no [desktop.app].quickapps
    // (HyDE's own default). Desktop ids or commands. Default ["kitty"].
    readonly property var quickAppsFallback: ["kitty"]

    // Direct paste (emoji, glyph and clipboard pickers): after copying, wait this long for the
    // launcher to close and focus to return to the previous window, then send Ctrl+V (skipped for
    // the window classes in HyDE's ignore.paste, terminals by default). Milliseconds, 50–1000,
    // default 150.
    readonly property int pasteDelayMs: 150
}
