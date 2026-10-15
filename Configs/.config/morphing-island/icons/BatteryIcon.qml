pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.theme

// Battery icon: a horizontal cell with a small terminal on the right and a fill proportional to the
// charge. The percentage sits inside the cell, drawn twice (once over the empty part, once over the
// full part in a contrasting colour) so it always reads well.
// Charging: fill in the accent colour and a bolt. Low charge: fill in the danger colour.
Item {
    id: root

    property color color: Theme.icon
    property real size: 18
    property real percent: 100
    property bool charging: false
    property bool present: true
    property bool showPercent: true
    property real lowLevel: 15

    readonly property real clamped: Math.max(0, Math.min(100, percent))
    readonly property bool low: !charging && clamped <= lowLevel
    readonly property color fillColor: charging ? Theme.accent : low ? Theme.danger : color
    readonly property color contrastColor: charging ? Theme.accentContent : Theme.background

    // Geometry (in pixels, relative to size)
    readonly property real stroke: size * 0.09
    readonly property real nubWidth: size * 0.12
    readonly property real nubGap: stroke * 0.6
    readonly property real bodyWidth: size * 2 - nubWidth - nubGap
    readonly property real bodyRadius: size * 0.3
    readonly property real inset: stroke + size * 0.065
    readonly property real innerWidth: bodyWidth - 2 * inset
    readonly property real innerHeight: size - 2 * inset

    // Displayed fraction (animated) and the matching fill width.
    property real shown: present ? clamped / 100 : 0
    readonly property real fillWidth: innerWidth * shown

    // Centre content: number, bolt, or both. The font shrinks if "100" + bolt do not fit.
    readonly property bool showNumber: present && showPercent
    readonly property bool showBolt: present && charging
    readonly property real boltHeight: showNumber ? size * 0.52 : size * 0.62
    readonly property real boltWidth: boltHeight * 10 / 16
    readonly property real spacing: size * 0.04
    readonly property real basePixelSize: size * 0.62
    readonly property real needed: (showNumber ? metrics.advanceWidth : 0) + (showBolt ? boltWidth : 0) + (showNumber && showBolt ? spacing : 0)
    readonly property real pixelSize: basePixelSize * Math.min(1, needed > 0 ? innerWidth * 0.88 / needed : 1)

    implicitWidth: size * 2
    implicitHeight: size

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    Behavior on shown {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    TextMetrics {
        id: metrics

        font.family: Appearance.font
        font.weight: Font.DemiBold
        font.pixelSize: root.basePixelSize
        text: Math.round(root.clamped).toString()
    }

    // Number + bolt in a single colour; instantiated twice, each inside its own clip.
    component Content: Row {
        id: content

        property color tint

        spacing: root.showNumber && root.showBolt ? root.spacing : 0
        height: root.size

        Text {
            visible: root.showNumber
            height: parent.height
            text: Math.round(root.clamped)
            color: content.tint
            font.family: Appearance.font
            font.weight: Font.DemiBold
            font.pixelSize: root.pixelSize
            font.features: ({
                    "tnum": 1
                })
            verticalAlignment: Text.AlignVCenter
            renderType: Text.NativeRendering
        }

        // Bolt: drawn in a 10×16 box and scaled.
        Item {
            visible: root.showBolt
            width: root.boltWidth
            height: parent.height

            Shape {
                anchors.centerIn: parent
                width: 10
                height: 16
                scale: root.boltHeight / 16
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: content.tint
                    strokeWidth: 1.4
                    fillColor: content.tint
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: "M 6.2 0.5 L 0.8 9 H 4.6 L 3.8 15.5 L 9.2 7 H 5.4 Z"
                    }
                }
            }
        }
    }

    Item {
        id: cell

        anchors.centerIn: parent
        width: root.size * 2
        height: root.size
        opacity: root.present ? 1 : 0.4

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // Cell outline
        Rectangle {
            width: root.bodyWidth
            height: parent.height
            radius: root.bodyRadius
            color: "transparent"
            border.width: root.stroke
            border.color: root.color
            antialiasing: true
        }

        // Terminal
        Rectangle {
            x: root.bodyWidth + root.nubGap
            anchors.verticalCenter: parent.verticalCenter
            width: root.nubWidth
            height: root.size * 0.38
            radius: width / 2
            color: root.color
            antialiasing: true
        }

        // Fill
        Rectangle {
            x: root.inset
            y: root.inset
            width: root.fillWidth
            height: root.innerHeight
            radius: Math.max(0, root.bodyRadius - root.inset)
            color: root.fillColor
            visible: width > 0.5
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // Empty part: content in the icon colour.
        Item {
            x: root.inset + root.fillWidth
            width: parent.width - x
            height: parent.height
            clip: true

            Content {
                x: (root.bodyWidth - width) / 2 - parent.x
                tint: root.color
            }
        }

        // Full part: content in a contrasting colour.
        Item {
            x: root.inset
            width: root.fillWidth
            height: parent.height
            clip: true

            Content {
                x: (root.bodyWidth - width) / 2 - parent.x
                tint: root.contrastColor
            }
        }
    }
}
