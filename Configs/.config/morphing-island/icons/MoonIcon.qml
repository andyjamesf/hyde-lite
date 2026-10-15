import QtQuick
import QtQuick.Shapes
import qs.theme

// Moon icon: a filled crescent (night light / "do not disturb").
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
    // A thin outline of the same colour, with round joins, softens the tips of the crescent.
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.6
            fillColor: root.color
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M 20.1 12.71 A 8.1 8.1 0 1 1 11.29 3.9 A 6.3 6.3 0 0 0 20.1 12.71 Z"
            }
        }
    }
}
