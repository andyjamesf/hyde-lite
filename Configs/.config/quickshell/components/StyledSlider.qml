import QtQuick
import qs.services

// Bar slider: a rounded track that fills and empties, with the icon inside and the value on the right,
// outside the track.
// `value` comes from outside (0..1); while dragging it emits moved() and shows the local value so it doesn't jump.
Item {
    id: root

    property real value: 0
    property string icon
    property bool enabled: true
    property bool showValue: true
    property real step: 0.05
    property color accent: Theme.primary

    signal moved(real value)
    signal iconClicked

    readonly property bool dragging: area.pressed
    property real dragValue: 0
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))

    property int trackHeight: 32

    implicitWidth: 240
    implicitHeight: trackHeight
    opacity: enabled ? 1 : 0.45

    function setFromX(x) {
        dragValue = Math.max(0, Math.min(1, x / track.width));
        moved(dragValue);
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: valueText.visible ? valueText.left : parent.right
        anchors.rightMargin: valueText.visible ? Theme.space3 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: root.trackHeight

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.surfaceContainerHighest
        }

        // Filled part: grows and shrinks with the value (never smaller than a circle, to fit the icon).
        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, root.shown * parent.width)
            radius: height / 2
            color: root.accent

            Behavior on width {
                enabled: !root.dragging
                NumberAnim {
                    duration: Anim.fast
                }
            }
        }

        MaterialIcon {
            visible: root.icon !== ""
            x: Math.round((root.trackHeight - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: Math.min(20, Math.round(root.trackHeight * 0.55))
            fill: 1
            color: Theme.onPrimary
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -4
            anchors.bottomMargin: -4
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: mouse => {
                // Click on the icon: its own action (usually mute), without touching the value.
                if (root.icon !== "" && mouse.x < root.trackHeight) {
                    mouse.accepted = false;
                    root.iconClicked();
                    return;
                }
                root.setFromX(mouse.x);
            }
            onPositionChanged: mouse => {
                if (pressed)
                    root.setFromX(mouse.x);
            }
            onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))))
        }
    }

    StyledText {
        id: valueText
        visible: root.showValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideNone
        text: `${Math.round(root.shown * 100)}%`
        font.pixelSize: Theme.labelLarge
        font.weight: Font.Medium
        color: Theme.textDim
    }
}
