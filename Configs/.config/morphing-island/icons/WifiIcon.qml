pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

// Wi‑Fi icon: a dot and three concentric arcs fanning upwards.
// The level (0..4) lights the parts from the bottom up; the rest stay faded.
// Off: everything at 35% opacity with a diagonal slash. Not connected: only the faded outline.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    // 0 = no signal, 1 = dot only, 2 = dot + 1 arc, 3 = + 2 arcs, 4 = all
    property int level: 4
    override property bool enabled: true
    property bool connected: true

    // How many parts are lit (off: everything is drawn, opacity does the rest).
    readonly property int lit: !enabled ? 4 : connected ? Math.max(0, Math.min(4, level)) : 0

    function tint(k) {
        return Qt.rgba(color.r, color.g, color.b, color.a * k);
    }

    implicitWidth: size
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    // Part of the fan; lights up when the level covers it.
    component Part: ShapePath {
        required property int index
        property real k: index < root.lit ? 1 : 0.25

        strokeColor: root.tint(k)
        strokeWidth: 2.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        Behavior on k {
            NumberAnimation {
                duration: 150
            }
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

        // Dot
        Part {
            index: 0
            strokeColor: "transparent"
            fillColor: root.tint(k)

            PathAngleArc {
                centerX: 12
                centerY: 18.5
                radiusX: 1.9
                radiusY: 1.9
                startAngle: 0
                sweepAngle: 360
            }
        }

        Part {
            index: 1

            PathSvg {
                path: "M 8.464 14.964 A 5 5 0 0 1 15.536 14.964"
            }
        }

        Part {
            index: 2

            PathSvg {
                path: "M 5.459 11.959 A 9.25 9.25 0 0 1 18.541 11.959"
            }
        }

        Part {
            index: 3

            PathSvg {
                path: "M 2.454 8.954 A 13.5 13.5 0 0 1 21.546 8.954"
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
