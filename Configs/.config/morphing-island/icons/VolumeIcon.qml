pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.theme

// Volume icon: a speaker (box + cone) with sound waves.
// Level 0 → no waves lit, up to 50% → one wave, above → two. Muted: an "X" instead of the waves.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    property real level: 1
    property bool muted: false

    readonly property int waves: muted || level <= 0 ? 0 : level <= 0.5 ? 1 : 2

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

    // Sound wave; faded when the level does not reach it.
    component Wave: ShapePath {
        required property int index
        property real k: index < root.waves ? 1 : 0.25

        strokeColor: root.tint(k)
        strokeWidth: 2.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

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

        // Speaker: filled, with round joins to soften the corners.
        ShapePath {
            strokeColor: root.color
            strokeWidth: 2.2
            fillColor: root.color
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M 4.25 9.25 H 7.5 L 11.75 5.5 V 18.5 L 7.5 14.75 H 4.25 Z"
            }
        }
    }

    // Waves (disappear when muted)
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.muted ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        Wave {
            index: 0

            PathSvg {
                path: "M 14.359 8.641 A 4.75 4.75 0 0 1 14.359 15.359"
            }
        }

        Wave {
            index: 1

            PathSvg {
                path: "M 17.187 5.813 A 8.75 8.75 0 0 1 17.187 18.187"
            }
        }
    }

    // Mute "X"
    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.size / 24
        preferredRendererType: Shape.CurveRenderer
        opacity: root.muted ? 1 : 0
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
                path: "M 15.25 9.5 L 20.25 14.5 M 20.25 9.5 L 15.25 14.5"
            }
        }
    }
}
