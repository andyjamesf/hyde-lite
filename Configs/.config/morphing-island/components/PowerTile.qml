import QtQuick
import qs.config
import qs.icons
import qs.theme

// A power menu tile: glyph + label below, rounded corners.
// States: hover (soft highlight), selected (accent ring, only after using the keyboard or really
// moving the mouse) and armed (danger background, "Confirm?" label).
// The MouseArea always accepts the click, so it does not reach the island's "empty space" one.
Item {
    id: root

    property string glyph: "power"
    property string label: ""
    property bool selected: false
    property bool armed: false
    // Destructive actions: the glyph uses the danger colour while not armed.
    property bool destructive: false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property color contentColor: armed ? Theme.onColor(Theme.danger) : Theme.foreground

    signal clicked
    // Global cursor position on every move (the view decides whether it was a real movement).
    signal moved(point globalPos)

    implicitWidth: Power.tileSize
    implicitHeight: Power.tileSize

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 20
        scale: root.pressed ? 0.95 : 1
        color: root.armed ? Theme.danger : Theme.surface
        border.width: root.selected ? 2 : 1
        border.color: root.selected ? (root.armed ? Theme.foreground : Theme.accent) : Theme.border

        Behavior on color {
            ColorAnimation {
                duration: Animations.duration(140)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(140)
                easing.type: Easing.OutCubic
            }
        }

        // Hover/press layer over the background (works the same on the normal and the armed background).
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.pressed ? Theme.pressed : root.hovered ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(120)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8

            PowerGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                kind: root.glyph
                size: Math.round(Power.tileSize * 0.34)
                color: root.armed ? root.contentColor : root.destructive ? Theme.danger : Theme.foreground
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.width - 12)
                horizontalAlignment: Text.AlignHCenter
                text: root.armed ? "Confirm?" : root.label
                color: root.armed || root.selected || root.hovered ? root.contentColor : Theme.dim
                font.weight: root.armed ? Font.DemiBold : Font.Normal
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: mouseEvent => root.moved(mapToGlobal(mouseEvent.x, mouseEvent.y))
        onClicked: mouseEvent => {
            mouseEvent.accepted = true;
            root.clicked();
        }
    }
}
