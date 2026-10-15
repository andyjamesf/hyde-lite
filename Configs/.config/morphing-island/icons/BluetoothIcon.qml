import QtQuick
import QtQuick.Shapes
import qs.theme

// Bluetooth icon: the classic rune drawn with strokes.
// Connected to a device: two small dots on each side. Off: 35% opacity and a diagonal slash.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    override property bool enabled: true
    property bool connected: false

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
        opacity: root.enabled ? 1 : 0.35

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M 7.5 7.75 L 16.5 16.25 L 12 20.5 V 3.5 L 16.5 7.75 L 7.5 16.25"
            }
        }
    }

    // "Connected" dots
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.enabled && root.connected ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathAngleArc {
                centerX: 4
                centerY: 12
                radiusX: 1.4
                radiusY: 1.4
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.color

            PathAngleArc {
                centerX: 20
                centerY: 12
                radiusX: 1.4
                radiusY: 1.4
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // "Off" slash
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.enabled ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathSvg {
                path: "M 4 4 L 20 20"
            }
        }
    }
}
