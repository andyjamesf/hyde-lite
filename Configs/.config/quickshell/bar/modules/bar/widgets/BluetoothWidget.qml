import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// Bluetooth. Click opens the devices; right click toggles it on/off.
BarItem {
    shown: Bluetooth.available
    icon: Bluetooth.icon
    iconColor: Bluetooth.enabled ? Theme.text : Theme.textFaint
    tooltip: !Bluetooth.enabled ? "Bluetooth off" : Bluetooth.connected ? Bluetooth.devices.filter(d => d.connected).map(d => d.name + (d.battery >= 0 ? ` (${d.battery}%)` : "")).join("\n") : "Bluetooth on, no devices"

    popoutName: "bluetooth"
    popout: Component {
        BluetoothPanel {}
    }
    onRightClicked: Bluetooth.setEnabled(!Bluetooth.enabled)
}
