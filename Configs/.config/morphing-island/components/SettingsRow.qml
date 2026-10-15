import QtQuick
import qs.config
import qs.theme

// A settings row: title (and optional subtitle) on the left and, on the right, whatever control
// the view puts there (default children). Keeps no state: the view says whether it has the
// keyboard ring (`focused`) and reacts to triggered() (click or Enter/Space) and to
// adjustRequested(±1) (left/right arrows).
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    // Keyboard ring.
    property bool focused: false
    // A click anywhere on the row emits triggered() (switches and shortcuts).
    property bool clickable: true
    // Width reserved for the title (sliders use it to align their tracks).
    property real titleWidth: -1
    readonly property bool hovered: mouse.containsMouse
    default property alias trailing: trailingRow.data

    signal triggered
    signal adjustRequested(int direction)
    signal entered

    implicitWidth: 400
    implicitHeight: Math.max(44, texts.implicitHeight + 16)

    // Hover background (clickable rows only).
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: mouse.pressed ? Theme.pressed : Theme.hover
        opacity: root.clickable && root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(120)
            }
        }
    }

    // Keyboard ring.
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1.5
        border.color: Qt.alpha(Theme.foreground, 0.75)
        opacity: root.focused ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(120)
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: if (containsMouse)
            root.entered()
        onClicked: if (root.clickable)
            root.triggered()
    }

    Column {
        id: texts
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.titleWidth >= 0 ? root.titleWidth : Math.max(0, trailingRow.x - 12 - anchors.leftMargin)
        spacing: 1

        Label {
            width: parent.width
            visible: text !== ""
            text: root.title
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 2
        }
    }

    // Controls on the right (above the row's MouseArea, so they get their own clicks).
    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
}
