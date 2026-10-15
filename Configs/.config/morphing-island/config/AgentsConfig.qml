pragma Singleton
import QtQuick
import Quickshell

// Wi-Fi and Bluetooth requests (scripts/agents.py): a network that needs a password, a Bluetooth
// PIN, passkey or code to confirm. The island asks instead of nm-applet's and blueman's windows,
// which `island on` stops (and `island off` starts again, for the HyDE shell).
// (Named AgentsConfig because services/Agents.qml is the service.)
Singleton {
    // Answer these requests in the island. false = nobody answers them while the island runs
    // (then start nm-applet / blueman-applet yourself). Default true.
    readonly property bool enabled: true
    // Minimum length of a Wi-Fi (WPA) password; shorter ones are refused before sending. Default 8.
    readonly property int minWifiPassword: 8
}
