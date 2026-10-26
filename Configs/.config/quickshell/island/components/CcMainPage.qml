import QtQuick
import Quickshell
import qs.island.config
import qs.island.core
import qs.island.services
import qs.shared.services
import qs.shared.controlcenter

// Main page of the control center. What it draws is shared with the bar (shared/controlcenter/
// CcMainView.qml): header, tiles (ControlCenter.tiles), sliders, media row, shortcuts
// (ControlCenter.shortcuts) and the notification history. What is the island's own is here: the hints
// under a hovered button, the right-click menus, the pages a click leads to, and the height, which
// grows with the history (up to maxRows rows, and never past the bottom of the island's window: the
// rows that don't fit scroll).
Item {
    id: root

    // True while this is the page on screen with the control center open.
    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int gap: ControlCenter.spacing
    readonly property int notifRowHeight: ControlCenter.notificationRowHeight
    readonly property int maxRows: ControlCenter.maxNotificationRows
    readonly property int notifCount: Notifications.count
    // Rows that fit under everything above the list inside the island's window (its height is
    // capped by the screen): the list scrolls past them.
    readonly property int windowHeight: QsWindow.window?.height ?? 760
    readonly property int fitRows: Math.max(1, Math.floor((windowHeight - Pill.topMargin - 12 - 2 * pad - view.notificationsY) / notifRowHeight))
    readonly property int visibleRows: Math.min(notifCount, maxRows, fitRows)

    implicitWidth: ControlCenter.width
    implicitHeight: view.implicitHeight + 2 * pad

    // Hint under a hovered header or shortcut button (text: Shortcuts.hint).
    function hint(on, id, item) {
        if (on) {
            IslandController.hintScreen = QsWindow.window?.screen?.name ?? "";
            IslandController.hintAt = item.mapToItem(null, item.width / 2, item.height);
            IslandController.hint = id;
        } else if (IslandController.hint === id) {
            IslandController.hint = "";
        }
    }

    // Right-click menu of a tile or button, under it.
    function menu(id, item) {
        if (Menus.has(id))
            IslandController.openMenu(id, item, QsWindow.window?.screen?.name ?? "");
    }

    // Switches pages inside the control center, on the same screen.
    function go(p) {
        IslandController.mode = p;
    }

    CcMainView {
        id: view
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.gap
        tiles: ControlCenter.tiles
        shortcuts: ControlCenter.shortcuts
        notificationRowHeight: root.notifRowHeight
        visibleRows: root.visibleRows

        onPageRequested: page => root.go(({
                    "wifi": IslandState.wifi,
                    "bluetooth": IslandState.bluetooth,
                    "audio": IslandState.audio,
                    "battery": IslandState.battery,
                    "media": IslandState.media
                })[page])
        onHeaderAction: id => id === "avatar" ? SysInfo.chooseAvatar() : Shortcuts.run(id)
        onMenuRequested: (id, item) => root.menu(id, item)
        onHintRequested: (on, id, item) => root.hint(on, id, item)
    }
}
