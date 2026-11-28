import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

BarItem {
    shown: KdeConnect.installed
    icon: "devices"
    iconColor: KdeConnect.reachableCount > 0 ? Theme.text : Theme.textFaint
    tooltip: KdeConnect.devices.map(d => d.name + (d.battery >= 0 ? ` (${d.battery}%${d.charging ? ", charging" : ""})` : "")).join("\n") || "KDE Connect: no reachable devices"
    popoutName: "kdeconnect"
    popout: Component { KdeConnectPanel {} }
    onRightClicked: KdeConnect.refresh()
}
