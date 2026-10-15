import QtQuick
import qs.config
import qs.icons
import qs.theme

// Control center tile with two click zones:
//  - the round badge on the left toggles directly (toggled);
//  - the rest (name + status) opens the subview (opened), if any; otherwise it also toggles.
// Active: badge in Theme.accent with the icon in Theme.accentContent; inactive: Theme.surface.
Item {
    id: root

    property string title: ""
    property string status: ""
    property bool active: false
    // Has a subview (shows "›" and clicking the body opens it).
    property bool expandable: false
    override property bool enabled: true

    // Icon inside the badge (default child); the colour to use is in iconColor.
    default property alias icon: iconHolder.data
    readonly property color iconColor: active ? Theme.accentContent : Theme.icon

    signal toggled
    signal opened
    // Right click (the tile's menu, services/Menus.qml).
    signal menuRequested

    implicitWidth: 200
    implicitHeight: ControlCenter.tileHeight
    opacity: enabled ? 1 : 0.45

    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(150)
        }
    }

    // Tile background (reacts to the body; the badge has its own state).
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 18
        color: root.active ? Qt.alpha(Theme.accent, 0.12) : Theme.hover
        border.width: 1
        border.color: root.active ? Qt.alpha(Theme.accent, 0.35) : Theme.border
        scale: body.pressed && root.enabled ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: Animations.duration(160)
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Animations.duration(160)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(140)
                easing.type: Easing.OutCubic
            }
        }

        // Hover/press highlight over the base colour.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: !root.enabled ? "transparent" : body.pressed ? Theme.pressed : body.containsMouse ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(120)
                }
            }
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.RightButton) {
                root.menuRequested();
                return;
            }
            if (!root.enabled)
                return;
            if (root.expandable)
                root.opened();
            else
                root.toggled();
        }
    }

    // Badge (on/off button).
    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        width: root.height - 18
        height: width
        radius: width / 2
        color: root.active ? Theme.accent : Theme.surface
        border.width: root.active ? 0 : 1
        border.color: Theme.border
        scale: badgeMouse.pressed && root.enabled ? 0.9 : 1

        Behavior on color {
            ColorAnimation {
                duration: Animations.duration(160)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(140)
                easing.type: Easing.OutCubic
            }
        }

        // Badge hover: a veil in the icon colour (visible on both the active and the inactive badge).
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: !root.enabled ? "transparent" : badgeMouse.pressed ? Qt.alpha(root.iconColor, 0.2) : badgeMouse.containsMouse ? Qt.alpha(root.iconColor, 0.12) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(120)
                }
            }
        }

        Item {
            id: iconHolder
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }

        MouseArea {
            id: badgeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton) {
                    root.menuRequested();
                    return;
                }
                if (root.enabled)
                    root.toggled();
            }
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: 10
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Label {
            width: parent.width
            text: root.title
            font.weight: Font.DemiBold
        }

        Label {
            width: parent.width
            text: root.status
            textFormat: Text.PlainText
            color: root.active ? Theme.foreground : Theme.dim
            font.pixelSize: Appearance.fontSize - 2
            opacity: 0.85
        }
    }

    Glyph {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: root.expandable ? 10 : 0
        anchors.verticalCenter: parent.verticalCenter
        kind: "chevron"
        size: root.expandable ? 14 : 0
        visible: root.expandable
        color: body.containsMouse ? Theme.foreground : Theme.faint
    }
}
