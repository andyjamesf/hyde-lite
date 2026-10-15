import QtQuick
import QtQuick.Shapes
import qs.theme

// Shield with a keyhole for the authentication request (24×24 grid, like the glyphs in icons/).
Item {
    id: root

    property color color: Theme.accent
    property real size: 30

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer

        // Shield (outline with a veil of the same colour inside).
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.6
            fillColor: Qt.alpha(root.color, 0.14)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M 12 2.8 L 19.5 5.6 V 11.2 C 19.5 15.9 16.3 19.6 12 21.2 C 7.7 19.6 4.5 15.9 4.5 11.2 V 5.6 Z"
            }
        }

        // Keyhole.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.6
            fillColor: root.color
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M 12 8.6 A 1.7 1.7 0 1 1 11.99 8.6 Z M 12 12 V 14.6"
            }
        }
    }
}
