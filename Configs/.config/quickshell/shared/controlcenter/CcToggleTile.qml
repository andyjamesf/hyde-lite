import QtQuick
import qs.shared.icons
import qs.shared.services

// One tile of the control centre for one entry of CcToggles: its name and status, the round badge
// that toggles it, and (when it has a detail page) the arrow that opens it. The icon in the badge
// is picked here, from the same set in every shell.
CcTile {
    id: tile

    // An id of CcToggles.items.
    required property string toggleId
    readonly property var entry: CcToggles.get(toggleId) ?? ({})

    // The detail page the body asks for ("wifi", "bluetooth", "audio", "battery").
    signal pageRequested(string page)

    title: entry.label ?? ""
    status: entry.status ?? ""
    active: entry.active ?? false
    enabled: toggleId === "bluetooth" ? Bluetooth.available : toggleId === "nightlight" ? NightLight.available : true
    expandable: (entry.page ?? "") !== ""
    onToggled: CcToggles.toggle(toggleId)
    onOpened: pageRequested(entry.page ?? "")

    Loader {
        sourceComponent: ({
                wifi: wifiIcon,
                bluetooth: bluetoothIcon,
                sound: soundIcon,
                mic: micIcon,
                dnd: dndIcon,
                nightlight: nightIcon,
                caffeine: caffeineIcon,
                powerProfile: profileIcon,
                colors: colorsIcon
            })[tile.toggleId] ?? null
    }

    Component {
        id: wifiIcon

        WifiIcon {
            size: 18
            color: tile.iconColor
            level: Network.wired ? 4 : Network.level
            enabled: Network.wifiEnabled || Network.wired
            connected: Network.connected
        }
    }

    Component {
        id: bluetoothIcon

        BluetoothIcon {
            size: 18
            color: tile.iconColor
            enabled: Bluetooth.enabled
            connected: Bluetooth.connected
        }
    }

    Component {
        id: soundIcon

        VolumeIcon {
            size: 18
            color: tile.iconColor
            level: Audio.volume
            muted: Audio.muted
        }
    }

    Component {
        id: micIcon

        CcLabel {
            text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
            font.family: CcTheme.nerdFont
            font.pixelSize: 18
            elide: Text.ElideNone
            color: tile.iconColor
        }
    }

    Component {
        id: dndIcon

        Glyph {
            kind: Notifications.peaceMode ? "bellOff" : "bell"
            size: 18
            color: tile.iconColor
        }
    }

    Component {
        id: nightIcon

        MoonIcon {
            size: 17
            color: tile.iconColor
        }
    }

    Component {
        id: caffeineIcon

        Glyph {
            kind: "coffee"
            size: 18
            color: tile.iconColor
        }
    }

    // Power profile: a click goes to the next one; the arrow opens the battery page with all three.
    Component {
        id: profileIcon

        CcLabel {
            text: ["\u{F032A}", "\u{F05D1}", "\u{F14DE}"][Battery.profile] ?? "\u{F05D1}"
            font.family: CcTheme.nerdFont
            font.pixelSize: 18
            elide: Text.ElideNone
            color: tile.iconColor
        }
    }

    // Colors: where the palette comes from, the wallpaper's colours or the current HyDE theme's.
    Component {
        id: colorsIcon

        Glyph {
            kind: "wallpaper"
            size: 18
            color: tile.iconColor
        }
    }
}
