pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.core

// The island's notification server. Tunables: config/NotificationsConfig.qml.
//
// - Every notification goes to the history (up to `historySize`, newest first), except the ones the
//   app marks as "transient" (and HyDE's keyboard-layout alert), which only show as a popup and
//   leave once seen.
// - Popups enter a queue and appear one at a time in the island, as a transient. If the user has a
//   surface open (launcher, control center…) or another transient is showing (OSD, another
//   notification), they wait until the island is back to its base mode.
// - Peace mode: no popups, history only. Critical ones still pop up (criticalBypassesPeace).
// - Volume/brightness notifications from HyDE's scripts are ignored: the island has its own OSD.
Singleton {
    id: root

    readonly property int historySize: NotificationsConfig.historySize
    readonly property int normalTimeout: NotificationsConfig.normalTimeout
    readonly property int criticalTimeout: NotificationsConfig.criticalTimeout
    // Pause between two popups in a row, so it is clear another one arrived.
    readonly property int queueGap: NotificationsConfig.queueGap

    // History, newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length

    // Popups waiting in the queue and the one showing.
    property var queue: []
    property var current: null

    // Arrival time of each notification (the protocol does not carry it).
    property var times: ({})

    readonly property bool peaceMode: Prefs.get("notifications.peaceMode", false)

    function togglePeace() {
        const on = !peaceMode;
        Prefs.set("notifications.peaceMode", on);
        // When turning it on, the normal ones still waiting no longer show (they stay in the history).
        if (on) {
            const dropped = queue.filter(n => !isCritical(n));
            queue = queue.filter(n => isCritical(n));
            for (const n of dropped)
                retire(n);
        }
    }

    function clear() {
        queue = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function dismiss(n) {
        n?.dismiss();
    }

    // Hides the popup on screen (the notification stays in the history).
    function hideCurrent() {
        if (current && IslandController.mode === IslandState.notification)
            IslandController.close();
    }

    function timeOf(n) {
        return times[n?.id] ?? new Date();
    }

    function isCritical(n) {
        return n?.urgency === NotificationUrgency.Critical;
    }

    // Critical notifications that still pop up in peace mode.
    function bypassesPeace(n) {
        return NotificationsConfig.criticalBypassesPeace && isCritical(n);
    }

    function isHydeOsd(n) {
        // The path passed with `notify-send -i` may arrive in appIcon or in image.
        return NotificationsConfig.filterHydeOsd && n.appName === "HyDE Notify" && `${n.appIcon} ${n.image}`.includes("/Wallbash-Icon/media/");
    }

    // HyDE's keyboard-layout alert (keyboardswitch.sh: `notify-send -a "HyDE Alert" -r 91190
    // -i …/Wallbash-Icon/keyboard.svg <layout>`): a short popup, never kept in the history.
    function isHydeLayoutAlert(n) {
        return NotificationsConfig.transientLayoutAlert && n.appName === "HyDE Alert" && `${n.appIcon} ${n.image}`.includes("/Wallbash-Icon/keyboard");
    }

    // Shown as a popup only, then removed (marked transient by the app, or treated as such here).
    function isTransient(n) {
        return !!n && (n.transient || isHydeLayoutAlert(n));
    }

    // Icon/image to show: the notification's image, or the app icon (path or theme name).
    function imageOf(n) {
        if (!n)
            return "";
        if (n.image)
            return n.image;
        const icon = n.appIcon || n.desktopEntry || "";
        if (icon.startsWith("/"))
            return `file://${icon}`;
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;
        return icon ? Quickshell.iconPath(icon, true) : "";
    }

    // Time on screen: normalTimeout (or less, if the app asks), criticalTimeout for critical ones.
    // `expireTimeout` is in milliseconds (the protocol value); ≤ 0 means "the server decides".
    function timeoutOf(n) {
        if (isCritical(n))
            return criticalTimeout;
        const asked = Math.round(n.expireTimeout ?? 0);
        return asked > 0 ? Math.min(asked, normalTimeout) : normalTimeout;
    }

    function sameKind(a, b) {
        return a && b && a !== b && a.appName === b.appName && a.summary === b.summary;
    }

    // A notification that will no longer be (or stopped being) shown: transient ones leave for good.
    function retire(n) {
        if (n && isTransient(n) && n.tracked)
            n.expire();
    }

    // Identity of a notification across a reload of the island (the id alone could repeat if the
    // server's counter restarted).
    function keyOf(n) {
        return `${n.id}|${n.appName}|${n.summary}`;
    }

    // persist.arrivedJson as an object ({} if unreadable: then nothing is lost, at worst a popup
    // shows again).
    function readArrived() {
        try {
            return JSON.parse(persist.arrivedJson || "{}") ?? {};
        } catch (e) {
            return {};
        }
    }

    function onArrived(n) {
        if (isHydeOsd(n))
            return;

        // keepOnReload: after the island reloads, the server hands every kept notification over
        // again. Those are not new: back into the history with their real arrival time, no popup.
        const arrived = readArrived();
        const known = arrived[keyOf(n)];
        if (known !== undefined) {
            n.tracked = true;
            const t = Object.assign({}, times);
            t[n.id] = new Date(known);
            times = t;
            return;
        }

        const popup = !peaceMode || bypassesPeace(n);
        // A transient without a popup is useless: it is not kept (it is discarded).
        if (!popup && isTransient(n))
            return;
        n.tracked = true;

        const t = Object.assign({}, times);
        t[n.id] = new Date();
        times = t;
        // Remembered across reloads; entries of notifications no longer kept are dropped.
        const keep = {};
        for (const x of server.trackedNotifications.values) {
            const k = keyOf(x);
            if (arrived[k] !== undefined)
                keep[k] = arrived[k];
        }
        keep[keyOf(n)] = t[n.id].getTime();
        persist.arrivedJson = JSON.stringify(keep);

        // Limited history: the oldest ones leave.
        const tracked = server.trackedNotifications.values;
        for (let i = 0; i < tracked.length - historySize; i++)
            tracked[i].expire();

        if (!popup)
            return;

        // Same app and same title as the popup on screen (e.g. switching layouts several times in a row):
        // the new one replaces it and the countdown restarts. notify-send's `-r` would only do that if
        // the app knew the id the server gave it.
        if (sameKind(current, n) && IslandController.mode === IslandState.notification) {
            const old = current;
            current = n;
            if (IslandController.showTransient(IslandState.notification, n, timeoutOf(n))) {
                old.expire();
                return;
            }
            current = old;
        }

        // Same in the queue: the new one takes the old one's place.
        const i = queue.findIndex(q => sameKind(q, n));
        if (i >= 0) {
            const old = queue[i];
            const q = queue.slice();
            q[i] = n;
            queue = q;
            old.expire();
        } else if (isCritical(n)) {
            // Critical ones jump ahead of the normal ones.
            const j = queue.findIndex(q => !isCritical(q));
            const q = queue.slice();
            q.splice(j < 0 ? q.length : j, 0, n);
            queue = q;
        } else {
            queue = queue.concat([n]);
        }
        pump();
    }

    // Shows the next in the queue if the island is free (no surface nor another transient).
    function pump() {
        if (queue.length === 0 || current || IslandController.mode !== "")
            return;
        const n = queue[0];
        queue = queue.slice(1);
        // `current` before showTransient: the mode change it triggers already finds it.
        current = n;
        if (!IslandController.showTransient(IslandState.notification, n, timeoutOf(n))) {
            current = null;
            queue = [n].concat(queue);
        }
    }

    // The notification left the island (time ran out, click, Esc, another mode on top…).
    function finishCurrent() {
        const n = current;
        current = null;
        retire(n);
    }

    // Survives reloads of the island (see onArrived).
    PersistentProperties {
        id: persist
        reloadableId: "islandNotifications"
        // JSON of keyOf(n) → arrival time in ms. A string: a JS object can't cross into the new
        // QML engine of a reload ("JSValue can't be reassigned to another engine").
        property string arrivedJson: "{}"
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true

        onNotification: n => root.onArrived(n)
    }

    // The island stopped showing the notification → it is done; when the island is free, the next one.
    Connections {
        target: IslandController
        function onModeChanged() {
            if (IslandController.mode !== IslandState.notification && root.current)
                root.finishCurrent();
            if (IslandController.mode === "" && root.queue.length > 0)
                gap.restart();
        }
    }

    Timer {
        id: gap
        interval: root.queueGap
        onTriggered: root.pump()
    }

    // Closed by the app (or by us): leaves the queue and, if showing, the island.
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
