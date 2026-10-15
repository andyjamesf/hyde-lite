import QtQuick
import QtQuick.Shapes
import qs.theme

// Search icon: a magnifying glass (ring + diagonal handle).
Item {
    id: root

    property color color: Theme.icon
    property real size: 18

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    // Everything is drawn on a 24×24 grid and scaled to the requested size.
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 10.25
                centerY: 10.25
                radiusX: 6
                radiusY: 6
                startAngle: 0
                sweepAngle: 360
            }
            PathMove {
                x: 14.75
                y: 14.75
            }
            PathLine {
                x: 19.75
                y: 19.75
            }
        }
    }
}
