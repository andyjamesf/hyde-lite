import QtQuick
import qs.services

// Round icon-only button. `checked` fills it with the primary color (for toggles); `tonal`
// gives it a subtle background, for buttons that sit on their own in a panel. `tooltip` shows up after
// half a second of hovering.
Item {
    id: root

    property string icon
    property bool checked: false
    property bool tonal: false
    property int size: 34
    property int iconSize: Math.round(size * 0.55)
    property color color: checked ? Theme.onPrimary : Theme.text
    property color background: checked ? Theme.primary : tonal ? Theme.surfaceContainerHighest : "transparent"
    property string tooltip
    property bool tooltipBelow: true
    property bool enabled: true

    signal clicked

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.background
        scale: area.pressed ? 0.92 : 1

        Behavior on color {
            ColorAnim {}
        }
        Behavior on scale {
            NumberAnim {
                duration: Anim.fast
            }
        }
    }

    StateLayer {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }

    MaterialIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        fill: root.checked ? 1 : 0
        color: root.color
    }

    Timer {
        id: tipDelay
        interval: 500
        running: area.containsMouse && root.tooltip !== ""
    }

    Loader {
        active: area.containsMouse && !tipDelay.running && root.tooltip !== ""
        sourceComponent: Tooltip {
            target: root
            text: root.tooltip
            below: root.tooltipBelow
        }
    }
}
