import QtQuick
import QtQuick.Shapes
import qs.theme

// Media control icon: "play" (rounded triangle), "pause" (two rounded bars), "next" and "prev"
// (triangle + bar). Switching between "play" and "pause" cross-fades.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    // "play", "pause", "next" or "prev"
    property string kind: "play"

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    // Everything is drawn on a 24×24 grid and scaled to the requested size.
    // Filled shapes with an outline of the same colour and round joins: that is what rounds the corners.
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.kind === "pause" ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: root.color
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.kind === "next" ? "M 5.9 6.5 L 13.9 12 L 5.9 17.5 Z M 18.15 6.5 V 17.5" : root.kind === "prev" ? "M 18.1 6.5 L 10.1 12 L 18.1 17.5 Z M 5.85 6.5 V 17.5" : "M 7.5 6 L 17 12 L 7.5 18 Z"
            }
        }
    }

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.kind === "pause" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: root.color
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M 7.25 6 H 9.25 V 18 H 7.25 Z M 14.75 6 H 16.75 V 18 H 14.75 Z"
            }
        }
    }
}
