import QtQuick
import QtQuick.Shapes
import qs.theme

// Power menu glyphs (same 24×24 grid as the other icons, outline only):
// "lock" (padlock), "suspend" (moon), "logout" (door with arrow), "restart" (circular arrow) and
// "power" (power symbol).
Item {
    id: root

    property string kind: "power"
    property color color: Theme.icon
    property real size: 30

    // Outline of each glyph (SVG paths on the 24×24 grid).
    readonly property string strokePath: {
        switch (kind) {
        case "lock":
            return "M 7 11 H 17 A 1.8 1.8 0 0 1 18.8 12.8 V 19.2 A 1.8 1.8 0 0 1 17 21 H 7 A 1.8 1.8 0 0 1 5.2 19.2 V 12.8 A 1.8 1.8 0 0 1 7 11 Z M 8.5 11 V 7.5 A 3.5 3.5 0 0 1 15.5 7.5 V 11";
        case "suspend":
            return "M 20.1 12.71 A 8.1 8.1 0 1 1 11.29 3.9 A 6.3 6.3 0 0 0 20.1 12.71 Z";
        case "logout":
            return "M 10 4 H 6.5 A 1.5 1.5 0 0 0 5 5.5 V 18.5 A 1.5 1.5 0 0 0 6.5 20 H 10 M 15 7.5 L 19.5 12 L 15 16.5 M 19.5 12 H 9.5";
        case "restart":
            return "M 19 12 A 7 7 0 1 1 16.95 7.05 M 17.5 3.5 V 7.5 H 13.5";
        case "power":
            return "M 16.82 7.255 A 7.5 7.5 0 1 1 7.18 7.255 M 12 3.5 V 11";
        }
        return "";
    }

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

        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }
    }
}
