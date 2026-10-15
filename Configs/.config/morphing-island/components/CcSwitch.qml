import QtQuick
import qs.config
import qs.theme

// Small on/off switch: rounded track and a sliding knob. It does not change state by itself: it
// emits toggled() and the user decides (`checked` always comes from the service).
Item {
    id: root

    property bool checked: false
    override property bool enabled: true
    readonly property bool hovered: mouse.containsMouse

    signal toggled

    implicitWidth: 42
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : root.hovered && root.enabled ? Theme.pressed : Theme.hover
        border.width: root.checked ? 0 : 1
        border.color: Theme.border

        Behavior on color {
            ColorAnimation {
                duration: Animations.duration(150)
            }
        }

        Rectangle {
            id: knob
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.accentContent : Theme.dim
            scale: mouse.pressed ? 0.88 : 1

            Behavior on x {
                NumberAnimation {
                    duration: Animations.duration(180)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(150)
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Animations.duration(120)
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled)
                root.toggled();
        }
    }
}
