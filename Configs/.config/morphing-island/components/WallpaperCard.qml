import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.config
import qs.theme

// Preview card of a wallpaper (16:10, 12 px corners).
// States: active (3 px accent ring + check mark), hovered (scale 1.03 + faint ring), keyboard focus
// (outer ring), applying (veil + a spinning wheel until `current` changes).
Item {
    id: root

    // Entry of Wallpapers.list ({ path, name, thumb, … }).
    property var entry: ({})
    property bool active: false
    property bool focused: false
    property bool working: false
    readonly property bool hovered: mouse.containsMouse
    readonly property int radius: 12

    signal clicked

    function duration(ms) {
        return Animations.duration(ms);
    }

    Item {
        id: body
        anchors.fill: parent
        scale: root.hovered && !mouse.pressed ? 1.03 : mouse.pressed ? 0.98 : 1

        Behavior on scale {
            NumberAnimation {
                duration: root.duration(160)
                easing.type: Easing.OutCubic
            }
        }

        // Keyboard focus ring, outside the card.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: root.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Qt.alpha(Theme.foreground, 0.75)
            opacity: root.focused ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.duration(120)
                }
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            color: Theme.surface

            // Placeholder while the image loads: the surface pulsing slowly.
            Rectangle {
                anchors.fill: parent
                color: Theme.hover
                visible: image.status !== Image.Ready

                SequentialAnimation on opacity {
                    running: image.status === Image.Loading && Animations.enabled
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.3
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1
                        to: 0.3
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Image {
                id: image
                anchors.fill: parent
                source: root.entry && root.entry.thumb ? root.entry.thumb : ""
                // Decodes only at twice the card size (sharp on HiDPI screens, little memory).
                sourceSize: Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                retainWhileLoading: true
                smooth: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.duration(180)
                    }
                }
            }

            // Name at the bottom, only when hovered, focused or if the image failed.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 26
                color: Qt.alpha(Theme.background, 0.72)
                opacity: root.hovered || root.focused || image.status === Image.Error ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.duration(140)
                    }
                }

                Label {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    text: root.entry && root.entry.name ? root.entry.name : ""
                    font.pixelSize: Appearance.fontSize - 2
                }
            }

            // Applying: veil + wheel.
            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Theme.background, 0.5)
                opacity: root.working ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.duration(160)
                    }
                }

                Shape {
                    id: spinner
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 3
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 14
                            centerY: 14
                            radiusX: 11
                            radiusY: 11
                            startAngle: 0
                            sweepAngle: 270
                        }
                    }

                    RotationAnimator on rotation {
                        running: root.working
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }
            }
        }

        // Ring over the image: accent on the active one, a hint on hover, a subtle stroke on the rest.
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.width: root.active ? 3 : root.hovered ? 2 : 1
            border.color: root.active ? Theme.accent : root.hovered ? Qt.alpha(Theme.accent, 0.55) : Theme.border

            Behavior on border.color {
                ColorAnimation {
                    duration: root.duration(140)
                }
            }
        }

        // Check mark of the active one (top right corner).
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            width: 22
            height: 22
            radius: 11
            color: Theme.accent
            scale: root.active ? 1 : 0.4
            opacity: root.active ? 1 : 0
            visible: opacity > 0

            Behavior on scale {
                NumberAnimation {
                    duration: root.duration(200)
                    easing.type: Easing.OutBack
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.duration(140)
                }
            }

            Shape {
                anchors.centerIn: parent
                width: 24
                height: 24
                scale: 14 / 24
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.accentContent
                    strokeWidth: 3.4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    startX: 5
                    startY: 12.5

                    PathLine {
                        x: 10
                        y: 17.5
                    }
                    PathLine {
                        x: 19
                        y: 7
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouseEvent => {
            mouseEvent.accepted = true;
            root.clicked();
        }
    }
}
