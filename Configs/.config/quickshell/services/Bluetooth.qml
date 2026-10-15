pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBluetooth

// Bluetooth via Quickshell.Bluetooth (BlueZ over D-Bus, no bluetoothctl).
Singleton {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connected: devices.filter(d => d.connected)
    // Paired first (connected at the top), then new ones found by discovery, that have a name.
    readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => b.connected - a.connected)
    readonly property var discovered: devices.filter(d => !d.paired && !d.bonded && d.deviceName !== "")

    readonly property string icon: !enabled ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"
    readonly property string summary: !enabled ? "Off" : connected.length === 1 ? connected[0].name : connected.length > 1 ? `${connected.length} devices` : "On"

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }

    function setScanning(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }

    // Material icon derived from the freedesktop icon BlueZ reports.
    function iconFor(device) {
        const i = device?.icon ?? "";
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio"))
            return "speaker";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("phone"))
            return "smartphone";
        if (i.includes("gaming") || i.includes("joystick"))
            return "sports_esports";
        if (i.includes("computer"))
            return "computer";
        return "bluetooth";
    }

    // Connecting a new device: pair, trust (so it reconnects by itself) and connect.
    function activate(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired || device.bonded) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    Instantiator {
        model: root.discovered
        delegate: Connections {
            required property var modelData
            target: modelData
            function onPairedChanged() {
                if (modelData.paired)
                    modelData.connect();
            }
        }
    }
}
