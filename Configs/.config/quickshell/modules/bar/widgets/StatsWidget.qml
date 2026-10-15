import QtQuick
import qs.components
import qs.services

// CPU, memory, temperature and network traffic (each one can be enabled in config.json).
Row {
    id: root

    readonly property var cfg: Config.widgets.stats
    property bool shown: true

    Component.onCompleted: SystemStats.users++
    Component.onDestruction: SystemStats.users--

    BarItem {
        shown: root.cfg.cpu
        height: root.height
        icon: "memory"
        text: `${Math.round(SystemStats.cpu * 100)}%`
        tooltip: "CPU usage"
        onClicked: Utils.run("hyde-shell system.monitor.sh")
    }

    BarItem {
        shown: root.cfg.memory
        height: root.height
        icon: "memory_alt"
        text: `${Math.round(SystemStats.memory * 100)}%`
        tooltip: `Memory: ${Utils.formatBytes(SystemStats.memUsedBytes)}`
        onClicked: Utils.run("hyde-shell system.monitor.sh")
    }

    BarItem {
        shown: root.cfg.temperature && SystemStats.temperature > 0
        height: root.height
        icon: "thermostat"
        text: `${Math.round(SystemStats.temperature)}°`
        textColor: SystemStats.temperature >= 85 ? Theme.error : Theme.text
        tooltip: "CPU temperature"
    }

    BarItem {
        shown: root.cfg.network
        height: root.height
        icon: "swap_vert"
        text: `${Utils.formatBytes(SystemStats.rxRate)}/s`
        tooltip: `↓ ${Utils.formatBytes(SystemStats.rxRate)}/s\n↑ ${Utils.formatBytes(SystemStats.txRate)}/s`
    }
}
