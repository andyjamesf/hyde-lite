import QtQuick
import QtQuick.Shapes
import qs.theme

// Refresh icon: a ~300° arc with an arrow head. With `spinning`, it rotates continuously.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    property bool spinning: false

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    // Everything is drawn on a 24×24 grid and scaled to the requested size.
    Shape {
        id: glyph
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
            joinStyle: ShapePath.RoundJoin

            PathAngleArc {
                centerX: 12
                centerY: 12
                radiusX: 7.5
                radiusY: 7.5
                startAngle: -60
                sweepAngle: 300
            }
        }
        // Arrow head at the start of the arc (top right), pointing along the arc.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 15.2
            startY: 2.6

            PathLine {
                x: 15.75
                y: 5.5
            }
            PathLine {
                x: 12.8
                y: 6.4
            }
        }

        RotationAnimator on rotation {
            running: root.spinning
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            onStopped: glyph.rotation = 0
        }
    }
}
