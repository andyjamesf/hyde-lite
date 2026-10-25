pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server, shared by every UI of this configuration: one server, one history, one
// peace mode, however many shells show them.
//
// What it does NOT do is decide how a popup looks or when: the island shows one at a time, through
// its pill, and the bar shows a stack in a corner. That is each shell's policy, so this announces
// an arrival with `popupRequested` and the shell takes it from there
// (island/services/NotificationQueue.qml, bar/services/Popups.qml).
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

    // A notification that should be shown as a popup. Each shell shows it its own way.
    signal popupRequested(var notification)
    // Whatever is waiting to be shown should not be: everything, or only the non-critical ones.
    signal popupsDropped(bool all)

    function dropPopups(all: bool): void {
        popupsDropped(all);
    }

    // Tunables. A shared service has no settings file of its own, so each shell binds these from
    // its own (the island from config/NotificationsConfig.qml, the bar from config.json).
    property int historySize: 100
    property int normalTimeout: 5000
    property int criticalTimeout: 10000
    property bool criticalBypassesPeace: true
    property bool filterHydeOsd: true
    property bool transientLayoutAlert: true

    // There is always a server here (the shells replace swaync/dunst), so a widget asking whether
    // notifications work at all gets a yes; the bar's service had this and used it.
    readonly property bool available: true

    // History, newest first.
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length


    // Arrival time of each notification (the protocol does not carry it).
    property var times: ({})

    // "Peace mode" in the island, "Silent" in the bar: no popups, history only (critical ones
    // still come through, see criticalBypassesPeace). It is kept here rather than in either
    // shell's Prefs, which are not shared; the old keys in those files are no longer read.
    property alias peaceMode: state.peaceMode
    // The bar called it this.
    readonly property bool dnd: peaceMode

    function toggleDnd(): void {
        togglePeace();
    }

    function togglePeace(): void {
        const on = !peaceMode;
        state.peaceMode = on;
        stateFile.writeAdapter();
        // Turning it on: whatever is waiting to pop up no longer should, except the critical ones.
        if (on)
            dropPopups(false);
    }

    function clear(): void {
        dropPopups(true);
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function dismiss(n) {
        n?.dismiss();
    }


    function timeOf(n) {
        return times[n?.id] ?? new Date();
    }

    function isCritical(n) {
        return n?.urgency === NotificationUrgency.Critical;
    }

    // Critical notifications that still pop up in peace mode.
    function bypassesPeace(n) {
        return criticalBypassesPeace && isCritical(n);
    }

    function isHydeOsd(n) {
        // The path passed with `notify-send -i` may arrive in appIcon or in image.
        return filterHydeOsd && n.appName === "HyDE Notify" && `${n.appIcon} ${n.image}`.includes("/Wallbash-Icon/media/");
    }

    // HyDE's keyboard-layout alert (keyboardswitch.sh: `notify-send -a "HyDE Alert" -r 91190
    // -i …/Wallbash-Icon/keyboard.svg <layout>`): a short popup, never kept in the history.
    function isHydeLayoutAlert(n) {
        return transientLayoutAlert && n.appName === "HyDE Alert" && `${n.appIcon} ${n.image}`.includes("/Wallbash-Icon/keyboard");
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

        if (popup)
            popupRequested(n);
    }


    // Survives reloads of the island (see onArrived).
    FileView {
        id: stateFile
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: state
            property bool peaceMode: false
        }
    }

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

}
