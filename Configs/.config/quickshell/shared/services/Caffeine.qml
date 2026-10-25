pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine: keeps the session awake — no dimming, no locking, no suspending by hypridle — while it
// is on. Shared by every UI of this configuration.
//
// This only holds the state. The inhibitor itself is an IdleInhibitor on each shell's windows,
// which is the only way to hold one: it needs a window, and the windows belong to the shells
// (island/core/IslandWindow.qml, bar/modules/bar/Bar.qml and the minimal bar's).
//
// It is the island's service: the bar had a plain boolean on ShellState that was lost on every
// reload, and no way to say "stay awake for an hour". The state lives in a file of its own, as the
// shared notification server's does, because neither shell's Prefs is shared; the island's old
// "idle.caffeine" keys are no longer read.
Singleton {
    id: root

    readonly property bool active: state.on
    // When it turns itself off (ms since the epoch); 0 = until it is turned off by hand.
    readonly property real until: state.until
    // "1 h 20 min left", or "" when it has no end.
    readonly property string remaining: {
        if (!active || until <= 0)
            return "";
        const m = Math.max(1, Math.round((until - tick.now) / 60000));
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min left` : `${m} min left`;
    }

    function toggle(): void {
        if (active)
            off();
        else
            enableFor(0);
    }

    function off(): void {
        state.on = false;
        state.until = 0;
        stateFile.writeAdapter();
    }

    // On for `minutes` (0 = until turned off).
    function enableFor(minutes: int): void {
        state.on = true;
        state.until = minutes > 0 ? Date.now() + minutes * 60000 : 0;
        stateFile.writeAdapter();
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("caffeine.json")
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: state
            property bool on: false
            property real until: 0
        }
    }

    // Ticks only while there is a countdown to show, so `remaining` keeps up with the minute.
    QtObject {
        id: tick
        property real now: Date.now()
    }

    Timer {
        interval: 20000
        running: root.active && root.until > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tick.now = Date.now();
            if (tick.now >= root.until)
                root.off();
        }
    }
}
