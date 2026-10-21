import QtQuick
import Quickshell
import qs.island.config
import qs.island.core
import qs.island.icons
import qs.island.services
import qs.island.theme

// Status icons, right-aligned: the right zone of the expanded island and the status pill at the
// screen's right edge (StatusPillConfig.icons). Ids: "volume", "bluetooth", "wifi", "battery",
// "caffeine" (dim when off, accent when on), "notifications" (bell with the unread count; crossed
// out in peace mode), "power" (the power menu), "ai" (AI usage: the symbol, coloured by the tool
// closest to its limit; a click shows the numbers), "updates" (only while updates wait, with their
// number; a click opens the update in a terminal). With `extras`, shortcut buttons fill the free space on their left.
// Every icon is a button; resting the pointer on one shows what it does. Actions and hints:
// services/Shortcuts.qml.
Item {
    id: root

    // Width assigned by ExpandedView (the content hugs the right edge inside it).
    property int zoneWidth: implicitWidth
    // Icons to show, in order.
    property var icons: Expanded.statusIcons
    // Battery percentage, drawn inside the battery icon.
    property bool batteryPercent: true
    // Time left next to the battery icon: until empty on battery, until full while charging.
    property bool batteryTime: false
    // Keep the bell visible with no unread notifications (it opens the notification center).
    property bool alwaysShowBell: true
    // Shortcut buttons (Expanded.extraButtons) shown left of the status icons, as many as fit in
    // the free part of zoneWidth. They never widen the zone. [] = none (the status pill).
    property var extras: []
    readonly property real extraCell: iconSize + 2 * cellPadding + row.spacing
    readonly property int extrasFit: Math.max(0, Math.min(extras.length, Math.floor((zoneWidth - row.implicitWidth) / extraCell)))

    // Nerd Font glyphs for the shortcuts that have no drawn icon.
    readonly property var extraGlyphs: ({
            screenshot: "\u{F0E09}",
            clipboard: "\u{F0192}",
            picker: "\u{F020A}",
            wallpaper: "\u{F0E51}",
            theme: "\u{F03D8}",
            settings: "\u{F0493}",
            system: "\u{F061A}",
            nextwallpaper: "\u{F04AD}",
            hydetheme: "\u{F08B5}",
            keybindings: "\u{F030C}"
        })

    // Hint under the hovered icon, drawn by the island's window (IslandController.hint).
    function setHint(on, id, item) {
        if (on) {
            IslandController.hintScreen = QsWindow.window?.screen?.name ?? "";
            IslandController.hintAt = item.mapToItem(null, item.width / 2, item.height);
            IslandController.hint = id;
        } else if (IslandController.hint === id && !IslandController.hintPinned) {
            IslandController.hint = "";
        }
    }

    // "3h 12m" / "45m" from seconds; "" while UPower has no estimate.
    function duration(seconds) {
        const m = Math.round(seconds / 60);
        if (!(m > 0))
            return "";
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${String(m % 60).padStart(2, "0")}m` : `${m}m`;
    }
    readonly property string batteryText: batteryTime ? duration(Battery.charging ? Battery.timeToFull : Battery.plugged ? 0 : Battery.timeToEmpty) : ""

    readonly property real iconSize: Math.round(Pill.height * Expanded.statusIconFactor)
    // Padding around each icon button (its hover highlight), in pixels.
    readonly property int cellPadding: 3

    width: zoneWidth
    implicitWidth: row.implicitWidth
    implicitHeight: Pill.height

    // Icon id → component.
    readonly property var iconComponents: ({
            volume: volumeIcon,
            bluetooth: bluetoothIcon,
            wifi: wifiIcon,
            battery: batteryIcon,
            caffeine: caffeineIcon,
            notifications: notificationsIcon,
            power: powerIcon,
            ai: aiIcon,
            weather: weatherIcon,
            updates: updatesIcon,
            clock: clockIcon,
            date: dateIcon,
            mic: micIcon,
            brightness: brightnessIcon,
            media: mediaIcon
        })

    // The built-in icon of `id`, or a plugin's, or null when nothing provides it.
    function componentFor(id) {
        return root.iconComponents[id] ?? Plugins.icon(id);
    }

    // Icons that only show when they have something to say (a hidden icon takes no space in the row).
    function available(id) {
        if (Plugins.has(id))
            return Plugins.available(id);
        if (id === "notifications")
            return alwaysShowBell || Notifications.count > 0 || Notifications.peaceMode;
        if (id === "ai")
            return AiUsage.available;
        if (id === "weather")
            return Weather.available;
        if (id === "updates")
            return Updates.count > 0;
        if (id === "mic")
            return Audio.source !== null;
        if (id === "brightness")
            return Brightness.available;
        if (id === "media")
            return Media.active;
        return id === "bluetooth" ? Bluetooth.available : id === "battery" ? Battery.available : true;
    }

    // Shortcut buttons, right-aligned against the status icons.
    Row {
        anchors.right: row.left
        // Same gap as between two icons inside a row (the buttons carry their own padding).
        anchors.rightMargin: root.extrasFit > 0 ? row.spacing : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: row.spacing

        Repeater {
            model: root.extras.slice(0, root.extrasFit)

            Item {
                id: extra

                required property string modelData
                readonly property bool on: modelData === "nightlight" && NightLight.active

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.iconSize + 2 * root.cellPadding
                implicitHeight: root.iconSize + 2 * root.cellPadding

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: extraMouse.pressed ? Theme.pressed : extraMouse.containsMouse ? Theme.hover : "transparent"
                }

                MoonIcon {
                    visible: extra.modelData === "nightlight"
                    anchors.centerIn: parent
                    size: root.iconSize
                    color: extra.on ? Theme.accent : Theme.icon
                }
                PowerIcon {
                    visible: extra.modelData === "power"
                    anchors.centerIn: parent
                    size: root.iconSize
                    color: Theme.icon
                }
                Glyph {
                    visible: extra.modelData === "lock"
                    anchors.centerIn: parent
                    kind: "lock"
                    size: root.iconSize
                    color: Theme.icon
                }
                Label {
                    visible: root.extraGlyphs[extra.modelData] !== undefined
                    anchors.centerIn: parent
                    text: root.extraGlyphs[extra.modelData] ?? ""
                    font.family: Appearance.nerdFont
                    font.pixelSize: Math.round(root.iconSize * 0.95)
                    elide: Text.ElideNone
                    color: Theme.icon
                }

                MouseArea {
                    id: extraMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.RightButton) {
                            if (Menus.has(extra.modelData))
                                IslandController.openMenu(extra.modelData, extra, QsWindow.window?.screen?.name ?? "");
                        } else {
                            Shortcuts.run(extra.modelData);
                        }
                    }
                    onContainsMouseChanged: root.setHint(containsMouse, extra.modelData, extra)
                }
            }
        }
    }

    Row {
        id: row
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // Each button has its own padding (for the hover highlight), taken off the spacing.
        spacing: Math.max(0, Expanded.statusSpacing - 2 * root.cellPadding)

        Repeater {
            // A plugin's icon is as good as a built-in one; services/Plugins.qml answers for the
            // ids this file has never heard of.
            model: root.icons.filter(i => root.componentFor(i) !== null)

            Item {
                id: cell

                required property string modelData

                anchors.verticalCenter: parent.verticalCenter
                visible: root.available(modelData)
                implicitWidth: icon.implicitWidth + 2 * root.cellPadding
                implicitHeight: Math.max(icon.implicitHeight, root.iconSize) + 2 * root.cellPadding

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : "transparent"
                }

                Loader {
                    id: icon
                    anchors.centerIn: parent
                    sourceComponent: root.componentFor(cell.modelData)
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.RightButton && Menus.has(cell.modelData))
                            IslandController.openMenu(cell.modelData, cell, QsWindow.window?.screen?.name ?? "");
                        else if (event.button !== Qt.RightButton)
                            Shortcuts.status(cell.modelData, event.button);
                    }
                    onContainsMouseChanged: root.setHint(containsMouse, cell.modelData, cell)
                    onWheel: event => {
                        if (cell.modelData === "brightness") {
                            if (event.angleDelta.y > 0)
                                Brightness.up();
                            else
                                Brightness.down();
                        } else if (cell.modelData === "volume") {
                            const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
                            Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + step)));
                        }
                    }
                }
            }
        }
    }

    Component {
        id: volumeIcon

        VolumeIcon {
            size: root.iconSize
            color: Theme.icon
            level: Audio.volume
            muted: Audio.muted
        }
    }

    Component {
        id: bluetoothIcon

        BluetoothIcon {
            size: root.iconSize
            color: Bluetooth.enabled ? Theme.icon : Theme.dim
            enabled: Bluetooth.enabled
            connected: Bluetooth.connected
        }
    }

    // Network: the ethernet icon while a cable is connected (it takes priority), otherwise Wi‑Fi.
    Component {
        id: wifiIcon

        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize

            EthernetIcon {
                anchors.centerIn: parent
                visible: Network.wired
                size: root.iconSize
                color: Theme.icon
            }

            WifiIcon {
                anchors.centerIn: parent
                visible: !Network.wired
                size: root.iconSize
                color: Network.connected ? Theme.icon : Theme.dim
                level: Network.level
                enabled: Network.wifiEnabled
                connected: Network.connected
            }
        }
    }

    // Battery (percentage inside it, if batteryPercent), then the time left (batteryTime; red when
    // low and not charging).
    Component {
        id: batteryIcon

        Row {
            spacing: 4

            BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: root.iconSize
                color: Theme.icon
                present: Battery.available
                percent: Battery.percent
                charging: Battery.charging
                showPercent: root.batteryPercent
            }

            Label {
                visible: root.batteryText !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.batteryText
                font.pixelSize: Appearance.fontSize - 1
                color: Battery.percent <= 15 && !Battery.charging ? Theme.danger : Theme.foreground
            }
        }
    }

    // Power menu (log out, suspend, restart, shut down): always at hand, right of the battery.
    Component {
        id: powerIcon

        PowerIcon {
            size: root.iconSize
            color: Theme.icon
        }
    }

    // Caffeine: while on, the session never goes idle (also the control center tile and
    // `island ipc caffeine`). Always shown: dim when off, accent colour when on.
    Component {
        id: caffeineIcon

        Glyph {
            kind: "coffee"
            size: root.iconSize
            color: Caffeine.active ? Theme.accent : Theme.dim
        }
    }

    // AI usage (services/AiUsage.qml): only the symbol; red near a limit, accent colour half way.
    Component {
        id: aiIcon

        Label {
            text: "\u{F06A9}"
            font.family: Appearance.nerdFont
            font.pixelSize: Math.round(root.iconSize * 0.95)
            elide: Text.ElideNone
            color: AiUsage.worst === "high" ? Theme.danger : AiUsage.worst === "mid" ? Theme.accent : Theme.icon
        }
    }

    // Weather (services/Weather.qml): the sky's own symbol, and the temperature next to it.
    // The time and the date as plain text (the expanded island's own are fixed in its middle); they open the
    // calendar.
    Component {
        id: clockIcon

        Label {
            text: Time.time
            font.pixelSize: Appearance.fontSize
            color: Theme.foreground
        }
    }

    Component {
        id: dateIcon

        Label {
            text: Time.date
            font.pixelSize: Appearance.fontSize - 1
            color: Theme.foreground
        }
    }

    // Microphone: dim and crossed out while muted.
    Component {
        id: micIcon

        Label {
            // The same size as `iconSize` above, worked out here because a Component cannot name `root`
            // without qmllint counting it.
            readonly property real iconSize: Math.round(Pill.height * Expanded.statusIconFactor)

            text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
            font.family: Appearance.nerdFont
            font.pixelSize: Math.round(iconSize * 0.95)
            elide: Text.ElideNone
            color: Audio.micMuted ? Theme.dim : Theme.icon
        }
    }

    // Screen brightness: the sun and the percentage; the wheel changes it.
    Component {
        id: brightnessIcon

        Row {
            readonly property real iconSize: Math.round(Pill.height * Expanded.statusIconFactor)

            spacing: 4

            BrightnessIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: parent.iconSize
                color: Theme.icon
                level: Brightness.percent / 100
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Brightness.percent}%`
                font.pixelSize: Appearance.fontSize - 1
                color: Theme.foreground
            }
        }
    }

    // What plays: a play/pause button and the title (shortened); a click pauses or resumes, middle click skips.
    Component {
        id: mediaIcon

        Row {
            readonly property real iconSize: Math.round(Pill.height * Expanded.statusIconFactor)

            spacing: 5

            MediaIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: parent.iconSize
                color: Theme.icon
                kind: Media.playing ? "pause" : "play"
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 150)
                text: Media.title
                elide: Text.ElideRight
                font.pixelSize: Appearance.fontSize - 1
                color: Theme.foreground
            }
        }
    }

    Component {
        id: weatherIcon

        Row {
            spacing: 3

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.current ? Weather.glyph(Weather.current.code, Weather.current.isDay) : "\u{F0590}"
                font.family: Appearance.nerdFont
                font.pixelSize: Math.round(root.iconSize * 0.95)
                elide: Text.ElideNone
                color: Theme.icon
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: WeatherConfig.showTemperatureInBar && Weather.current
                text: Weather.current ? `${Math.round(Weather.current.temp)}°` : ""
                // Same rule as the counts beside the updates and notification icons: a number next
                // to an icon follows the text size, not the icon size, so the two stay in step when
                // either is changed.
                font.pixelSize: Appearance.fontSize - 1
                elide: Text.ElideNone
                color: Theme.icon
            }
        }
    }

    // Updates waiting (services/Updates.qml): package symbol and their number.
    Component {
        id: updatesIcon

        Row {
            spacing: 3

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0BAF}"
                font.family: Appearance.nerdFont
                font.pixelSize: Math.round(root.iconSize * 0.95)
                elide: Text.ElideNone
                color: Updates.updating ? Theme.accent : Theme.icon
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: String(Updates.count)
                font.pixelSize: Appearance.fontSize - 1
            }
        }
    }

    // Unread notifications (bell + count), or peace mode (crossed-out bell).
    Component {
        id: notificationsIcon

        Row {
            spacing: 3

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                kind: Notifications.peaceMode ? "bellOff" : "bell"
                size: root.iconSize
                color: Theme.icon
            }

            Label {
                visible: Notifications.count > 0
                anchors.verticalCenter: parent.verticalCenter
                text: String(Notifications.count)
                font.pixelSize: Appearance.fontSize - 1
            }
        }
    }
}
