pragma Singleton
import QtQuick
import Quickshell
import qs.shared.services

// What the control centre offers, as data: one list of toggles, read by every UI of this
// configuration. The bar draws them as a grid of buttons, the island as a column of tiles, and
// both draw the same ones, in the same order, with the same labels and the same behaviour.
//
// This is what the shared layer was for. Until the services underneath were shared a toggle could
// not be described once — "do not disturb" meant Notifs.dnd in the bar and
// Notifications.peaceMode in the island — so each shell had written its own row and they drifted:
// the bar had Colors and Silent, the island had Power Profile, Peace Mode and Sound, and neither
// had the other's.
//
// Each entry carries what both views need:
//   id          what toggle() takes, and what a view keys its own icon on
//   label       shown under (bar) or beside (island) the icon
//   icon        Material Symbols name, for the views that draw with them
//   status      a word or two about the current state, for the views that show one
//   active      whether it reads as on
//   available   false leaves it out (no Bluetooth adapter, no night light installed)
//   page        the detail page a view opens when the entry is expanded; "" does not expand
//
// A shell with a toggle of its own puts it in `extra` from its Shell.qml, the way the picker
// registry takes one — the bar's Colors, which has no meaning in the island.
Singleton {
    id: root

    property var extra: []

    readonly property var items: [
        {
            id: "wifi",
            label: "Wi-Fi",
            icon: Network.wired ? "lan" : Network.icon,
            status: !Network.wifiEnabled ? (Network.wired ? "Ethernet" : "Off") : Network.connected ? Network.name : "Not connected",
            active: Network.wifiEnabled,
            available: true,
            page: "wifi"
        },
        {
            id: "bluetooth",
            label: "Bluetooth",
            icon: Bluetooth.icon,
            status: Bluetooth.summary,
            active: Bluetooth.enabled,
            available: Bluetooth.available,
            page: "bluetooth"
        },
        {
            id: "sound",
            label: "Sound",
            icon: Audio.icon,
            status: Audio.muted ? "Muted" : `${Math.round(Audio.volume * 100)}%`,
            active: !Audio.muted,
            available: Audio.ready,
            page: "audio"
        },
        {
            id: "mic",
            label: "Microphone",
            icon: Audio.micIcon,
            status: Audio.micMuted ? "Off" : `${Math.round(Audio.micVolume * 100)}%`,
            active: !Audio.micMuted,
            available: !!Audio.source,
            page: "audio"
        },
        {
            id: "dnd",
            label: "Do not disturb",
            icon: Notifications.peaceMode ? "notifications_off" : "notifications",
            status: Notifications.peaceMode ? "On" : "Off",
            active: Notifications.peaceMode,
            available: true,
            page: ""
        },
        {
            id: "nightlight",
            label: "Night light",
            icon: "nightlight",
            status: !NightLight.available ? "Unavailable" : NightLight.active ? `${NightLight.currentTemperature} K` : "Off",
            active: NightLight.active,
            available: NightLight.available,
            page: ""
        },
        {
            id: "caffeine",
            label: "Caffeine",
            icon: "coffee",
            status: Caffeine.active ? (Caffeine.remaining || "Staying awake") : "Off",
            active: Caffeine.active,
            available: true,
            page: ""
        },
        {
            id: "powerProfile",
            label: "Power profile",
            icon: Battery.profileIcon,
            status: Battery.profileName,
            active: Battery.profile !== 1,
            available: true,
            page: "battery"
        }
    ]

    // Everything a view should draw: the shared ones that are available, then the shell's own.
    readonly property var shown: items.filter(t => t.available).concat(extra)

    function get(id) {
        return shown.find(t => t.id === id) ?? null;
    }

    // What clicking one does. A view calls this and nothing else, so no shell decides on its own
    // what "do not disturb" means any more.
    function toggle(id: string): void {
        switch (id) {
        case "wifi":
            Network.setWifiEnabled(!Network.wifiEnabled);
            return;
        case "bluetooth":
            Bluetooth.setEnabled(!Bluetooth.enabled);
            return;
        case "sound":
            Audio.toggleMute();
            return;
        case "mic":
            Audio.toggleMicMute();
            return;
        case "dnd":
            Notifications.togglePeace();
            return;
        case "nightlight":
            NightLight.toggle();
            return;
        case "powerProfile":
            Battery.cycleProfile();
            return;
        case "caffeine":
            Caffeine.toggle();
            return;
        default:
            // A shell's own entry carries its action with it.
            const own = extra.find(t => t.id === id);
            if (own && own.toggle)
                own.toggle();
        }
    }
}
