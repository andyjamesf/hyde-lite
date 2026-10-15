pragma Singleton
import QtQuick
import Quickshell

// Control center (island modes "controlcenter", "wifi", "bluetooth", "audio", "media").
Singleton {
    // Width of the control center in pixels. Default 440.
    readonly property int width: 440
    // Corner radius of the island while the control center is open, in pixels. Default 26.
    readonly property int radius: 26
    // Inner padding and spacing between blocks, in pixels. Defaults 16 / 12.
    readonly property int padding: 16
    readonly property int spacing: 12
    // Page slide (main page ↔ wifi/bluetooth/audio/media). Milliseconds before Animations.speed,
    // default 340.
    readonly property int slideMs: 340

    // Quick-toggle tiles, in order, two per row (an odd last tile takes the whole row). Known ids:
    // "wifi", "bluetooth", "sound", "mic" (microphone on/off), "peace" (peace mode: no popups),
    // "nightlight", "caffeine" (keep the session awake), "profile" (power profile: saver, balanced,
    // performance; the arrow opens the battery page). Remove an id to hide that tile.
    // Default ["wifi", "bluetooth", "sound", "mic", "peace", "nightlight", "caffeine", "profile"].
    readonly property var tiles: ["wifi", "bluetooth", "sound", "mic", "peace", "nightlight", "caffeine", "profile"]
    // HyDE shortcuts under the media row, in order: "nextwallpaper", "wallpaper" (the picker),
    // "hydetheme" (HyDE themes), "animations", "keybindings". [] hides the row.
    readonly property var shortcuts: ["nextwallpaper", "wallpaper", "hydetheme", "animations", "keybindings"]
    // Tile height in pixels. Default 56.
    readonly property int tileHeight: 56

    // Notification history on the main page: row height in pixels and rows visible before scrolling.
    // Defaults 46 / 4.
    readonly property int notificationRowHeight: 46
    readonly property int maxNotificationRows: 4

    // Wi-Fi and Bluetooth pages: row height in pixels and rows visible before scrolling.
    // Defaults 50 / 6.
    readonly property int listRowHeight: 50
    readonly property int maxListRows: 6
    // Audio page: maximum height of the device list area in pixels (scrolls beyond). Default 400.
    readonly property int audioMaxBodyHeight: 400

    // Sliders that start a process per change (brightness via brightnessctl) send at most one value
    // per this interval while dragging. Milliseconds, default 60 (~16 per second).
    readonly property int sliderThrottleMs: 60
    // Bluetooth discovery stops by itself after this long. Milliseconds, default 30000.
    readonly property int btDiscoveryMs: 30000
    // Night light colour temperature (hyprsunset, through HyDE's script), used when turning it on while
    // HyDE's saved temperature is neutral (≥ 6000 K); otherwise HyDE's own saved temperature is kept.
    // Kelvin, 1000–20000 (lower = warmer), default 4000.
    readonly property int nightLightTemperature: 4000
}
