pragma Singleton
import QtQuick
import Quickshell

// ═══════════════════════════════════════════════════════════════════════════════════════════
//  THE MINIMAL BAR — the only file you have to edit
// ═══════════════════════════════════════════════════════════════════════════════════════════
//
//  WHAT IT IS
//  A second, slimmer bar that takes the normal one's place while it is switched on. The modules
//  it shows are the SAME ones the normal bar uses (../../bar/widgets/): nothing here is a copy,
//  so everything that already works there works the same way here — clicks, menus, popouts,
//  tooltips, scrolling on the volume.
//
//  SWITCHING IT ON AND OFF, without editing anything
//      qs ipc call minibar toggle     minimal bar <-> normal bar
//      qs ipc call minibar show       switch the minimal one on
//      qs ipc call minibar hide       back to the normal one
//      qs ipc call minibar status     say which one is in use
//  The key for it is $mod+SHIFT+B. The choice is remembered across restarts (model/MiniBarState).
//
//  EDITING IT
//  Change the values here and save: the file is watched and the bar applies the change on its
//  own, with nothing to restart. To add or drop modules, edit the lists in section 3 — "//" at
//  the start of a line switches that module off.
//
//  IF YOU GET IT WRONG
//  A misspelled module id: the bar does not break, the module simply does not appear and the
//  wrong name is in the log (journalctl --user -u "hyde-*-qsbar.service").
//  A QML syntax error (a missing comma or bracket): the shell cannot load the file — the log
//  names the line. Undo the last change and save again.
//
//  WHERE THE REST OF IT LIVES (see ../README.md)
//      model/       this file and the on/off state
//      view/        the window that draws the bar
//      controller/  the commands behind the IPC target
// ═══════════════════════════════════════════════════════════════════════════════════════════
Singleton {
    id: root

    // ── 1. THE MAIN SWITCH ─────────────────────────────────────────────────────────────────

    // false: the minimal bar stops existing (the IPC target says so and does nothing). This is
    // how to switch it off for good without deleting this file or losing the settings below.
    readonly property bool enabled: true

    // true: while the minimal bar is on, the normal bar hides — one OR the other.
    // false: both are shown at once (say the normal one on top and the minimal one at the
    //        bottom), but then the minimal bar does NOT apply the height, style and position
    //        from section 2: the modules read those from the BarLayout service, which is shared
    //        by both bars, and the normal one would be drawn with the minimal one's measurements.
    //        With `false`, then, the minimal bar is just a second row of modules in the normal
    //        bar's shape.
    readonly property bool hideMainBar: true

    // ── 2. POSITION AND SHAPE ──────────────────────────────────────────────────────────────
    // (everything in this section only applies with hideMainBar: true — see above)

    // "top" | "bottom"
    readonly property string position: "top"

    // "continuous"  a thin strip from edge to edge, against the edge of the screen
    // "islands"     rounded groups that float, each with its own background
    // "none"        no background at all: only the icons and the text over the wallpaper
    readonly property string style: "continuous"

    // Bar height in px. 0 = the same as the normal bar's. Clamped to 16–40.
    readonly property int height: 20

    // Margin between the bar and the edge of the screen. Only counts in the "islands" style.
    readonly property int margin: 4

    // Space in px between groups of modules (the lines in section 3).
    readonly property int spacing: 8

    // Background opacity: 0 = invisible, 1 = opaque. -1 = the normal bar's.
    readonly property real opacity: 0.92

    // Background colour. "" = the theme's colour (follows matugen, which is the one to want).
    // Or a fixed colour, say "#1e1e2e" — the transparency always comes from `opacity` above, so
    // there is no point writing the colour with an alpha ("#1e1e2ecc"): that alpha is ignored.
    readonly property string color: ""

    // Corner rounding in the "islands" style. -1 = follows Hyprland's `decoration:rounding`,
    // the way the normal bar does.
    readonly property int radius: -1

    // Text and icon size. 0 = worked out from the height (what you want).
    readonly property int fontSize: 0
    readonly property int iconSize: 0

    // false: the bar floats over the windows and takes no space from them, so a window can use
    //        the whole screen and the bar sits on top of it. This is the default here.
    // true:  windows open below the bar, which reserves its own strip of the screen (what the
    //        normal bar does).
    readonly property bool reserveSpace: false

    // ── HIDING THE BAR ─────────────────────────────────────────────────────────────────────

    // true:  the bar keeps itself off the screen edge and only a thin strip of it takes the
    //        pointer, so the window underneath keeps the clicks; moving the pointer onto that
    //        strip slides the bar back in, and it slides away again when the pointer leaves.
    //        While hidden it reserves no space at all, whatever `reserveSpace` says above.
    // false: the bar is always on screen (it still takes no space from windows unless
    //        `reserveSpace` is true).
    readonly property bool autoHide: false

    // How long the pointer has to be away before the bar hides again, in milliseconds. It never
    // hides while one of its own panels is open (the calendar, the volume panel…).
    readonly property int hideDelay: 700

    // How much of the bar is left on the screen edge while it is hidden, in px: the strip to touch
    // to bring it back. 2 is enough for a mouse; raise it if you find it hard to hit.
    readonly property int peek: 2

    // Which monitors it appears on. [] = all of them.
    // Or only some, by the names `hyprctl monitors` prints: ["DP-1", "HDMI-A-1"]
    readonly property var screens: []

    // ── 3. MODULES ─────────────────────────────────────────────────────────────────────────
    //
    // Each line of the three lists is a GROUP of modules:
    //     ["audio", "network", "battery"]   the three together, in one block/island
    //     ["clock"]                         one module alone in its own block
    // Between groups goes the `spacing` from section 2. A group whose modules have nothing to
    // show (no battery, no bluetooth…) disappears on its own and leaves no empty space.
    //
    // TO SWITCH A MODULE OFF: put "//" at the start of its line.
    // TO SWITCH ONE ON:       drop the "//", or write a new line.
    // Every line ends in a comma on purpose: that way any one of them can be commented out,
    // the last one included, without having to fix the other lines' commas.
    //
    // THE WHOLE CATALOGUE (the ids come from services/BarWidgets.qml; all of them already exist)
    //   "hyde"           HyDE menu: themes, wallpapers, keybindings
    //   "workspaces"     Hyprland's workspaces
    //   "activeWindow"   title of the focused window
    //   "clock"          clock; a click opens the calendar
    //   "media"          the track that is playing (MPRIS); a click opens the controls
    //   "cava"           audio visualiser
    //   "aiUsage"        the AI tools' usage
    //   "tray"           system tray icons
    //   "audio"          volume; a click opens the panel, the wheel changes it
    //   "mic"            microphone
    //   "brightness"     screen brightness
    //   "network"        network / Wi-Fi
    //   "bluetooth"      bluetooth
    //   "battery"        battery
    //   "stats"          CPU, memory and temperature
    //   "idle"           idle inhibitor (keeps the screen from going off)
    //   "nightLight"     night light
    //   "notifications"  notifications and "do not disturb"
    //   "controlCenter"  the control centre's button
    //   "power"          power menu
    //
    // Each module's own options (clock format, brightness step and so on) stay in
    // config/config.json, section "widgets" — they are shared with the normal bar.

    // LEFT
    readonly property var left: [
        ["workspaces"],             // which desktop you are on
        // ["activeWindow"],        // title of the focused window
        // ["hyde"],                // HyDE menu
    ]

    // CENTRE (if it does not fit between the sides, it hides instead of overlapping them)
    readonly property var center: [
        // The clock also shows the day when config.json has widgets.clock.showDate (that setting,
        // and the two date formats next to it, are shared with the normal bar).
        ["clock"],                  // time and day
        // ["media"],               // the track that is playing
    ]

    // RIGHT — nothing for now. Drop the "//" from a line to put that group back.
    readonly property var right: [
        // ["audio", "network", "battery"],   // volume, network, battery
        // ["tray"],                          // system tray
        // ["mic", "brightness"],             // microphone and brightness
        // ["bluetooth"],                     // bluetooth
        // ["stats"],                         // CPU / memory / temperature
        // ["media"],                         // the track that is playing
        // ["cava"],                          // audio visualiser
        // ["aiUsage"],                       // the AI tools' usage
        // ["nightLight", "idle"],            // night light and idle inhibitor
        // ["notifications"],                 // notifications and "do not disturb"
        // ["controlCenter", "power"],        // control centre and power menu
    ]
}
