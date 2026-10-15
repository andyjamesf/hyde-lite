import QtQuick
import Quickshell
import qs.config
import qs.icons
import qs.services
import qs.theme

// Sound subview: outputs (sinks) and inputs (sources). Each device is a radio row (click → it
// becomes the default device) with its own volume slider below; the slider's icon mutes/unmutes
// that device. Long lists scroll (maxBody).
Item {
    id: root

    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int maxBody: ControlCenter.audioMaxBodyHeight

    readonly property var sinks: Audio.sinks ?? []
    readonly property var sources: Audio.sources ?? []

    implicitWidth: ControlCenter.width
    implicitHeight: header.y + header.height + 6 + body.height + pad

    CcHeader {
        id: header
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        title: "Sound"
    }

    Flickable {
        id: body
        x: root.pad
        y: header.y + header.height + 6
        width: root.width - 2 * root.pad
        height: Math.min(content.implicitHeight, root.maxBody)
        contentHeight: content.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: body.width
            spacing: 6

            SectionTitle {
                text: "Output"
            }

            Label {
                visible: root.sinks.length === 0
                width: parent.width
                leftPadding: 6
                height: 32
                text: "No output devices"
                color: Theme.faint
            }

            Repeater {
                model: ScriptModel {
                    values: root.sinks
                    objectProp: "key"
                }

                DeviceBlock {
                    required property var modelData
                    readonly property var fresh: root.sinks.find(s => s.key === modelData.key) ?? modelData

                    entry: fresh
                    input: false
                    onPicked: Audio.setDefaultSink(fresh.key)
                }
            }

            Item {
                width: 1
                height: 4
            }

            SectionTitle {
                text: "Input"
            }

            Label {
                visible: root.sources.length === 0
                width: parent.width
                leftPadding: 6
                height: 32
                text: "No input devices"
                color: Theme.faint
            }

            Repeater {
                model: ScriptModel {
                    values: root.sources
                    objectProp: "key"
                }

                DeviceBlock {
                    required property var modelData
                    readonly property var fresh: root.sources.find(s => s.key === modelData.key) ?? modelData

                    entry: fresh
                    input: true
                    onPicked: Audio.setDefaultSource(fresh.key)
                }
            }
        }
    }

    component SectionTitle: Label {
        leftPadding: 6
        height: 24
        color: Theme.dim
        font.pixelSize: Appearance.fontSize - 1
        font.weight: Font.DemiBold
    }

    // One device: radio + name; below it, its volume slider.
    component DeviceBlock: Column {
        id: block

        property var entry: ({})
        property bool input: false

        signal picked

        width: parent ? parent.width : 0
        spacing: 4

        Item {
            width: parent.width
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: pickMouse.pressed ? Theme.pressed : pickMouse.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Animations.duration(120)
                    }
                }
            }

            MouseArea {
                id: pickMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: block.entry.isDefault ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!block.entry.isDefault)
                        block.picked();
                }
            }

            // Radio
            Rectangle {
                id: radio
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: "transparent"
                border.width: 2
                border.color: block.entry.isDefault ? Theme.accent : Theme.faint

                Behavior on border.color {
                    ColorAnimation {
                        duration: Animations.duration(150)
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.accent
                    scale: block.entry.isDefault ? 1 : 0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Animations.duration(160)
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }

            Label {
                anchors.left: radio.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: block.entry.name || "Unknown device"
                textFormat: Text.PlainText
                font.weight: block.entry.isDefault ? Font.DemiBold : Font.Normal
            }
        }

        BigSlider {
            id: slider
            x: 6
            width: parent.width - 12
            thickness: 26
            value: block.entry.volume ?? 0
            muted: block.entry.muted ?? false
            label: slider.muted ? "Muted" : `${Math.round((block.entry.volume ?? 0) * 100)}%`
            iconClickable: true
            onMoved: v => Audio.setNodeVolume(block.entry.key, v)
            onIconClicked: Audio.toggleNodeMute(block.entry.key)

            VolumeIcon {
                visible: !block.input
                size: 14
                color: slider.iconColor
                level: block.entry.volume ?? 0
                muted: block.entry.muted ?? false
            }

            Glyph {
                visible: block.input
                kind: block.entry.muted ? "micOff" : "mic"
                size: 14
                color: slider.iconColor
            }
        }

        Item {
            width: 1
            height: 4
        }
    }
}
