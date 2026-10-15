pragma Singleton
import QtQuick
import Quickshell

// The island's modes (one central state; no booleans scattered around).
Singleton {
    // Base (depend only on hover/pin)
    readonly property string clock: "clock"
    readonly property string expanded: "expanded"
    // Transients: appear by themselves and return to the base mode
    readonly property string volume: "volume"
    readonly property string mic: "mic"
    readonly property string brightness: "brightness"
    readonly property string notification: "notification"
    readonly property string screenshot: "screenshot"
    // Surfaces opened by the user (the island keeps the focus until Esc or a click outside)
    readonly property string launcher: "launcher"
    readonly property string controlCenter: "controlcenter"
    readonly property string wifi: "wifi"
    readonly property string bluetooth: "bluetooth"
    readonly property string audio: "audio"
    readonly property string media: "media"
    readonly property string battery: "battery"
    readonly property string system: "system"
    readonly property string theme: "theme"
    readonly property string wallpaper: "wallpaper"
    readonly property string settings: "settings"
    readonly property string power: "power"
    readonly property string auth: "auth"
    readonly property string calendar: "calendar"
    // AI usage popup (the AI icon).
    readonly property string ai: "ai"
    // Wi-Fi password or Bluetooth pairing request (services/Agents.qml).
    readonly property string agent: "agent"
    // Workspace overview (components/OverviewView.qml).
    readonly property string overview: "overview"
    // Scratch page (components/NotepadView.qml).
    readonly property string notepad: "notepad"
    // Weather (components/WeatherView.qml), from the "weather" status icon.
    readonly property string weather: "weather"

    readonly property var transients: [volume, mic, brightness, notification, screenshot]
    readonly property var surfaces: [launcher, controlCenter, wifi, bluetooth, audio, media, battery, system, theme, wallpaper, settings, power, auth, calendar, agent, ai, overview, notepad, weather]
    // Surfaces that take the keyboard exclusively: text input, and the pickers with a grid (so
    // arrows and Enter work without clicking first).
    readonly property var keyboardModes: [launcher, auth, settings, theme, wallpaper, power, calendar, agent, overview, notepad]
    // Control center subviews (Esc goes back to the control center, not to the clock).
    readonly property var subviews: [wifi, bluetooth, audio, media, battery, system]

    function isTransient(m) {
        return transients.includes(m);
    }
    function isSurface(m) {
        return surfaces.includes(m);
    }
}
