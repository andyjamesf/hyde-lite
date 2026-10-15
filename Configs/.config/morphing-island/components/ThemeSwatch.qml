import QtQuick
import qs.config
import qs.theme

// A scheme's swatch in the theme picker: a card with the scheme's own colours (background, surface
// pill, accent dot and stroke, "Aa" in the text colour) and the name below.
// The accent ring marks the active theme; the thin ring marks the keyboard position.
Item {
    id: root

    property string name: ""
    property bool active: false
    property bool focused: false
    // The scheme's base colours (without applying it).
    readonly property var p: Theme.preview(name)
    readonly property bool available: p.available
    readonly property bool einkCard: p.kind === "eink"
    readonly property alias hovered: mouse.containsMouse

    signal clicked
    signal entered

    implicitWidth: 94
    implicitHeight: card.height + 5 + label.implicitHeight
    opacity: available ? 1 : 0.45

    // Keyboard ring (outside the active theme's ring, if both coincide).
    Rectangle {
        anchors.fill: card
        anchors.margins: root.active ? -6 : -3
        radius: card.radius - anchors.margins
        visible: root.focused
        color: "transparent"
        border.width: 1.5
        border.color: root.active ? Theme.dim : Theme.foreground
        scale: card.scale
    }

    // Active theme ring.
    Rectangle {
        anchors.fill: card
        anchors.margins: -3
        radius: card.radius + 3
        visible: root.active
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        scale: card.scale
    }

    Rectangle {
        id: card
        width: root.width
        height: 50
        radius: 14
        color: root.p.background
        border.width: 1
        border.color: root.einkCard ? root.p.foreground : Qt.alpha(root.p.foreground, 0.16)
        scale: mouse.pressed ? 0.96 : mouse.containsMouse && root.available ? 1.04 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(140)
                easing.type: Easing.OutCubic
            }
        }

        // Surface pill.
        Rectangle {
            x: 9
            y: 9
            width: parent.width * 0.5
            height: 10
            radius: 5
            color: root.p.surface
            border.width: root.einkCard ? 1 : 0
            border.color: root.p.foreground
        }

        // Accent dot.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 9
            y: 8
            width: 12
            height: 12
            radius: 6
            color: root.p.accent
        }

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            text: "Aa"
            color: root.p.foreground
            font.pixelSize: Appearance.fontSize + 2
            font.weight: Font.DemiBold
        }

        // Accent stroke.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: 24
            height: 4
            radius: 2
            color: root.p.accent
        }
    }

    Label {
        id: label
        anchors.top: card.bottom
        anchors.topMargin: 5
        anchors.left: parent.left
        anchors.right: parent.right
        horizontalAlignment: Text.AlignHCenter
        text: root.name
        color: root.active ? Theme.foreground : Theme.dim
        font.pixelSize: Appearance.fontSize - 1
        font.weight: root.active ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: if (containsMouse)
            root.entered()
        onClicked: if (root.available)
            root.clicked()
    }
}
