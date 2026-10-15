import QtQuick
import qs.components
import qs.services

// A group of widgets. In the "islands" style it has its own rounded background; in "continuous" it is just
// a container over the bar background. It hides when none of its widgets has anything to show.
Item {
    id: root

    required property var widgets
    required property var bar
    readonly property bool islands: BarLayout.islands

    // Visible if any widget wants to appear (see WidgetLoader.wanted).
    visible: {
        for (let i = 0; i < repeater.count; i++)
            if (repeater.itemAt(i)?.wanted)
                return true;
        return false;
    }
    implicitWidth: row.implicitWidth + (islands ? Math.round(BarLayout.height * 0.25) : 0)
    implicitHeight: BarLayout.height
    // Only clips the content while the width animates (otherwise letters and symbols at the edge got cut off).
    clip: widthAnim.running

    Behavior on implicitWidth {
        NumberAnim {
            id: widthAnim
            duration: Anim.normal
            easing.bezierCurve: Anim.emphasized
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.islands
        radius: BarLayout.radius
        color: BarLayout.pillColor
        border.width: 1
        border.color: BarLayout.pillBorder

        Behavior on color {
            ColorAnim {}
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: parent.height

        Repeater {
            id: repeater
            model: root.widgets

            WidgetLoader {
                required property string modelData
                name: modelData
                bar: root.bar
                height: row.height
            }
        }
    }
}
