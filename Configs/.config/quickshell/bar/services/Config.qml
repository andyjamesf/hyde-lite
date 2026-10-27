pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings, in config/config.json. The defaults live here:
// the file only needs what you want to change. Changes are applied live.
Singleton {
    id: root

    readonly property alias bar: adapter.bar
    readonly property alias appearance: adapter.appearance
    readonly property alias widgets: adapter.widgets
    readonly property alias pickers: adapter.pickers


    FileView {
        path: Quickshell.shellPath("bar/config/config.json")
        watchChanges: true
        onFileChanged: reload()
        // Invalid JSON must not bring the shell down: the last good values are kept.
        onLoadFailed: error => console.warn("config.json:", FileViewError.toString(error))

        JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                // Default layout (one of the names in config/layouts.json).
                property string layout: "islands"
                // "top" | "bottom" (layouts can enforce their own position)
                property string position: "top"
                property real opacity: 0.92
                // Island background: "surface", "tint", "container", "accent", "glass", "outline"
                // or a fixed color ("#rrggbb"). Can be changed in the HyDE menu.
                property string pillStyle: "tint"
                // Layout to use automatically with each HyDE theme, e.g. { "Catppuccin-Mocha": "minimal" }.
                property var themeLayouts: ({})
            }

            property JsonObject appearance: JsonObject {
                // Language for dates (month and weekday names).
                property string locale: "en_GB"
                property string font: "Inter"
                property string monoFont: "JetBrainsMono Nerd Font"
                property string iconFont: "Material Symbols Rounded"
                property int fontSize: 12
                property int iconSize: 17
                property int radius: 14
                // Multiplier for animation durations (0 disables them).
                property real animationScale: 1
            }

            // Pickers: HyDE's rofi screens ported to the launcher (windows, files, web, emoji, glyphs,
            // themes, wallpapers…), opened with `qs ipc call launcher pick <name>` or from the HyDE
            // menu picker (Super+Shift+A). Paths may start with "~". Times are milliseconds.
            property JsonObject pickers: JsonObject {
                // Pickers that can be opened (by IPC or from the HyDE menu). Removing a name disables it: `pick`
                // falls back to the normal launcher and the HyDE menu hides it. Default: all of them.
                property var enabled: ["themes", "wallpapers", "windows", "files", "web", "emoji", "glyph", "bookmarks", "quickapps", "games", "wallbash", "palette", "animations", "hyprlock", "workflows", "shaders", "layouts", "menu"]

                // The HyDE menu picker ("menu"), in display order. Each entry: `name` (a picker from `enabled`),
                // `description` (row subtitle, also searched) and `glyph` (a Nerd Font character shown as the
                // row icon; "" uses the picker's own glyph if it is a character).
                property var menu: [
                    {
                        "name": "themes",
                        "description": "Switch the HyDE theme",
                        "glyph": "󰏘"
                    },
                    {
                        "name": "wallpapers",
                        "description": "Pick a wallpaper for the current theme",
                        "glyph": "󰸉"
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
                        "description": "Wallpaper palette: pick one of ten colour schemes, dark or light",
                        "glyph": "󰏘"
                    },
                    {
                        "name": "animations",
                        "description": "Window animations",
                        "glyph": ""
                    },
                    {
                        "name": "hyprlock",
                        "description": "Lock screen layout (hyprlock)",
                        "glyph": ""
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
                property var files: ({
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
                property var webPreferred: ["google", "duckduckgo", "youtube", "github", "wikipedia"]
                // Display names for common engines (others get their first letter capitalised).
                property var webLabels: ({
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
                // ranked higher when searching), stored in pickers.json in the shell's state folder.
                // 0–200; defaults emoji 40, glyph 40, bookmarks 10.
                property var recents: ({
                        "emoji": 40,
                        "glyph": 40,
                        "bookmarks": 10
                    })

                // Most rows each picker returns. 50–1000; defaults windows 200, emoji 300, glyph 300,
                // bookmarks 200, games 200 (the launcher also caps at maxShown, for pickers with no
                // entry here). wallpapers has no cap: the folder is the limit, not a row count, and
                // the grid only renders the tiles actually on screen.
                property var maxResults: ({
                        "windows": 200,
                        "emoji": 300,
                        "glyph": 300,
                        "bookmarks": 200,
                        "games": 200,
                        "wallpapers": Infinity
                    })

                // Quick apps ("quickapps") when ~/.config/hyde/config.toml has no [desktop.app].quickapps
                // (HyDE's own default). Desktop ids or commands. Default ["kitty"].
                property var quickAppsFallback: ["kitty"]

                // Direct paste (emoji, glyph and clipboard pickers): after copying, wait this long for the
                // launcher to close and focus to return to the previous window, then send Ctrl+V (skipped for
                // the window classes in HyDE's ignore.paste, terminals by default). Milliseconds, 50–1000,
                // default 150.
                property int pasteDelayMs: 150

                // Most rows the launcher shows for a picker with no entry in pickers.maxResults.
                // 50–1000, default 300.
                property int maxShown: 300

                // Wallpaper picker ("wallpapers"). Folders searched, in grid order; {theme} is the current HyDE
                // theme, {pictures} is $XDG_PICTURES_DIR (or ~/Pictures), {hydeConfig} is ~/.config/hyde; missing
                // folders are skipped. extensions: image types listed. minBytes: smaller files are skipped
                // (broken placeholders). pollMs / busyPollMs: how often the current wallpaper is re-read while
                // the picker is open / while a change is being applied. busyTimeoutMs: give up waiting after this.
                property var wallpapers: ({
                        "dirs": ["{pictures}/Wallpapers", "{pictures}/Wallpapers/{theme}"],
                        "extensions": ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"],
                        "minBytes": 4096,
                        "pollMs": 2000,
                        "busyPollMs": 400,
                        "busyTimeoutMs": 45000
                    })
            }

            property JsonObject widgets: JsonObject {
                property JsonObject workspaces: JsonObject {
                    // Minimum number of workspaces shown, even when empty.
                    property int shown: 5
                    property bool appIcons: true
                    property int maxIcons: 3
                }
                property JsonObject activeWindow: JsonObject {
                    property int maxWidth: 200
                }
                property JsonObject clock: JsonObject {
                    property string format: "HH:mm"
                    property string dateFormat: "ddd, d MMM"
                    property bool showDate: false
                }
                property JsonObject media: JsonObject {
                    property int maxWidth: 200
                    property bool cava: true
                }
                property JsonObject stats: JsonObject {
                    property int interval: 2000
                    property bool cpu: true
                    property bool memory: true
                    property bool temperature: true
                    property bool network: false
                }
                property JsonObject battery: JsonObject {
                    property bool showPercent: true
                    property int lowLevel: 15
                }
                property JsonObject brightness: JsonObject {
                    property bool showPercent: false
                    property int step: 5
                }
                property JsonObject notifications: JsonObject {
                    // Maximum time a popup stays visible (ms); apps can ask for less.
                    property int timeout: 5000
                    property int maxPopups: 4
                    property int historySize: 100
                }
                property JsonObject lock: JsonObject {
                    // false: locking uses HyDE's hyprlock instead of the shell's lock screen.
                    property bool enabled: true
                }
                property JsonObject osd: JsonObject {
                    property bool enabled: true
                    property int timeout: 1500
                }
                property JsonObject audio: JsonObject {
                    property bool showPercent: true
                    property int step: 5
                }
                property JsonObject tray: JsonObject {
                    // Tray icons to hide, by app id (the StatusNotifierItem "Id"). The apps keep
                    // running: nm-applet still asks for Wi-Fi passwords and blueman still handles
                    // PIN pairing, but their icons would repeat the bar's own network/Bluetooth
                    // widgets and open GTK menus. Remove an id to show that icon again.
                    property var hidden: ["nm-applet", "blueman", "udiskie"]
                }
            }
        }
    }
}
