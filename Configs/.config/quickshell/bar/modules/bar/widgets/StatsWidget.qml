import QtQuick
import qs.bar.components
import qs.bar.services

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
        textColor: Theme.textDim
        tooltip: `CPU ${Math.round(SystemStats.cpu * 100)}%\nMemory ${Math.round(SystemStats.memory * 100)}% (${Utils.formatBytes(SystemStats.memUsedBytes)})\nTemperature ${Math.round(SystemStats.temperature)}°`
        onClicked: Utils.run("hyde-shell system.monitor.sh")
    }

    BarItem {
        shown: root.cfg.memory && (!root.cfg.onlyWhenHigh || SystemStats.memory >= root.cfg.memoryHigh)
        height: root.height
        icon: "memory_alt"
        text: `${Math.round(SystemStats.memory * 100)}%`
        textColor: Theme.text
        tooltip: `Memory: ${Utils.formatBytes(SystemStats.memUsedBytes)}`
        onClicked: Utils.run("hyde-shell system.monitor.sh")
    }

    BarItem {
        shown: root.cfg.temperature && SystemStats.temperature > 0 && (!root.cfg.onlyWhenHigh || SystemStats.temperature >= root.cfg.temperatureHigh)
        height: root.height
        icon: "thermostat"
        text: `${Math.round(SystemStats.temperature)}°`
        textColor: SystemStats.temperature >= 85 ? Theme.error : Theme.textDim
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
