pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBluetooth

// Bluetooth through Quickshell.Bluetooth (BlueZ over D-Bus, no bluetoothctl and no polling),
// shared by every UI of this configuration.
//
// The union of the two services it replaces. From the island: devices as entries carrying their
// own battery level, pairing state and whether they are mid-connection, pairing that connects by
// itself once BlueZ confirms, forgetting a device, and discovery that stops on its own instead of
// burning the radio until someone remembers. From the bar: the Material icons, both for the
// adapter and per device type, and the toggle behaviour of clicking a device.
//
// Limitation, inherited and worth knowing: Quickshell registers no BlueZ agent, so a device that
// asks to confirm a code or type a PIN only pairs if another agent is running (blueman-applet, for
// instance). "Just works" devices — most headphones, mice and controllers — pair from here.
Singleton {
    id: root

    readonly property var adapter: QsBluetooth.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    // The adapter's own objects, for whoever needs the real thing.
    readonly property var deviceNodes: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: deviceNodes.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0

    // The devices worth listing: paired or connected ones, and of those discovery turns up only the
    // ones announcing a name (the anonymous ones are noise — beacons, the neighbours' phones).
    // Order: connected, paired, name. BlueZ gives the battery as 0..1; here it is 0..100, or -1
    // when the device does not report one.
    readonly property var devices: deviceNodes.filter(d => d.paired || d.bonded || d.connected || d.deviceName !== "").map(d => ({
                key: d.address,
                name: d.name || d.deviceName || d.address,
                icon: iconFor(d),
                bluezIcon: d.icon || "bluetooth",
                connected: d.connected,
                paired: d.paired || d.bonded,
                trusted: d.trusted,
                connecting: d.pairing || d.state === QsBluetooth.BluetoothDeviceState.Connecting || d.state === QsBluetooth.BluetoothDeviceState.Disconnecting,
                battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                device: d
            })).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    // The same list split the way a panel shows it: the owner's devices, and the rest.
    readonly property var paired: devices.filter(d => d.paired)
    readonly property var discovered: devices.filter(d => !d.paired)

    readonly property string icon: !enabled ? "bluetooth_disabled" : connected ? "bluetooth_connected" : "bluetooth"
    readonly property string summary: !available ? "Unavailable" : !enabled ? "Off" : connectedDevices.length === 1 ? connectedDevices[0].name : connectedDevices.length > 1 ? `${connectedDevices.length} devices` : "On"

    // Discovery costs battery and radio, so it stops by itself after this long.
    property int discoveryMs: 30000

    // Addresses whose pairing we asked for: when it completes, they connect on their own.
    property var _pairRequests: ({})

    // Material Symbols name from the freedesktop icon BlueZ reports. Takes a device, an entry or a
    // key, like everything else here.
    function iconFor(which): string {
        const i = _resolve(which)?.icon ?? "";
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

    function setEnabled(on: bool): void {
        if (adapter)
            adapter.enabled = on;
    }

    function startDiscovery(): void {
        if (!adapter || !adapter.enabled)
            return;
        adapter.discovering = true;
        discoveryTimeout.restart();
    }

    function stopDiscovery(): void {
        discoveryTimeout.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;
    }

    function connectDevice(which): void {
        _resolve(which)?.connect();
    }

    function disconnectDevice(which): void {
        _resolve(which)?.disconnect();
    }

    // Pairing: trust it first, so it reconnects by itself, then pair; the Instantiator below
    // connects it once BlueZ says the pairing went through.
    function pairDevice(which): void {
        const d = _resolve(which);
        if (!d)
            return;
        if (d.paired || d.bonded) {
            d.connect();
            return;
        }
        _pairRequests[d.address] = true;
        d.trusted = true;
        d.pair();
    }

    function forgetDevice(which): void {
        const d = _resolve(which);
        if (!d)
            return;
        delete _pairRequests[d.address];
        d.forget();
    }

    // What clicking a device in a list does: drop it if it is connected, connect it if it is known,
    // pair it if it is new.
    function toggle(which): void {
        const d = _resolve(which);
        if (!d)
            return;
        if (d.connected)
            d.disconnect();
        else if (d.paired || d.bonded)
            d.connect();
        else
            pairDevice(d);
    }

    function _resolve(which) {
        if (!which)
            return null;
        if (which.address !== undefined)   // already a device
            return which;
        if (which.device)                  // an entry
            return which.device;
        return deviceNodes.find(d => d.address === String(which)) ?? null;
    }

    function _afterPair(d) {
        if ((d.paired || d.bonded) && _pairRequests[d.address]) {
            delete _pairRequests[d.address];
            if (!d.connected)
                d.connect();
        }
    }

    // If the adapter stops discovery some other way, the timer has nothing left to do.
    onDiscoveringChanged: {
        if (!discovering)
            discoveryTimeout.stop();
    }

    Timer {
        id: discoveryTimeout
        interval: root.discoveryMs
        onTriggered: root.stopDiscovery()
    }

    Instantiator {
        model: root.deviceNodes
        delegate: Connections {
            required property var modelData
            target: modelData
            // A request is not dropped when pairing fails: pair()'s reply can arrive before the
            // Paired property does, and a forgotten request does no harm.
            function onPairedChanged() {
                root._afterPair(modelData);
            }
            function onBondedChanged() {
                root._afterPair(modelData);
            }
        }
    }
}
