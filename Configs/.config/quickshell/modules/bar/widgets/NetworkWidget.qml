import QtQuick
import qs.components
import qs.services
import qs.modules.controls

// Network status. Click opens the network list; right click toggles Wi-Fi on/off.
BarItem {
    icon: Network.icon
    iconFill: 1
    iconColor: Network.wifiEnabled || Network.wired ? Theme.text : Theme.textFaint
    tooltip: Network.wired ? "Wired connection" : Network.activeWifi ? `${Network.name}\nSinal: ${Math.round(Network.signal * 100)}%` : Network.wifiEnabled ? "Wi-Fi not connected" : "Wi-Fi off"

    popoutName: "network"
    popout: Component {
        WifiPanel {}
    }
    onRightClicked: Network.setWifiEnabled(!Network.wifiEnabled)
}
