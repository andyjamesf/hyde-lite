import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.services

// OSD window: only created while there is an OSD to show, on the focused screen (see shell.qml).
// It doesn't receive clicks; it slides up with a fade.
PanelWindow {
    id: win

    required property ShellScreen modelData
    // Only created when there is an OSD to show; `ready` lets the first entrance animate.
    property bool ready: false
    readonly property bool shown: ready && Osd.visible && (Hyprland.focusedMonitor?.name ?? "") === modelData.name
    Component.onCompleted: Qt.callLater(() => ready = true)

    screen: modelData
    visible: true
    anchors.bottom: true
    margins.bottom: 70
    implicitWidth: 300
    implicitHeight: 64
    exclusiveZone: 0
    color: "transparent"
    mask: Region {}

    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: pill

        width: parent.width
        height: 52
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.shown ? 0 : 12
        opacity: win.shown ? 1 : 0
        radius: height / 2
        color: Theme.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.border

        Behavior on y {
            NumberAnim {
                easing.bezierCurve: Anim.emphasized
            }
        }
        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }

        Rectangle {
            id: iconBg
            width: 36
            height: 36
            radius: height / 2
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Osd.muted ? Theme.surfaceContainerHighest : Theme.primary

            MaterialIcon {
                anchors.centerIn: parent
                icon: Osd.icon
                size: 20
                fill: 1
                color: Osd.muted ? Theme.textDim : Theme.onPrimary
            }
        }

        Rectangle {
            id: track
            anchors.left: iconBg.right
            anchors.leftMargin: 12
            anchors.right: label.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: Theme.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Osd.value))
                height: parent.height
                radius: 4
                color: Osd.muted ? Theme.textFaint : Theme.primary

                Behavior on width {
                    NumberAnim {
                        duration: Anim.fast
                    }
                }
            }
        }

        StyledText {
            id: label
            width: 44
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: Osd.muted ? "Muted" : `${Math.round(Osd.value * 100)}%`
            font.weight: Font.DemiBold
        }
    }
}
