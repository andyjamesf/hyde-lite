import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.services

// Sound: output and input volume, device selection and per-app volume.
ColumnLayout {
    id: root
    // In the control center: the header gets the back button.
    property bool backButton: false
    signal back

    width: 320
    spacing: 10

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        icon: Audio.icon
        title: "Sound"
        subtitle: Audio.nameOf(Audio.sink)

        IconButton {
            icon: "tune"
            size: 32
            tooltip: "Misturador"
            onClicked: Utils.run("pavucontrol-qt || pavucontrol")
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        icon: Audio.icon
        value: Audio.muted ? 0 : Audio.volume
        onMoved: v => Audio.setVolume(v)
        onIconClicked: Audio.toggleMute()
    }

    SectionLabel {
        visible: Audio.sinks.length > 1
        text: "Output"
    }

    Repeater {
        model: Audio.sinks.length > 1 ? Audio.sinks : []

        ListRow {
            required property PwNode modelData
            Layout.fillWidth: true
            icon: (modelData.properties["device.form-factor"] ?? "").includes("head") ? "headphones" : "speaker"
            title: Audio.nameOf(modelData)
            highlighted: modelData === Audio.sink
            onClicked: Audio.setSink(modelData)
        }
    }

    SectionLabel {
        text: "Microphone"
    }

    StyledSlider {
        Layout.fillWidth: true
        icon: Audio.micIcon
        value: Audio.micMuted ? 0 : Audio.micVolume
        onMoved: v => Audio.setMicVolume(v)
        onIconClicked: Audio.toggleMicMute()
    }

    Repeater {
        model: Audio.sources.length > 1 ? Audio.sources : []

        ListRow {
            required property PwNode modelData
            Layout.fillWidth: true
            icon: "mic"
            title: Audio.nameOf(modelData)
            highlighted: modelData === Audio.source
            onClicked: Audio.setSource(modelData)
        }
    }

    SectionLabel {
        visible: Audio.streams.length > 0
        text: "Apps"
    }

    Repeater {
        model: Audio.streams

        RowLayout {
            id: stream

            required property PwNode modelData

            Layout.fillWidth: true
            spacing: 10

            Image {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                source: Quickshell.iconPath(Audio.appIconOf(stream.modelData), "audio-x-generic")
                sourceSize.width: 48
                sourceSize.height: 48
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: Audio.appNameOf(stream.modelData)
                    font.pixelSize: Theme.labelSmall
                    color: Theme.textDim
                }

                StyledSlider {
                    Layout.fillWidth: true
                    trackHeight: 16
                    value: stream.modelData.audio?.muted ? 0 : (stream.modelData.audio?.volume ?? 0)
                    onMoved: v => Audio.setNodeVolume(stream.modelData, v)
                }
            }
        }
    }
}
