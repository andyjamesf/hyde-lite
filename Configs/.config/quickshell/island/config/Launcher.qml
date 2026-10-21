pragma Singleton
import QtQuick
import Quickshell

// Launcher tunables (components/LauncherView.qml and the services it searches: Apps, Clipboard,
// Calculator, Keybinds and the pickers in services/Pick*.qml).
//
// The launcher is the island's "launcher" mode: a search field on top and a result list below.
// Without a picker, a prefix picks the mode: none = applications, `prefixes.calc` = calculator,
// `prefixes.clipboard` = clipboard history, `prefixes.keys` = Hyprland keybindings. Tab/Shift+Tab
// cycle through `cycleOrder`, keeping what was typed. A picker (services/Pickers.qml, tunables in
// config/PickersConfig.qml) replaces the modes with its own list, as rows or as a grid of tiles.
//
// Sizes are logical pixels; times are milliseconds. Everything here is read live: editing this file
// hot-reloads the shell. Values are plain defaults, not user preferences (those live in Prefs).
// Picker-specific values (file finder, web engines, recents, paste delay…) are in config/PickersConfig.qml.
Singleton {
    // ── Geometry ───────────────────────────────────────────────────────────────────────────────

    // Width of the open launcher. Pixels, 400–900, default 560.
    readonly property int width: 560
    // Corner radius of the island while the launcher is open. Pixels, 12–40, default 24.
    readonly property int radius: 24
    // Height of one result row (apps, clipboard, keybindings, list pickers). Pixels, 40–72, default 52.
    readonly property int rowHeight: 52
    // Rows shown before the list scrolls (the island grows up to this many). 3–12, default 7.
    readonly property int maxRows: 7
    // Side of one square tile in grid pickers (emoji, glyphs). Pixels, 40–96, default 56.
    readonly property int tileSize: 56
    // Tile rows shown before the grid scrolls. 2–8, default 5.
    readonly property int maxGridRows: 5
    // Height of the grid footer that names the selected tile. Pixels, 20–48, default 30.
    readonly property int footer: 30
    // Height of the calculator result area. Pixels, 60–120, default 84.
    readonly property int calcBody: 84
    // Height of the "No results" / "Loading…" line. Pixels, 30–60, default 44.
    readonly property int emptyBody: 44

    // ── Modes ──────────────────────────────────────────────────────────────────────────────────

    // Query prefixes that switch mode (a single character each; must differ). Defaults:
    // calc "=", clipboard ":", keys "?".
    readonly property var prefixes: ({
            "calc": "=",
            "clipboard": ":",
            "keys": "?"
        })
    // Order Tab walks through (Shift+Tab goes backwards). Any permutation of
    // "apps", "clipboard", "calc", "keys"; leaving one out skips it. Default apps → clipboard → calc → keys.
    readonly property var cycleOrder: ["apps", "clipboard", "calc", "keys"]

    // ── Result caps and text lengths ───────────────────────────────────────────────────────────

    // Most rows a picker may show (providers are asked for their best matches first). 50–1000, default 300.
    readonly property int maxPickerResults: 300
    // Most clipboard entries listed. 20–500, default 100.
    readonly property int maxClipboardResults: 100
    // Clipboard row title: first non-empty line, cut to this many characters. 40–500, default 200.
    readonly property int clipTitleChars: 200
    // Clipboard image row subtitle (cliphist's description), cut to this many characters. 40–500, default 160.
    readonly property int clipSubtitleChars: 160

    // ── Search ─────────────────────────────────────────────────────────────────────────────────

    // Picker searches wait this long after the last keystroke (some scan ~10 000 entries, e.g. the
    // glyph picker takes ~55 ms per search). Enter always searches immediately. Milliseconds,
    // 0–500, default 100.
    readonly property int pickerDebounceMs: 100
    // Most applications listed. 10–200, default 50.
    readonly property int appsMaxResults: 50
    // Frecency: each launch counts 1, halving every this many days (recent launches rank higher).
    // Days, 1–60, default 7.
    readonly property real frecencyHalfLifeDays: 7

    // Application ranking. A match scores up to ~120 per field (exact > prefix > word start >
    // substring > subsequence, see services/Fuzzy.qml); each field's score is multiplied by its
    // weight and the best one counts. Weights 0–1; defaults name 1, genericName 0.75,
    // keywords 0.65, id (desktop file name) 0.6, comment 0.4.
    readonly property var fuzzyWeights: ({
            "name": 1,
            "genericName": 0.75,
            "keywords": 0.65,
            "id": 0.6,
            "comment": 0.4
        })
    // Bonus added to a matching app: frecency × frecencyBonusScale, capped at frecencyBonusMax
    // (defaults 4 and 25), plus favoriteBonus for favourites (default 10). Points, 0–50.
    readonly property real frecencyBonusScale: 4
    readonly property real frecencyBonusMax: 25
    readonly property real favoriteBonus: 10
}
