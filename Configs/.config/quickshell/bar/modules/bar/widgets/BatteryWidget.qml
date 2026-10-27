import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// Battery. Click opens the panel (charge, time remaining, power profile).
BarItem {
    readonly property var cfg: Config.widgets.battery

    shown: Battery.available
    icon: Battery.icon
    iconFill: 1
    iconColor: Battery.low ? Theme.error : Battery.plugged ? Theme.success : Theme.text
    // "87% · 3 h 20 min" on the minimal bar when it asks for the time (MiniBarConfig.batteryShowTime).
    readonly property string timeText: BarLayout.batteryShowTime && Battery.secondsLeft > 0 ? Utils.formatDuration(Battery.secondsLeft) : ""
    text: [cfg.showPercent ? `${Battery.percent}%` : "", timeText].filter(t => t !== "").join(" · ")
    textColor: Battery.low ? Theme.error : Theme.text
    tooltip: `${Battery.percent}% · ${Battery.charging ? "charging" : Battery.plugged ? "plugged in" : "on battery"}` + (Battery.secondsLeft > 0 ? `\n${Utils.formatDuration(Battery.secondsLeft)} ${Battery.charging ? "until full" : "left"}` : "") + `\nProfile: ${Battery.profileName}`

    popoutName: "battery"
    popout: Component {
        BatteryPanel {}
    }
}
