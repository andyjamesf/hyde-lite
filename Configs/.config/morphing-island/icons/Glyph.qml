import QtQuick
import QtQuick.Shapes
import qs.theme

// Small vector glyphs used across the UI (same 24×24 grid as the other icons, outline only):
// "back" (‹), "chevron" (›), "lock", "check", "bell", "bellOff", "refresh", "mic", "micOff",
// "close", "speaker", "coffee" (caffeine tile), "menu" (☰) and "plus".
Item {
    id: root

    property string kind: "chevron"
    property color color: Theme.icon
    property real size: 18

    // Outline of each glyph (SVG paths on the 24×24 grid).
    readonly property string strokePath: {
        switch (kind) {
        case "back":
            return "M 15 5 L 8 12 L 15 19";
        case "chevron":
            return "M 9 5 L 16 12 L 9 19";
        case "lock":
            return "M 7 11 H 17 A 1.8 1.8 0 0 1 18.8 12.8 V 19.2 A 1.8 1.8 0 0 1 17 21 H 7 A 1.8 1.8 0 0 1 5.2 19.2 V 12.8 A 1.8 1.8 0 0 1 7 11 Z M 8.5 11 V 7.5 A 3.5 3.5 0 0 1 15.5 7.5 V 11";
        case "check":
            return "M 5 12.5 L 10 17.5 L 19 7";
        case "bell":
            return "M 18 16.5 V 11 A 6 6 0 0 0 6 11 V 16.5 L 4.5 18.5 H 19.5 Z M 10 21 Q 12 22.6 14 21";
        case "bellOff":
            return "M 18 16.5 V 11 A 6 6 0 0 0 6 11 V 16.5 L 4.5 18.5 H 19.5 Z M 10 21 Q 12 22.6 14 21 M 3.5 3.5 L 20.5 20.5";
        case "refresh":
            return "M 19 12 A 7 7 0 1 1 16.95 7.05 M 17.5 3.5 V 7.5 H 13.5";
        case "mic":
            return "M 12 3.5 A 3 3 0 0 1 15 6.5 V 11.5 A 3 3 0 0 1 9 11.5 V 6.5 A 3 3 0 0 1 12 3.5 Z M 5.5 11 A 6.5 6.5 0 0 0 18.5 11 M 12 17.5 V 21";
        case "micOff":
            return "M 12 3.5 A 3 3 0 0 1 15 6.5 V 11.5 A 3 3 0 0 1 9 11.5 V 6.5 A 3 3 0 0 1 12 3.5 Z M 5.5 11 A 6.5 6.5 0 0 0 18.5 11 M 12 17.5 V 21 M 4 4 L 20 20";
        case "close":
            return "M 6.5 6.5 L 17.5 17.5 M 17.5 6.5 L 6.5 17.5";
        case "speaker":
            return "M 7 3.5 H 17 A 1.5 1.5 0 0 1 18.5 5 V 19 A 1.5 1.5 0 0 1 17 20.5 H 7 A 1.5 1.5 0 0 1 5.5 19 V 5 A 1.5 1.5 0 0 1 7 3.5 Z M 12 10.5 A 3.5 3.5 0 1 1 11.99 10.5 Z";
        case "plus":
            return "M 12 5 V 19 M 5 12 H 19";
        case "menu":
            return "M 4.5 7 H 19.5 M 4.5 12 H 19.5 M 4.5 17 H 19.5";
        case "coffee":
            return "M 5 9 H 16 V 14.5 A 4.5 4.5 0 0 1 11.5 19 H 9.5 A 4.5 4.5 0 0 1 5 14.5 Z M 16 10.5 H 17.5 A 2.25 2.25 0 0 1 17.5 15 H 16 M 8.5 3.5 V 6 M 12 3.5 V 6";
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
            strokeWidth: root.kind === "back" || root.kind === "chevron" || root.kind === "check" ? 2.4 : 1.9
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: root.strokePath
            }
        }
    }
}
