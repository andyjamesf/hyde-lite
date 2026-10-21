pragma Singleton
import QtQuick
import Quickshell

// Notification server and popups. (Named NotificationsConfig because services/Notifications.qml
// is the server.) Peace mode is toggled from the control center / IPC and stored as the Prefs key
// "notifications.peaceMode".
Singleton {
    // Maximum notifications kept in the history (oldest leave first). 1–1000, default 100.
    readonly property int historySize: 100
    // Time a normal popup stays visible (apps may ask for less, never more). Milliseconds,
    // default 5000.
    readonly property int normalTimeout: 5000
    // Time a critical popup stays visible. Milliseconds, default 12000.
    readonly property int criticalTimeout: 12000
    // Pause between two queued popups, so it is clear another one arrived. Milliseconds, default 220.
    readonly property int queueGap: 220
    // Critical notifications still pop up in peace mode. Default true.
    readonly property bool criticalBypassesPeace: true
    // Ignore HyDE's volume/brightness notifications (the island has its own OSD). Default true.
    readonly property bool filterHydeOsd: true
    // Treat HyDE's keyboard-layout alert ("HyDE Alert" with the keyboard icon) as transient: it
    // pops up but is never kept in the history. Default true.
    readonly property bool transientLayoutAlert: true

    // Popup layout.
    // Minimum / maximum popup width in pixels. Defaults 360 / 460.
    readonly property int minWidth: 360
    readonly property int maxWidth: 460
    // Corner radius of the island while showing a popup, in pixels. Default 22.
    readonly property int radius: 22
    // Inner padding in pixels. Default 14.
    readonly property int padding: 14
    // App icon / image size in pixels. Default 40.
    readonly property int avatarSize: 40
    // Maximum action buttons shown (extra actions are dropped). Default 3.
    readonly property int maxActions: 3
    // Maximum lines of the title and of the body before eliding. Defaults 2 / 2.
    readonly property int summaryLines: 2
    readonly property int bodyLines: 2
}
