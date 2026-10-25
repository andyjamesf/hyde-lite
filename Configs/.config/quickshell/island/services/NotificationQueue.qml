pragma Singleton
import QtQuick
import Quickshell
import qs.island.config
import qs.island.core
import qs.shared.services

// How the island shows the notifications the shared server announces: one at a time, as a
// transient in the pill. If a surface is open (launcher, control centre…) or another transient is
// showing (an OSD, another notification), the next one waits until the island is back to its base
// mode.
//
// The server itself, the history, peace mode and everything that decides *whether* a notification
// should pop up are in shared/services/Notifications.qml, which both shells use. This file is only
// the island's answer to "and how do I show it?" — the bar's is bar/services/Popups.qml.
Singleton {
    id: root

    // Waiting their turn, and the one on screen.
    property var queue: []
    property var current: null

    // Hides the popup on screen (the notification stays in the history).
    function hideCurrent(): void {
        if (current && IslandController.mode === IslandState.notification)
            IslandController.close();
    }

    // Shows the next one if the island is free (no surface and no other transient).
    function pump(): void {
        if (queue.length === 0 || current || IslandController.mode !== "")
            return;
        const n = queue[0];
        queue = queue.slice(1);
        // `current` before showTransient: the mode change it triggers already finds it.
        current = n;
        if (!IslandController.showTransient(IslandState.notification, n, Notifications.timeoutOf(n))) {
            current = null;
            queue = [n].concat(queue);
        }
    }

    // The notification left the island (time ran out, a click, Esc, another mode on top…).
    function finishCurrent(): void {
        const n = current;
        current = null;
        Notifications.retire(n);
    }

    Connections {
        target: Notifications

        // A new one to show: it replaces one of the same kind, jumps the queue if it is critical,
        // and otherwise lines up.
        function onPopupRequested(n) {
            if (Notifications.sameKind(root.current, n) && IslandController.mode === IslandState.notification) {
                const old = root.current;
                root.current = n;
                if (IslandController.showTransient(IslandState.notification, n, Notifications.timeoutOf(n))) {
                    old.expire();
                    return;
                }
                root.current = old;
            }
            const i = root.queue.findIndex(q => Notifications.sameKind(q, n));
            if (i >= 0) {
                const old = root.queue[i];
                const q = root.queue.slice();
                q[i] = n;
                root.queue = q;
                old.expire();
            } else if (Notifications.isCritical(n)) {
                const j = root.queue.findIndex(q => !Notifications.isCritical(q));
                const q = root.queue.slice();
                q.splice(j < 0 ? q.length : j, 0, n);
                root.queue = q;
            } else {
                root.queue = root.queue.concat([n]);
            }
            root.pump();
        }

        // Peace mode came on, or the history was cleared: what is waiting no longer shows.
        function onPopupsDropped(all) {
            const dropped = all ? root.queue : root.queue.filter(n => !Notifications.isCritical(n));
            root.queue = all ? [] : root.queue.filter(n => Notifications.isCritical(n));
            for (const n of dropped)
                Notifications.retire(n);
        }
    }

    // The island went back to its base mode: the one that was showing is done, and the next can go.
    Connections {
        target: IslandController
        function onModeChanged() {
            if (root.current && IslandController.mode !== IslandState.notification)
                root.finishCurrent();
            if (IslandController.mode === "" && root.queue.length > 0)
                gap.restart();
        }
    }

    // A pause between two popups in a row, so it is clear another one arrived.
    Timer {
        id: gap
        interval: NotificationsConfig.queueGap
        onTriggered: root.pump()
    }

    // Closed by the app (or by us): it leaves the queue and, if it is showing, the island.
    Instantiator {
        model: root.current ? [root.current].concat(root.queue) : root.queue
        delegate: Connections {
            required property var modelData
            target: modelData
            function onClosed() {
                if (modelData === root.current)
                    root.hideCurrent();
                else
                    root.queue = root.queue.filter(q => q !== modelData);
            }
        }
    }
}
