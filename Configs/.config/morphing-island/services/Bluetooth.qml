pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBluetooth
import qs.config

// Bluetooth via Quickshell.Bluetooth (BlueZ over D-Bus, no bluetoothctl nor polling).
// For the control center: device list (plain objects), discovery that stops by itself after
// ControlCenter.btDiscoveryMs, connect/disconnect, pair and forget.
Singleton {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    // The adapter's BluetoothDevice objects (internal use, and for whoever needs the real object).
    readonly property var _rawDevices: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: _rawDevices.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0
    // Short text: "Off", "On", the name of the only connected device, or "N devices".
    readonly property string summary: !available ? "Unavailable" : !enabled ? "Off" : connectedDevices.length === 1 ? connectedDevices[0].name : connectedDevices.length > 1 ? `${connectedDevices.length} devices` : "On"

    // Devices for the list: the paired/connected ones and, of those found by discovery, only the ones
    // announcing a name (anonymous ones are noise: beacons, neighbours' phones, etc.).
    // Order: connected, paired, name. BlueZ gives the battery in 0..1; here it is 0..100 or -1.
    readonly property var devices: _rawDevices.filter(d => d.paired || d.bonded || d.connected || d.deviceName !== "").map(d => ({
                key: d.address,
                name: d.name || d.deviceName || d.address,
                icon: d.icon || "bluetooth",
                connected: d.connected,
                paired: d.paired || d.bonded,
                trusted: d.trusted,
                connecting: d.pairing || d.state === QsBluetooth.BluetoothDeviceState.Connecting || d.state === QsBluetooth.BluetoothDeviceState.Disconnecting,
                battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                device: d
            })).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    readonly property bool discovering: adapter?.discovering ?? false

    // Addresses whose pairing we requested: when it completes, they connect automatically.
    property var _pairRequests: ({})

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }

    // Discovery costs battery and radio: it stops by itself after ControlCenter.btDiscoveryMs.
    function startDiscovery() {
        if (!adapter || !adapter.enabled)
            return;
        adapter.discovering = true;
        discoveryTimeout.restart();
    }

    function stopDiscovery() {
        discoveryTimeout.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;
    }

    function connectDevice(key) {
        _find(key)?.connect();
    }

    function disconnectDevice(key) {
        _find(key)?.disconnect();
    }

    // Pairing a new device: trust it (so it reconnects by itself), pair and, when BlueZ confirms the
    // pairing, connect (see the Instantiator below).
    // Limitation: Quickshell does not register a BlueZ agent, so devices that require confirming or
    // entering a PIN only pair if another agent is running (e.g. blueman-applet); the ones using
    // "Just Works" (most headphones, mice and controllers) pair directly.
    function pairDevice(key) {
        const d = _find(key);
        if (!d)
            return;
        if (d.paired || d.bonded) {
            d.connect();
            return;
        }
        _pairRequests[key] = true;
        d.trusted = true;
        d.pair();
    }

    function forgetDevice(key) {
        const d = _find(key);
        if (!d)
            return;
        delete _pairRequests[key];
        d.forget();
    }

    function _afterPair(d) {
        if ((d.paired || d.bonded) && _pairRequests[d.address]) {
            delete _pairRequests[d.address];
            if (!d.connected)
                d.connect();
        }
    }

    function _find(key) {
        return _rawDevices.find(d => d.address === key) ?? null;
    }

    // If the adapter stops discovery some other way, the timer is no longer needed.
    onDiscoveringChanged: {
        if (!discovering)
            discoveryTimeout.stop();
    }

    Timer {
        id: discoveryTimeout
        interval: ControlCenter.btDiscoveryMs
        onTriggered: root.stopDiscovery()
    }

    Instantiator {
        model: root._rawDevices
        delegate: Connections {
            required property var modelData
            target: modelData
            // The request is not deleted when pairing ends unsuccessfully: pair()'s reply may arrive before
            // the Paired property, and a forgotten request is harmless.
            function onPairedChanged() {
                root._afterPair(modelData);
            }
            function onBondedChanged() {
                root._afterPair(modelData);
            }
        }
    }
}
