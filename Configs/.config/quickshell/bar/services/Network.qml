pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking as QsNet

// Network via Quickshell.Networking (NetworkManager over D-Bus, no nmcli).
Singleton {
    id: root

    readonly property var devices: QsNet.Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === QsNet.DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === QsNet.DeviceType.Wired) ?? null

    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values : []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null
    readonly property real signal: activeWifi?.signalStrength ?? 0
    readonly property bool online: QsNet.Networking.connectivity === QsNet.NetworkConnectivity.Full || wired || activeWifi !== null

    // Visible networks, without repeated names (multiple access points), the connected one first and then by signal.
    readonly property var networks: {
        const best = {};
        for (const n of wifiNetworks) {
            if (!n.name)
                continue;
            if (!best[n.name] || n.connected || n.signalStrength > best[n.name].signalStrength && !best[n.name].connected)
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength));
    }

    readonly property string name: wired ? "Ethernet" : activeWifi?.name ?? ""
    readonly property string icon: {
        if (wired)
            return "lan";
        if (!wifiEnabled)
            return "signal_wifi_off";
        if (!activeWifi)
            return "signal_wifi_statusbar_not_connected";
        return signalIcon(signal);
    }

    // Network scanning: only while some panel shows the list (user counter).
    property int scanUsers: 0
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanUsers > 0
        when: root.wifiDevice !== null
    }

    // Network waiting for a password (the control center shows the field).
    property var pendingNetwork: null
    property string lastError: ""

    function signalIcon(s) {
        return Utils.level(["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"], s * 100);
    }

    // Open networks (and OWE, encrypted without a password) connect without asking for anything.
    function isSecure(network) {
        return ![QsNet.WifiSecurityType.Open, QsNet.WifiSecurityType.Owe].includes(network.security);
    }

    function setWifiEnabled(on) {
        QsNet.Networking.wifiEnabled = on;
    }

    // Known or open networks connect right away; the others ask for the password first.
    function activate(network) {
        lastError = "";
        if (network.connected)
            network.disconnect();
        else if (network.known || !isSecure(network))
            network.connect();
        else
            pendingNetwork = network;
    }

    function connectWithPassword(password) {
        if (!pendingNetwork)
            return;
        lastError = "";
        pendingNetwork.connectWithPsk(password);
        pendingNetwork = null;
    }

    Instantiator {
        model: root.wifiNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root.lastError = `Could not connect to ${modelData.name}`;
                if (!modelData.known)
                    root.pendingNetwork = modelData;
            }
        }
    }
}
