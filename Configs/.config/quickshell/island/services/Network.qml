pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking as QsNet

// Network state via Quickshell.Networking (NetworkManager over D-Bus, no nmcli nor polling).
// A wired connection takes priority over Wi-Fi in the name and level shown.
// For the control center: list of Wi-Fi networks (plain objects), scanning only while some panel
// shows it (scanUsers), connecting with or without a password, and forgetting networks.
Singleton {
    id: root

    readonly property var devices: QsNet.Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === QsNet.DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === QsNet.DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property bool wired: wiredDevice !== null
    readonly property bool connected: wired || activeWifi !== null
    readonly property string name: wired ? "Ethernet" : activeWifi?.name ?? ""
    // signalStrength comes in 0..1.
    readonly property int strength: wired ? 100 : activeWifi ? _percent(activeWifi.signalStrength) : 0
    // 0 without connection/signal; 1 < 25; 2 < 50; 3 < 75; 4 ≥ 75.
    readonly property int level: connected ? _levelOf(strength) : 0

    // Visible networks, one per SSID (several access points with the same name count as one: the
    // connected one or, failing that, the strongest). Order: connected, known, signal.
    // The objects are recreated when any property read here changes (the binding registers
    // connected/known/signalStrength/stateChanging of each network as dependencies).
    readonly property var networks: {
        const best = {};
        for (const n of wifiNetworks) {
            if (!n.name)
                continue;
            const b = best[n.name];
            if (!b || n.connected && !b.connected || !b.connected && n.signalStrength > b.signalStrength)
                best[n.name] = n;
        }
        return Object.values(best).map(n => {
            const s = _percent(n.signalStrength);
            return {
                key: n.name,
                name: n.name,
                strength: s,
                level: _levelOf(s),
                secured: _isSecured(n),
                connected: n.connected,
                known: n.known,
                connecting: n.stateChanging && !n.connected,
                network: n
            };
        }).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.strength - a.strength) || a.name.localeCompare(b.name));
    }

    // Scanning: each visible panel increments when it appears and decrements when it disappears.
    property int scanUsers: 0
    readonly property bool scanning: wifiDevice?.scannerEnabled ?? false

    // Network waiting for a password (the panel shows the field). Cleared on connecting or cancelling.
    readonly property string pendingKey: _pendingKey
    property string _pendingKey: ""
    // "" when all is well; an English message for the user when something fails.
    property string lastError: ""

    function setWifiEnabled(on) {
        QsNet.Networking.wifiEnabled = on;
    }

    // Known or open networks connect right away; unknown secured ones stay pending until the
    // password arrives (connectWithPassword).
    function connect(key) {
        const n = _find(key);
        if (!n || n.connected)
            return;
        lastError = "";
        if (n.known || !_isSecured(n)) {
            _pendingKey = "";
            n.connect();
        } else {
            _pendingKey = key;
        }
    }

    // pendingKey stays until the connection succeeds (if the password fails, the field remains).
    function connectWithPassword(key, password) {
        const n = _find(key);
        if (!n) {
            lastError = "Network not found";
            return;
        }
        lastError = "";
        _pendingKey = key;
        n.connectWithPsk(password);
    }

    function cancelPending() {
        _pendingKey = "";
        lastError = "";
    }

    function disconnect() {
        if (activeWifi)
            activeWifi.disconnect();
    }

    function forget(key) {
        const n = _find(key);
        if (!n)
            return;
        if (_pendingKey === key)
            _pendingKey = "";
        n.forget();
    }

    // Finds the network with that SSID, preferring the connected one (as in the list).
    function _find(key) {
        return networks.find(o => o.key === key)?.network ?? null;
    }

    function _percent(s) {
        return Math.round(Math.max(0, Math.min(1, s ?? 0)) * 100);
    }

    function _levelOf(s) {
        return s <= 0 ? 0 : s < 25 ? 1 : s < 50 ? 2 : s < 75 ? 3 : 4;
    }

    // Open networks (and OWE, encrypted without a password) connect without asking for anything.
    function _isSecured(n) {
        return n.security !== QsNet.WifiSecurityType.Open && n.security !== QsNet.WifiSecurityType.Owe;
    }

    function _failMessage(name, reason) {
        switch (reason) {
        case QsNet.ConnectionFailReason.NoSecrets:
            return `Wrong password for ${name}`;
        case QsNet.ConnectionFailReason.WifiAuthTimeout:
            return `Authentication with ${name} timed out`;
        case QsNet.ConnectionFailReason.WifiNetworkLost:
            return `${name} is out of range`;
        default:
            return `Could not connect to ${name}`;
        }
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanUsers > 0
        when: root.wifiDevice !== null
    }

    // Turning Wi-Fi off cancels any ongoing password request.
    onWifiEnabledChanged: {
        if (!wifiEnabled)
            _pendingKey = "";
    }

    Instantiator {
        model: root.wifiNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (modelData.connected && modelData.name === root._pendingKey) {
                    root._pendingKey = "";
                    root.lastError = "";
                }
            }
            function onConnectionFailed(reason) {
                root.lastError = root._failMessage(modelData.name, reason);
                // Wrong or missing password: ask for it again.
                if (reason === QsNet.ConnectionFailReason.NoSecrets || !modelData.known && root._isSecured(modelData))
                    root._pendingKey = modelData.name;
            }
        }
    }
}
