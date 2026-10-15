pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery via UPower (native, over D-Bus). Uses UPower's "display device", which aggregates the
// laptop's batteries; on a machine without a battery `available` stays false. Also the power
// profile (power-profiles-daemon, through UPower's PowerProfiles).
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: (device?.isLaptopBattery ?? false) && (device?.isPresent ?? false)
    // In Quickshell the percentage comes as 0..1 (a fraction), despite the name; if some version gives
    // it as 0..100 (the raw D-Bus value), it is used as is.
    readonly property real percent: available ? Math.max(0, Math.min(100, device.percentage > 1 ? device.percentage : device.percentage * 100)) : 0
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    // On AC power: charging, fully charged or waiting to charge (charge limit).
    readonly property bool plugged: available && (!UPower.onBattery || [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(device.state))
    // Seconds (0 while UPower has no estimate yet).
    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0

    // Battery health (full capacity now vs when new), 0..100; -1 when UPower does not know it.
    readonly property real health: available && (device?.healthSupported ?? false) ? device.healthPercentage : -1

    // Power profile: 0 power saver, 1 balanced, 2 performance (when the machine has it).
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var profileNames: ["Power saver", "Balanced", "Performance"]
    readonly property string profileName: profileNames[profile] ?? ""
    // The system holds performance back (too hot, laptop on a lap): shown on the battery page.
    readonly property bool degraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

    function setProfile(p) {
        PowerProfiles.profile = p;
    }
    // Next profile (the control center tile): saver → balanced → performance → saver.
    function cycleProfile() {
        setProfile((profile + 1) % (hasPerformance ? 3 : 2));
    }
}
