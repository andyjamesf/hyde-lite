pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Networking as QsNet

// Network through Quickshell.Networking (NetworkManager over D-Bus, no nmcli and no polling),
// shared by every UI of this configuration. A wired connection takes priority over Wi-Fi in the
// name and the level shown.
//
// The union of the two services this replaces. From the island: the networks as entries with a key
// of their own, the failure messages that say what actually went wrong, disconnect, forget and
// cancelPending. From the bar: `online` (which asks NetworkManager whether the connection reaches
// anywhere, not just whether it is up), the Material icons and the toggle behaviour of clicking a
// network. The island's half was the fuller one, so the bar gains the most here: before, a wrong
// password only ever said "Could not connect".
Singleton {
    id: root

    readonly property var devices: QsNet.Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === QsNet.DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === QsNet.DeviceType.Wired) ?? null
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property bool wired: wiredDevice?.connected ?? false
    // Something is up…
    readonly property bool connected: wired || activeWifi !== null
    // …and it reaches somewhere (a captive portal or a dead router is connected but not online).
    readonly property bool online: QsNet.Networking.connectivity === QsNet.NetworkConnectivity.Full || connected

    readonly property string name: wired ? "Ethernet" : activeWifi?.name ?? ""
    // 0..1, as Quickshell reports it; `strength` is the same as a percentage and `level` as 0..4.
    readonly property real signal: activeWifi?.signalStrength ?? 0
    readonly property int strength: wired ? 100 : activeWifi ? _percent(signal) : 0
    readonly property int level: connected ? _levelOf(strength) : 0

    // The visible networks, one entry per SSID (several access points with the same name count as
    // one: the connected one or, failing that, the strongest). Order: connected, known, signal.
    // Reading each network's fields here is what makes the list follow their changes.
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
                secured: isSecure(n),
                connected: n.connected,
                known: n.known,
                connecting: n.stateChanging && !n.connected,
                network: n
            };
        }).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.strength - a.strength) || a.name.localeCompare(b.name));
    }

    // Scanning: each visible panel counts itself in while it is shown and out when it goes away.
    property int scanUsers: 0
    readonly property bool scanning: wifiDevice?.scannerEnabled ?? false

    // The network waiting for a password (a panel shows the field). Cleared once it connects or
    // when the request is cancelled.
    readonly property string pendingKey: _pendingKey
    property string _pendingKey: ""
    // "" while all is well; otherwise a message for the owner.
    property string lastError: ""

    // Material Symbols name for the shells that draw with them.
    readonly property string icon: {
        if (wired)
            return "lan";
        if (!wifiEnabled)
            return "signal_wifi_off";
        if (!activeWifi)
            return "signal_wifi_statusbar_not_connected";
        return signalIcon(signal);
    }

    // Takes the signal either as 0..1 or as a percentage.
    function signalIcon(s: real): string {
        const pct = s <= 1 ? s * 100 : s;
        const list = ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"];
        return list[Math.max(0, Math.min(list.length - 1, Math.floor(pct * list.length / 101)))];
    }

    // Open networks (and OWE, encrypted without a password) connect without asking for anything.
    // Takes a network, an entry or a key.
    function isSecure(which): bool {
        const n = _resolve(which);
        return !!n && n.security !== QsNet.WifiSecurityType.Open && n.security !== QsNet.WifiSecurityType.Owe;
    }

    function setWifiEnabled(on: bool): void {
        QsNet.Networking.wifiEnabled = on;
    }

    // Known or open networks connect straight away; an unknown secured one waits for the password
    // (pendingKey, then connectWithPassword).
    function connect(which): void {
        const n = _resolve(which);
        if (!n || n.connected)
            return;
        lastError = "";
        if (n.known || !isSecure(n)) {
            _pendingKey = "";
            n.connect();
        } else {
            _pendingKey = n.name;
        }
    }

    // What clicking a network in a list does: connect to it, or drop it if it is the one connected.
    function toggle(which): void {
        const n = _resolve(which);
        if (!n)
            return;
        if (n.connected)
            n.disconnect();
        else
            connect(n);
    }

    // The key may be left out, and then it is the one waiting. pendingKey stays until the
    // connection succeeds, so a wrong password leaves the field where it was.
    function connectWithPassword(key, password): void {
        if (password === undefined) {
            password = key;
            key = _pendingKey;
        }
        const n = _resolve(key);
        if (!n) {
            lastError = "Network not found";
            return;
        }
        lastError = "";
        _pendingKey = n.name;
        n.connectWithPsk(password);
    }

    function cancelPending(): void {
        _pendingKey = "";
        lastError = "";
    }

    function disconnect(): void {
        if (activeWifi)
            activeWifi.disconnect();
    }

    function forget(which): void {
        const n = _resolve(which);
        if (!n)
            return;
        if (_pendingKey === n.name)
            _pendingKey = "";
        n.forget();
    }

    // Takes whatever the caller has: a network, an entry from `networks`, or a key (the SSID).
    function _resolve(which) {
        if (!which)
            return null;
        if (which.security !== undefined)   // already a network
            return which;
        if (which.network)                  // an entry
            return which.network;
        return networks.find(o => o.key === String(which))?.network ?? null;
    }

    function _percent(s) {
        return Math.round(Math.max(0, Math.min(1, s ?? 0)) * 100);
    }

    function _levelOf(s) {
        return s <= 0 ? 0 : s < 25 ? 1 : s < 50 ? 2 : s < 75 ? 3 : 4;
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

    // Turning Wi-Fi off cancels any password request that was open.
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
                // A wrong or missing password: ask for it again.
                if (reason === QsNet.ConnectionFailReason.NoSecrets || !modelData.known && root.isSecure(modelData))
                    root._pendingKey = modelData.name;
            }
        }
    }
}
