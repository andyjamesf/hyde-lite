import QtQuick
import QtQuick.Shapes
import qs.island.theme

// Shuffle icon: two crossing arrows (pick a random wallpaper).
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

        // Diagonal rising to the right, with its arrowhead.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 4
            startY: 17

            PathLine {
                x: 20
                y: 7
            }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 16
            startY: 8

            PathLine {
                x: 20
                y: 7
            }
            PathLine {
                x: 19
                y: 11
            }
        }

        // Diagonal falling to the right, with its arrowhead.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 4
            startY: 7

            PathLine {
                x: 20
                y: 17
            }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 16
            startY: 16

            PathLine {
                x: 20
                y: 17
            }
            PathLine {
                x: 19
                y: 13
            }
        }
    }
}
