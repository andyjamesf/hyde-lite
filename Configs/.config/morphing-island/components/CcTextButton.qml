import QtQuick
import qs.config
import qs.theme

// Pill-shaped text button ("Disconnect", "Pair", "Forget", "Connect"…). `primary` uses the accent
// colour; the others stay subtle until hovered.
Rectangle {
    id: root

    property string text: ""
    property bool primary: false
    override property bool enabled: true
    readonly property bool hovered: mouse.containsMouse

    signal clicked

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 26
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: primary ? (mouse.pressed ? Qt.darker(Theme.accent, 1.15) : mouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent) : mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: primary ? 0 : 1
    border.color: Theme.border
    scale: mouse.pressed && enabled ? 0.95 : 1

    Behavior on color {
        ColorAnimation {
            duration: Animations.duration(120)
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Animations.duration(120)
        }
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.primary ? Theme.accentContent : root.hovered ? Theme.foreground : Theme.dim
        font.pixelSize: Appearance.fontSize - 1
        font.weight: Font.Medium
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.enabled)
                root.clicked();
        }
    }
}
