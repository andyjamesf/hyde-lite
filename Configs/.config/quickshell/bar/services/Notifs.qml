pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell's notification server (replaces HyDE's swaync/dunst).
//
// - All notifications are kept in the history (up to `historySize`), except those marked as
//   "transient" by the app, which only show up as a popup.
// - Popups respect "Do not disturb" (only critical ones get through) and disappear by themselves.
// - The volume and brightness notifications from HyDE's scripts (volumecontrol.sh and
//   brightnesscontrol.sh) are ignored when the shell's OSD is enabled: they would do the same
//   as the OSD, twice.
Singleton {
    id: root

    readonly property bool available: true
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length
    property var popups: []
    // Arrival time of each notification (the protocol doesn't provide it).
    property var times: ({})

    readonly property bool dnd: Prefs.dnd

    function toggleDnd() {
        Prefs.dnd = !Prefs.dnd;
        Prefs.save();
    }

    // Compatibility with the bar widget: opens the history in the control center.
    function togglePanel() {
        ShellState.toggleControlCenter("notifications");
    }

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function dismiss(n) {
        n.dismiss();
    }

    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
        // Transient ones are not kept in the history.
        if (n.transient && n.tracked)
            n.expire();
    }

    function timeOf(n) {
        return times[n.id] ?? new Date();
    }

    function isHydeOsd(n) {
        // The path passed with `notify-send -i` may arrive in appIcon or in image.
        return Config.widgets.osd.enabled && n.appName === "HyDE Notify" && `${n.appIcon} ${n.image}`.includes("/Wallbash-Icon/media/");
    }

    // Icon/image to show: the notification's image, or the app icon (path or theme name).
    function imageOf(n) {
        if (n.image)
            return n.image;
        const icon = n.appIcon || n.desktopEntry || "";
        if (icon.startsWith("/"))
            return `file://${icon}`;
        if (icon.startsWith("file://") || icon.startsWith("image://"))
            return icon;
        return icon ? Quickshell.iconPath(icon, true) : "";
    }

    function onArrived(n) {
        if (isHydeOsd(n))
            return;
        n.tracked = true;

        // Same app and same title as a popup still on screen (e.g. switching layouts several times
        // in a row): the new one replaces the old one instead of stacking up. notify-send's `-r` would only
        // do that if the app knew the id the server gave it.
        for (const old of popups.filter(p => p !== n && p.appName === n.appName && p.summary === n.summary)) {
            popups = popups.filter(p => p !== old);
            old.expire();
        }

        const t = Object.assign({}, times);
        t[n.id] = new Date();
        times = t;

        // Bounded history: the oldest ones are dropped.
        const tracked = server.trackedNotifications.values;
        for (let i = 0; i < tracked.length - Config.widgets.notifications.historySize; i++)
            tracked[i].expire();

        if (!dnd || n.urgency === NotificationUrgency.Critical)
            popups = [n].concat(popups.filter(p => p !== n)).slice(0, Config.widgets.notifications.maxPopups);
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

    // With the control center open the popups go away: the notifications are already there, in the history.
    Connections {
        target: ShellState
        function onControlCenterOpenChanged() {
            if (ShellState.controlCenterOpen)
                for (const n of root.popups.slice())
                    root.hidePopup(n);
        }
    }

    // A closed notification (by the app or by us) leaves the popups.
    Instantiator {
        model: root.popups
        delegate: Connections {
            required property var modelData
            target: modelData
            function onClosed() {
                root.popups = root.popups.filter(p => p !== modelData);
            }
        }
    }
}
