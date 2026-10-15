import QtQuick
import QtQuick.Shapes
import qs.theme

// Ethernet icon: three linked boxes (a small wired network), drawn with strokes like the other
// status icons. Not connected: 35% opacity.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    property bool connected: true

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
        opacity: root.connected ? 1 : 0.35

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

            // Top box, the link down, the bar across and the two links to the bottom boxes.
            PathSvg {
                path: "M 10 2.5 H 14 Q 15 2.5 15 3.5 V 7.5 Q 15 8.5 14 8.5 H 10 Q 9 8.5 9 7.5 V 3.5 Q 9 2.5 10 2.5 Z"
                    + " M 12 8.5 V 12 M 5.5 15.5 V 13 Q 5.5 12 6.5 12 H 17.5 Q 18.5 12 18.5 13 V 15.5"
                    + " M 3.5 15.5 H 7.5 Q 8.5 15.5 8.5 16.5 V 20.5 Q 8.5 21.5 7.5 21.5 H 3.5 Q 2.5 21.5 2.5 20.5 V 16.5 Q 2.5 15.5 3.5 15.5 Z"
                    + " M 16.5 15.5 H 20.5 Q 21.5 15.5 21.5 16.5 V 20.5 Q 21.5 21.5 20.5 21.5 H 16.5 Q 15.5 21.5 15.5 20.5 V 16.5 Q 15.5 15.5 16.5 15.5 Z"
            }
        }
    }
}
