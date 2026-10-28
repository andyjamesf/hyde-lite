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
    // On the minimal bar / when widgets.battery.showTime is on: "87% · 3 h 20 min" when UPower has an
    // estimate, otherwise the state ("charging", "full", "plugged in", "on battery"), because UPower
    // gives no time while full or just after the charger changes.
    readonly property string timeText: {
        if (!BarLayout.batteryShowTime)
            return "";
        if (Battery.secondsLeft > 0)
            return Utils.formatDuration(Battery.secondsLeft);
        return Battery.charging ? "charging" : Battery.plugged ? (Battery.percent >= 95 ? "full" : "plugged in") : "on battery";
    }
    text: [cfg.showPercent ? `${Battery.percent}%` : "", timeText].filter(t => t !== "").join(" · ")
    textColor: Battery.low ? Theme.error : Theme.text
    tooltip: `${Battery.percent}% · ${Battery.charging ? "charging" : Battery.plugged ? "plugged in" : "on battery"}` + (Battery.secondsLeft > 0 ? `\n${Utils.formatDuration(Battery.secondsLeft)} ${Battery.charging ? "until full" : "left"}` : "") + `\nProfile: ${Battery.profileName}`

    popoutName: "battery"
    popout: Component {
        BatteryPanel {}
    }
}
