pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

// Brightness icon: a sun with a central disc and 8 rays.
// The rays light up clockwise from the top (at least one lit); the disc grows slightly with the
// level.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    property real level: 1

    readonly property real clamped: Math.max(0, Math.min(1, level))
    readonly property int activeRays: Math.max(1, Math.ceil(clamped * 8))
    property real discRadius: 3.25 + clamped

    function tint(k) {
        return Qt.rgba(color.r, color.g, color.b, color.a * k);
    }

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Behavior on discRadius {
        NumberAnimation {
            duration: 150
        }
    }

    // Sun ray, from the centre outwards, at an angle of index × 45°.
    component Ray: ShapePath {
        id: ray

        required property int index
        readonly property real angle: index * Math.PI / 4
        readonly property real dx: Math.sin(angle)
        readonly property real dy: -Math.cos(angle)
        property real k: index < root.activeRays ? 1 : 0.25

        strokeColor: root.tint(k)
        strokeWidth: 2.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: 12 + 6.75 * dx
        startY: 12 + 6.75 * dy

        Behavior on k {
            NumberAnimation {
                duration: 150
            }
        }

        PathLine {
            x: 12 + 9 * ray.dx
            y: 12 + 9 * ray.dy
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
            strokeColor: "transparent"
            fillColor: root.color

            PathAngleArc {
                centerX: 12
                centerY: 12
                radiusX: root.discRadius
                radiusY: root.discRadius
                startAngle: 0
                sweepAngle: 360
            }
        }

        Ray {
            index: 0
        }
        Ray {
            index: 1
        }
        Ray {
            index: 2
        }
        Ray {
            index: 3
        }
        Ray {
            index: 4
        }
        Ray {
            index: 5
        }
        Ray {
            index: 6
        }
        Ray {
            index: 7
        }
    }
}
