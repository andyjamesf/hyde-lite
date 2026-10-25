import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// Network status. Click opens the network list; right click toggles Wi-Fi on/off.
BarItem {
    icon: Network.icon
    iconFill: 1
    iconColor: Network.wifiEnabled || Network.wired ? Theme.text : Theme.textFaint
    tooltip: Network.wired ? "Wired connection" : Network.activeWifi ? `${Network.name}\nSignal: ${Network.strength}%` : Network.wifiEnabled ? "Wi-Fi not connected" : "Wi-Fi off"

    popoutName: "network"
    popout: Component {
        WifiPanel {}
    }
    onRightClicked: Network.setWifiEnabled(!Network.wifiEnabled)
}
