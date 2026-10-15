import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.theme

// The workspace indicator's content: one chip per workspace (number + app icons, "+N" for more),
// the current one filled with the accent colour. Click a chip to go there; scroll to step through.
// Used by the indicator pill next to the clock (core/IslandWindow.qml) and by the expanded island.
// The screen is the one of the window it is in. Options: config/WorkspacesConfig.qml.
Item {
    id: root

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property var list: Workspaces.forScreen(screenName)
    readonly property int iconSize: Math.round(Pill.height * WorkspacesConfig.iconFactor)
    readonly property int chipHeight: Math.round(Pill.height * 0.72)

    implicitWidth: row.implicitWidth
    implicitHeight: chipHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Workspaces.step(root.list, event.angleDelta.y > 0 ? -1 : 1)
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: WorkspacesConfig.spacing

        Repeater {
            model: root.list

            Rectangle {
                id: chip

                required property var modelData
                readonly property bool active: modelData.active

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: content.implicitWidth + 2 * Math.round(root.chipHeight * 0.32)
                implicitHeight: root.chipHeight
                radius: height / 2
                color: active ? Theme.accent : mouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Animations.duration(160)
                    }
                }
                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: Animations.duration(200)
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: Math.round(root.chipHeight * 0.18)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.name
                        font.weight: Font.DemiBold
                        color: chip.active ? Theme.accentContent : Theme.foreground
                    }

                    Repeater {
                        model: chip.modelData.apps

                        IconImage {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: root.iconSize
                            source: modelData.icon
                            // Unknown app: no broken image, just nothing.
                            visible: modelData.icon !== ""
                        }
                    }

                    Label {
                        visible: chip.modelData.extra > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: `+${chip.modelData.extra}`
                        font.pixelSize: Appearance.fontSize - 2
                        color: chip.active ? Theme.accentContent : Theme.dim
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Workspaces.focus(chip.modelData.id)
                }
            }
        }
    }
}
