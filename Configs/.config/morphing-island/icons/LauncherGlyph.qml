import QtQuick
import QtQuick.Shapes
import qs.config as Config
import qs.theme

// Small vector glyphs for the launcher (same 24×24 grid as the other icons in icons/):
// "star" (favourite, filled), "starOutline", "image", "clipboard", "calc", "keys" (keyboard) and, for
// pickers, "windows", "folder", "globe" and "picker" (generic: a list). An unknown kind draws
// nothing (empty strokePath); `kinds` lists the known ones, which the launcher uses to tell a
// picker's glyph kind from a Nerd Font character.
Item {
    id: root

    // Every kind this component draws.
    readonly property var kinds: ["windows", "folder", "globe", "picker", "star", "starOutline", "image", "clipboard", "calc", "keys"]

    property string kind: "star"
    property color color: Theme.icon
    property real size: 18

    // Outline and fill of each glyph (SVG paths on the 24×24 grid).
    readonly property string strokePath: {
        switch (kind) {
        case "starOutline":
            return "M 12 3 L 14.7 8.6 L 20.8 9.4 L 16.3 13.6 L 17.5 19.7 L 12 16.7 L 6.5 19.7 L 7.7 13.6 L 3.2 9.4 L 9.3 8.6 Z";
        case "star":
            return "M 12 3 L 14.7 8.6 L 20.8 9.4 L 16.3 13.6 L 17.5 19.7 L 12 16.7 L 6.5 19.7 L 7.7 13.6 L 3.2 9.4 L 9.3 8.6 Z";
        case "image":
            return "M 6 4.5 H 18 A 2.5 2.5 0 0 1 20.5 7 V 17 A 2.5 2.5 0 0 1 18 19.5 H 6 A 2.5 2.5 0 0 1 3.5 17 V 7 A 2.5 2.5 0 0 1 6 4.5 Z M 4 17 L 9 12 L 13 16 L 15.5 13.5 L 20 18";
        case "clipboard":
            return "M 8.5 5 H 7 A 2 2 0 0 0 5 7 V 19 A 2 2 0 0 0 7 21 H 17 A 2 2 0 0 0 19 19 V 7 A 2 2 0 0 0 17 5 H 15.5 M 9.5 3 H 14.5 A 1 1 0 0 1 15.5 4 V 6 A 1 1 0 0 1 14.5 7 H 9.5 A 1 1 0 0 1 8.5 6 V 4 A 1 1 0 0 1 9.5 3 Z M 9 12 H 15 M 9 16 H 13";
        case "calc":
            return "M 5.5 9 H 18.5 M 5.5 15 H 18.5";
        case "windows":
            return "M 6 4.5 H 15 A 2 2 0 0 1 17 6.5 V 13 A 2 2 0 0 1 15 15 H 6 A 2 2 0 0 1 4 13 V 6.5 A 2 2 0 0 1 6 4.5 Z M 4 8 H 17 M 8.5 19.5 H 18 A 2 2 0 0 0 20 17.5 V 10";
        case "folder":
            return "M 3.5 7 A 2 2 0 0 1 5.5 5 H 9.5 L 11.5 7.5 H 18.5 A 2 2 0 0 1 20.5 9.5 V 17 A 2 2 0 0 1 18.5 19 H 5.5 A 2 2 0 0 1 3.5 17 Z M 3.5 10.5 H 20.5";
        case "globe":
            return "M 12 3.5 A 8.5 8.5 0 1 1 11.99 3.5 Z M 12 3.5 C 8.8 6 8.8 18 12 20.5 M 12 3.5 C 15.2 6 15.2 18 12 20.5 M 3.5 12 H 20.5";
        case "picker":
            return "M 9.5 7 H 19 M 9.5 12 H 19 M 9.5 17 H 19 M 5 7 H 5.01 M 5 12 H 5.01 M 5 17 H 5.01";
        case "keys":
            return "M 5 6.5 H 19 A 2 2 0 0 1 21 8.5 V 15.5 A 2 2 0 0 1 19 17.5 H 5 A 2 2 0 0 1 3 15.5 V 8.5 A 2 2 0 0 1 5 6.5 Z M 7 10 H 7.01 M 10.5 10 H 10.51 M 14 10 H 14.01 M 17.5 10 H 17.51 M 8.5 14 H 15.5";
        }
        return "";
    }
    readonly property string fillPath: {
        switch (kind) {
        case "star":
            return strokePath;
        case "image":
            // The sun in the corner.
            return "M 15.5 7.3 A 1.7 1.7 0 1 1 15.49 7.3 Z";
        }
        return "";
    }

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: Config.Animations.duration(150)
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
            strokeWidth: root.kind === "calc" ? 2.6 : 1.9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: root.fillPath !== "" ? root.color : "transparent"

            PathSvg {
                path: root.fillPath
            }
        }
    }
}
