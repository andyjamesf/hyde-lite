pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Status pill: a small pill with the battery and other status at a glance (the mirror of the
// workspace pill on the left). With the clock pill showing it sits at the screen's right edge (or
// next to the clock); when the island expands it slides into it, whose right zone shows the status.
Singleton {
    // Show the status pill at all. Default true.
    readonly property bool enabled: Prefs.get("statusPill.enabled", true)
    // Where it sits: "right" = the screen's right edge, "clock" = just right of the clock pill.
    // Default "right".
    readonly property string placement: Prefs.get("statusPill.nearClock", false) ? "clock" : "right"
    // Distance from the screen's right edge ("right" placement), in pixels. Default 12.
    readonly property int edgeMargin: 12
    // Space between the status pill and the clock pill ("clock" placement), in pixels. Default 8.
    readonly property int gap: 8
    // Inner padding at each end of the pill, in pixels. Default 12.
    readonly property int padding: 12

    // What it shows, in this order. Each icon is a button (the same in the expanded island):
    //   "caffeine"       dim when off, accent when on; click turns it on/off
    //   "notifications"  bell with the unread count (crossed out in peace mode); click opens the
    //                    notification center
    //   "volume"         click: audio page · middle click: mute · scroll: volume
    //   "bluetooth"      click: Bluetooth page
    //   "wifi"           click: network page (also shows wired)
    //   "battery"        percentage inside, time left next to it; hidden on PCs without one;
    //                    click: control center
    //   "power"          click: power menu (log out, suspend, restart, shut down)
    //   "updates"        only while updates wait, with their number (config/UpdatesConfig.qml);
    //                    click: a terminal lists them and asks before updating
    //   "ai"             AI usage, only the symbol (config/AiUsageConfig.qml); click: the AI
    //                    popup with every tool's limits; hidden when the usage scripts are missing
    // Prefs key "statusPill.icons" (a list of ids) overrides it, live, from prefs.json.
    // Default ["updates", "ai", "caffeine", "notifications", "volume", "bluetooth", "wifi", "battery", "power"].
    readonly property var icons: Prefs.get("statusPill.icons", ["weather", "vpn", "updates", "ai", "caffeine", "notifications", "volume", "bluetooth", "wifi", "battery", "power"])
    // Battery percentage, inside the battery icon. Default true.
    readonly property bool batteryPercent: true
    // Time left next to the battery: until empty on battery, until full while charging ("3h 12m";
    // hidden while UPower has no estimate yet, and when plugged in and full). Default true.
    readonly property bool batteryTime: true
    // Keep the bell visible with no unread notifications, as the way into the notification center.
    // false = only with unread ones or in peace mode. Default true.
    readonly property bool alwaysShowBell: true
}
