import QtQuick
import Quickshell.Widgets
import qs.bar.services

// Base element of the bar widgets: icon (Material or image), text, tooltip, the three mouse
// buttons, scroll, an optional menu and a popout (panel) that opens on left click.
// Extra content can be added as children.
Item {
    id: root

    property string icon
    property real iconFill: 0
    property color iconColor: Theme.text
    property string image
    property string text
    property color textColor: Theme.text
    property bool rich: false
    property string fontFamily: Config.appearance.font
    property int maxTextWidth: 10000
    property string tooltip
    property var menu: null
    property bool menuOnLeftClick: false
    property bool active: false
    property int padding: BarLayout.itemPadding

    // Widgets say whether they have anything to show through `shown` (and not `visible`,
    // which also depends on the parents). The WidgetLoader and the Island use it to hide themselves.
    property bool shown: true

    property bool menuOpen: false
    property Component popout: null
    // Name used to open this popout over IPC (`qs ipc call bar popout <name>`).
    property string popoutName
    // Name for menus/tooltips requested over IPC (`bar menu <name>`, `bar tooltip <name>`); the
    // WidgetLoader fills it with the widget id.
    property string ipcName
    // Submenus to open right away (indices) when the menu is opened over IPC.
    property var menuPath: []
    readonly property bool ipcScreenOk: !root.bar?.screen || ShellState.requestedPopoutScreen === "" || ShellState.requestedPopoutScreen === root.bar.screen.name
    readonly property bool tipForced: ipcName !== "" && ShellState.requestedTooltip === ipcName && ipcScreenOk && visible
    property var bar

    // Only one popout open at a time: opening this one closes the previous one.
    onPopoutOpenChanged: if (popoutOpen)
        ShellState.popoutOwner = root
    Connections {
        target: ShellState
        function onPopoutOwnerChanged() {
            if (ShellState.popoutOwner !== root)
                root.popoutOpen = false;
        }
    }
    property bool popoutOpen: false
    // The outside click that closes the popout may land on this same widget; without this it would reopen at once.
    property real popoutClosedAt: 0
    readonly property bool hovered: stateLayer.containsMouse
    default property alias content: row.data

    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int direction)

    visible: shown
    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: BarLayout.height

    StateLayer {
        id: stateLayer
        anchors.fill: parent
        anchors.topMargin: Math.round(BarLayout.height * 0.14)
        anchors.bottomMargin: Math.round(BarLayout.height * 0.14)
        active: root.active || root.menuOpen || root.popoutOpen

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.menu && !root.menuOnLeftClick)
                    root.menuOpen = true;
                root.rightClicked();
            } else if (mouse.button === Qt.MiddleButton) {
                root.middleClicked();
            } else {
                if (root.popout && Date.now() - root.popoutClosedAt > 300)
                    root.popoutOpen = !root.popoutOpen;
                if (root.menu && root.menuOnLeftClick)
                    root.menuOpen = true;
                root.clicked();
            }
        }
        onScrolled: direction => root.scrolled(direction)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(BarLayout.height * 0.15)

        IconImage {
            visible: root.image !== ""
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: BarLayout.iconSize
            source: root.image
        }

        MaterialIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            fill: root.iconFill
            size: BarLayout.iconSize
            color: BarLayout.readable(root.iconColor, 3)
        }

        StyledText {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxTextWidth)
            text: root.rich ? Utils.pango(root.text, c => BarLayout.readable(c, 3)) : root.text
            textFormat: root.rich ? Text.StyledText : Text.PlainText
            color: BarLayout.readable(root.textColor, 4.5)
            font.family: root.fontFamily
            font.pixelSize: BarLayout.fontSize
        }
    }

    Timer {
        id: tipDelay
        interval: 500
        running: root.hovered && root.tooltip !== "" && !root.menuOpen && !root.popoutOpen
    }

    Loader {
        active: (root.hovered && !tipDelay.running || root.tipForced) && root.tooltip !== "" && !root.menuOpen && !root.popoutOpen
        sourceComponent: Tooltip {
            target: root
            text: root.tooltip
        }
    }

    Loader {
        active: root.menuOpen
        sourceComponent: MenuPopup {
            target: root
            items: root.menu
            path: root.menuPath
            onDismissed: {
                root.menuOpen = false;
                root.menuPath = [];
            }
        }
    }

    Loader {
        active: root.popoutOpen
        sourceComponent: Popout {
            target: root
            content: root.popout
            barWindow: root.bar ?? null
            onDismissed: {
                root.popoutOpen = false;
                root.popoutClosedAt = Date.now();
            }
        }
    }

    Connections {
        target: ShellState
        enabled: root.popoutName !== "" || root.ipcName !== ""
        function onRequestedMenuChanged() {
            const parts = ShellState.requestedMenu.split(":");
            if (parts[0] === root.ipcName && root.menu && root.ipcScreenOk && root.visible) {
                root.menuPath = parts.slice(1).map(n => parseInt(n));
                root.menuOpen = false;
                root.menuOpen = true;
            } else if (ShellState.requestedMenu === "") {
                root.menuOpen = false;
            }
        }
        function onRequestedPopoutChanged() {
            const screenOk = !root.bar?.screen || ShellState.requestedPopoutScreen === "" || ShellState.requestedPopoutScreen === root.bar.screen.name;
            if (ShellState.requestedPopout === root.popoutName && screenOk && root.visible)
                root.popoutOpen = true;
        }
    }
}
