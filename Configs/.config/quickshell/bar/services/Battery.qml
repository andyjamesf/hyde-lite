pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery and power profiles (UPower and power-profiles-daemon, native).
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    // Depending on the version, percentage comes as 0..1 or 0..100.
    readonly property int percent: available ? Math.round(device.percentage <= 1 ? device.percentage * 100 : device.percentage) : 0
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    readonly property bool plugged: available && [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(device.state)
    readonly property int secondsLeft: !available ? 0 : charging ? device.timeToFull : device.timeToEmpty
    readonly property bool low: available && !plugged && percent <= Config.widgets.battery.lowLevel

    readonly property string icon: {
        if (!available)
            return "battery_unknown";
        if (plugged)
            return percent >= 98 ? "battery_charging_full" : Utils.level(["battery_charging_20", "battery_charging_30", "battery_charging_50", "battery_charging_60", "battery_charging_80", "battery_charging_90"], percent);
        return Utils.level(["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"], percent);
    }

    readonly property int profile: PowerProfiles.profile
    readonly property string profileName: ["Power saver", "Balanced", "Performance"][profile] ?? ""
    readonly property string profileIcon: ["energy_savings_leaf", "balance", "speed"][profile] ?? "balance"

    function setProfile(p) {
        PowerProfiles.profile = p;
    }
}
