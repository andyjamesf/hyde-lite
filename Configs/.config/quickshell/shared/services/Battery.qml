pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery and power profile (UPower and power-profiles-daemon, native over D-Bus).
//
// Shared by every UI of this configuration: the bar, the minimal bar and the island all read this
// one singleton. It is the union of the two services that used to sit in bar/services and
// island/services and had drifted apart — each knew things the other did not (the bar had the
// icon, the low-battery flag and a single `secondsLeft`; the island had `isPresent`, battery
// health, the performance profile and `degraded`), so a feature present in one shell was missing
// from the other for no reason other than where it was written.
//
// It depends on nothing but Quickshell: a shared service cannot read a UI's own settings, so what
// one of them has to configure is a plain property that UI sets (see `lowLevel`).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    // A machine with no battery (a desktop) leaves this false and everything below at rest.
    readonly property bool available: (device?.isLaptopBattery ?? false) && (device?.isPresent ?? false)

    // The percentage arrives as 0..1 in some versions of UPower and as 0..100 in others; a value
    // above 1 is taken as already being a percentage. Rounded, because every caller shows it.
    readonly property int percent: available ? Math.round(Math.max(0, Math.min(100, device.percentage > 1 ? device.percentage : device.percentage * 100))) : 0

    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    // On mains: charging, full, or waiting to charge (a charge limit is set).
    readonly property bool plugged: available && (!UPower.onBattery || [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(device.state))

    // Seconds; 0 while UPower has no estimate yet.
    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0
    // Whichever of the two means something right now.
    readonly property real secondsLeft: charging ? timeToFull : timeToEmpty

    // Full capacity now against when it was new, 0..100; -1 when UPower does not know.
    readonly property real health: available && (device?.healthSupported ?? false) ? device.healthPercentage : -1

    // Below this, `low` is true. A shared service has no settings file of its own, so the UI that
    // has one sets this (the bar binds it to config.json, widgets.battery.lowLevel).
    property int lowLevel: 20
    readonly property bool low: available && !plugged && percent <= lowLevel

    // Material Symbols name for the bar's widgets. The island draws its own battery, so it ignores
    // this; it stays here because it is a reading of the state, not a rendering of it. The level
    // helper is inlined: a shared service cannot reach into a UI's Utils.
    readonly property string icon: {
        if (!available)
            return "battery_unknown";
        const pick = list => list[Math.max(0, Math.min(list.length - 1, Math.floor(percent * list.length / 101)))];
        if (plugged)
            return percent >= 98 ? "battery_charging_full" : pick(["battery_charging_20", "battery_charging_30", "battery_charging_50", "battery_charging_60", "battery_charging_80", "battery_charging_90"]);
        return pick(["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"]);
    }

    // Power profile: 0 power saver, 1 balanced, 2 performance (when the machine has it).
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var profileNames: ["Power saver", "Balanced", "Performance"]
    readonly property string profileName: profileNames[profile] ?? ""
    readonly property string profileIcon: ["energy_savings_leaf", "balance", "speed"][profile] ?? "balance"
    // The system is holding performance back (too hot, laptop on a lap).
    readonly property bool degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

    function setProfile(p: int): void {
        PowerProfiles.profile = p;
    }

    // Saver → balanced → performance → saver, for the control centre's tile.
    function cycleProfile(): void {
        setProfile((profile + 1) % (hasPerformance ? 3 : 2));
    }
}
