import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as QsBluetooth
import qs.components
import qs.services

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
    Component.onDestruction: Bluetooth.setScanning(false)

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
            subtitle: modelData.state === QsBluetooth.BluetoothDeviceState.Connecting ? "Connecting…" : modelData.connected ? "Connected" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}% bateria` : "") : "Disconnected"
            highlighted: modelData.connected
            busy: modelData.state === QsBluetooth.BluetoothDeviceState.Connecting || modelData.state === QsBluetooth.BluetoothDeviceState.Disconnecting
            onClicked: Bluetooth.activate(modelData)

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
            text: Bluetooth.scanning ? "Searching…" : "Other devices"
        }

        IconButton {
            icon: Bluetooth.scanning ? "stop" : "search"
            size: 30
            checked: Bluetooth.scanning
            onClicked: Bluetooth.setScanning(!Bluetooth.scanning)
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
                    onClicked: Bluetooth.activate(modelData)
                }
            }
        }
    }

    StyledText {
        visible: Bluetooth.enabled && !Bluetooth.scanning && Bluetooth.discovered.length === 0
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
