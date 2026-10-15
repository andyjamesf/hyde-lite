import QtQuick
import QtQuick.Shapes
import qs.theme

// Power icon: the classic symbol (a ring open at the top with a vertical stem).
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

            PathSvg {
                path: "M 16.82 7.255 A 7.5 7.5 0 1 1 7.18 7.255 M 12 3.5 V 11"
            }
        }
    }
}
