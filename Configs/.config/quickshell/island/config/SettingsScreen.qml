pragma Singleton
import QtQuick
import Quickshell

// The Settings screen (island mode "settings"). Values changed there are stored as overrides in
// <XDG_STATE_HOME>/morphing-island/prefs.json (services/Prefs.qml) and win over the defaults in the
// other config files; "Reset to defaults" removes them (the file defaults apply again).
Singleton {
    // Width of the screen in pixels. Default 480.
    readonly property int width: 480
    // Maximum height in pixels; the body scrolls beyond it. Default 620.
    readonly property int maxHeight: 620

    // The icons the Settings screen offers for statusPill.icons and expanded.extraButtons, as { id, label }.
    // The ids are the ones components/StatusZone.qml draws (tools/tests/test_icon_list_editor.py keeps the
    // two in step); a plugin's id still works in prefs.json and shows up in the editor by its id.
    readonly property var statusIconChoices: [
        { id: "updates", label: "Updates" },
        { id: "ai", label: "AI usage" },
        { id: "weather", label: "Weather" },
        { id: "caffeine", label: "Caffeine" },
        { id: "notifications", label: "Notifications" },
        { id: "volume", label: "Volume" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "wifi", label: "Network" },
        { id: "battery", label: "Battery" },
        { id: "power", label: "Power" },
        { id: "clock", label: "Clock" },
        { id: "date", label: "Date" },
        { id: "mic", label: "Microphone" },
        { id: "brightness", label: "Brightness" },
        { id: "media", label: "Now playing" }
    ]
    // What a pill can hold: the status widgets and the workspace indicator.
    readonly property var pillWidgetChoices: [{ id: "workspaces", label: "Workspaces" }].concat(statusIconChoices)
    readonly property var shortcutChoices: [
        { id: "nightlight", label: "Night light" },
        { id: "screenshot", label: "Screenshot" },
        { id: "clipboard", label: "Clipboard" },
        { id: "picker", label: "Colour picker" },
        { id: "wallpaper", label: "Wallpaper" },
        { id: "theme", label: "Theme" },
        { id: "settings", label: "Settings" },
        { id: "lock", label: "Lock" },
        { id: "power", label: "Power" },
        { id: "system", label: "System" },
        { id: "nextwallpaper", label: "Next wallpaper" },
        { id: "hydetheme", label: "HyDE theme" },
        { id: "keybindings", label: "Keybindings" }
    ]

    // Slider ranges.
    // Pill height (Pill.height) in pixels. Defaults 30–51.
    readonly property int barHeightMin: 30
    readonly property int barHeightMax: 51
    // Distance from the top edge to the pill (Pill.topMargin) in pixels. Defaults 0–24.
    readonly property int topMarginMin: 0
    readonly property int topMarginMax: 24
    // Base font size (Appearance.fontSize) in pixels. Defaults 11–18.
    readonly property int fontSizeMin: 11
    readonly property int fontSizeMax: 18
    // Animation speed multiplier (Animations.speed). Defaults 0.5–2, step 0.1.
    readonly property real speedMin: 0.5
    readonly property real speedMax: 2
    readonly property real speedStep: 0.1

    // Changes are written to prefs.json after this pause (sliders apply live, the file is written
    // once the drag settles). Milliseconds, default 300.
    readonly property int saveDebounceMs: 300

    // Prefs keys removed by "Reset to defaults". Theme and wallpaper are left alone (they have their
    // own pickers).
    readonly property var resetKeys: ["pill.height", "appearance.fontSize", "pill.hoverExpand", "notifications.peaceMode", "animations.enabled", "animations.speed", "statusPill.icons", "expanded.extraButtons", "pill.topMargin", "clock.hour12", "statusPill.enabled", "statusPill.nearClock", "pills.extra"]
}
