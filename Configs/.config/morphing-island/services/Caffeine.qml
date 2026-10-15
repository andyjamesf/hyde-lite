pragma Singleton
import QtQuick
import Quickshell

// Caffeine: keeps the session awake (no dimming, locking or suspend by hypridle) while on. The
// inhibitor itself is an IdleInhibitor on each island window (core/IslandWindow.qml); this only
// holds the state, persisted as the Prefs key "idle.caffeine" so it survives reloads and restarts.
// It can also be on for a while (right-click menu): "idle.caffeineUntil" holds the end time.
Singleton {
    id: root

    readonly property bool active: Prefs.get("idle.caffeine", false)
    // When it turns itself off (ms since the epoch); 0 = stays on until turned off.
    readonly property real until: Prefs.get("idle.caffeineUntil", 0)
    // "1 h 20 min left", or "" when it has no end.
    readonly property string remaining: {
        if (!active || until <= 0)
            return "";
        const m = Math.max(1, Math.round((until - Time.now.getTime()) / 60000));
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min left` : `${m} min left`;
    }

    function toggle() {
        if (active)
            off();
        else
            Prefs.set("idle.caffeine", true);
    }

    function off() {
        Prefs.reset("idle.caffeine");
        Prefs.reset("idle.caffeineUntil");
    }

    // On for `minutes` (0 = until turned off).
    function enableFor(minutes) {
        Prefs.set("idle.caffeine", true);
        if (minutes > 0)
            Prefs.set("idle.caffeineUntil", Date.now() + minutes * 60000);
        else
            Prefs.reset("idle.caffeineUntil");
    }

    Timer {
        interval: 20000
        running: root.active && root.until > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (Date.now() >= root.until)
            root.off()
    }
}
