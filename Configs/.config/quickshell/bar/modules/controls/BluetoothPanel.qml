import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// Bluetooth: on/off, paired devices (connect/disconnect/forget) and discovery of
// new devices to pair.
ColumnLayout {
    id: root
    // In the control center: the header gets the back button.
    property bool backButton: false
    signal back

    width: 320
    spacing: 8

    // Discovery drains battery: it stops when the panel closes.
    Component.onDestruction: Bluetooth.stopDiscovery()

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        icon: Bluetooth.icon
        title: "Bluetooth"
        subtitle: Bluetooth.summary
        hasSwitch: true
        checked: Bluetooth.enabled
        onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
    }

    SectionLabel {
        visible: Bluetooth.enabled && Bluetooth.paired.length > 0
        text: "My devices"
    }

    Repeater {
        model: Bluetooth.enabled ? Bluetooth.paired : []

        ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: Bluetooth.iconFor(modelData)
            iconFill: modelData.connected ? 1 : 0
            title: modelData.name
            subtitle: modelData.connecting ? "Connecting…" : modelData.connected ? "Connected" + (modelData.battery >= 0 ? ` · ${modelData.battery}% battery` : "") : "Disconnected"
            highlighted: modelData.connected
            busy: modelData.connecting
            onClicked: Bluetooth.toggle(modelData)

            IconButton {
                visible: !modelData.connected
                icon: "delete"
                size: 28
                color: Theme.textDim
                onClicked: modelData.forget()
            }
        }
    }

    RowLayout {
        visible: Bluetooth.enabled
        Layout.fillWidth: true

        SectionLabel {
            text: Bluetooth.discovering ? "Searching…" : "Other devices"
        }

        IconButton {
            icon: Bluetooth.discovering ? "stop" : "search"
            size: 30
            checked: Bluetooth.discovering
            onClicked: Bluetooth.discovering ? Bluetooth.stopDiscovery() : Bluetooth.startDiscovery()
        }
    }

    Flickable {
        visible: Bluetooth.enabled && Bluetooth.discovered.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 240)
        contentHeight: found.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: found
            width: parent.width

            Repeater {
                model: Bluetooth.discovered

                ListRow {
                    required property var modelData
                    width: found.width
                    icon: Bluetooth.iconFor(modelData)
                    title: modelData.name
                    subtitle: modelData.pairing ? "Pairing…" : "Click to pair"
                    busy: modelData.pairing
                    onClicked: Bluetooth.toggle(modelData)
                }
            }
        }
    }

    StyledText {
        visible: Bluetooth.enabled && !Bluetooth.discovering && Bluetooth.discovered.length === 0
        Layout.fillWidth: true
        text: "Tap the magnifier to search for new devices."
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
        wrapMode: Text.WordWrap
    }

    ListRow {
        Layout.fillWidth: true
        icon: "settings"
        title: "Bluetooth settings"
        onClicked: Utils.run("blueman-manager")
    }
}
