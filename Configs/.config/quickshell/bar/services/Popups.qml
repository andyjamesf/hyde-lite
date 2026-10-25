pragma Singleton
import QtQuick
import Quickshell
import qs.shared.services

// How the bar shows the notifications the shared server announces: a stack in the corner, several
// at once, each going away on its own. The island shows one at a time instead
// (island/services/NotificationQueue.qml); the server, the history and peace mode are shared
// (shared/services/Notifications.qml).
Singleton {
    id: root

    // On screen right now, newest first.
    property var list: []
    // At most this many at once; the rest wait for one to go.
    property int max: 3

    // Takes one off the screen. A transient one is not kept in the history, so it goes for good.
    function hide(n): void {
        list = list.filter(p => p !== n);
        Notifications.retire(n);
    }

    Connections {
        target: Notifications

        function onPopupRequested(n) {
            // Same app and same title as one still on screen (switching layouts a few times in a
            // row, say): the new one replaces it instead of stacking up.
            for (const old of root.list.filter(p => p !== n && Notifications.sameKind(p, n))) {
                root.list = root.list.filter(p => p !== old);
                old.expire();
            }
            root.list = [n].concat(root.list.filter(p => p !== n)).slice(0, root.max);
        }

        function onPopupsDropped(all) {
            const dropped = all ? root.list : root.list.filter(n => !Notifications.isCritical(n));
            root.list = all ? [] : root.list.filter(n => Notifications.isCritical(n));
            for (const n of dropped)
                Notifications.retire(n);
        }
    }

    // A notification closed by the app (or by us) leaves the screen.
    Instantiator {
        model: root.list
        delegate: Connections {
            required property var modelData
            target: modelData
            function onClosed() {
                root.list = root.list.filter(p => p !== modelData);
            }
        }
    }
}
