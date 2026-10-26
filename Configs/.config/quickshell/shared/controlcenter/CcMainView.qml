import QtQuick
import Quickshell.Widgets
import qs.shared.icons
import qs.shared.services

// The main page of the control centre, drawn by every UI of this configuration: a header (your
// picture and name, time since boot, battery, system, settings, lock and power), the toggle tiles
// (CcToggles) in two columns, the volume, microphone and brightness sliders, the media row, the
// shortcut buttons (CcShortcuts) and the notification centre.
//
// It was the island's page. The bar had its own, with round buttons and a different order, and the
// owner wanted the island's in both shells, so it is shared: what each shell contributes is its look
// (CcTheme) and what a click leads to, as signals — the island opens its own pages and menus, the
// bar its panel's pages. The host puts it in a window and decides the width and the padding.
Column {
    id: root

    // Ids of the tiles and of the shortcut buttons to show, in order. A tile or a button whose
    // entry is not available (no Bluetooth adapter, a picker that is not registered) is left out.
    property var tiles: ["wifi", "bluetooth", "sound", "mic", "dnd", "nightlight", "caffeine", "powerProfile", "colors"]
    property var shortcuts: ["nextwallpaper", "wallpaper", "hydetheme", "animations", "keybindings", "syncshell"]

    // Notification rows visible before the list scrolls (the host lowers it on a short screen).
    property int visibleRows: Math.min(Notifications.count, 4)
    property int notificationRowHeight: 46

    // A detail page: "wifi", "bluetooth", "audio", "battery", "media".
    signal pageRequested(string page)
    // A header button: "avatar" (choose another picture), "system", "settings", "lock", "power".
    signal headerAction(string id)
    // Right click on a tile, a header button or a shortcut: the host may show a menu.
    signal menuRequested(string id, Item item)
    // The pointer is over (on) or left (off) a header button or a shortcut: the host may show a hint.
    signal hintRequested(bool on, string id, Item item)

    // Where the notification list starts, for a host that fits `visibleRows` to the room it has.
    readonly property real notificationsY: notifCentre.y + notifCentre.listY

    spacing: 12

    // Header: picture (click: choose another), name and time since boot on the left; battery
    // (click: battery page), system, settings, lock and power on the right.
    Item {
        width: parent.width
        height: 40

        Rectangle {
            id: avatarFrame
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: width / 2
            color: CcTheme.surface
            border.width: 1
            border.color: avatarMouse.containsMouse ? CcTheme.accent : CcTheme.border

            CcLabel {
                anchors.centerIn: parent
                visible: avatarImage.status !== Image.Ready
                text: SysInfo.user.charAt(0).toUpperCase()
                color: CcTheme.accent
                font.weight: Font.DemiBold
            }
            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: width / 2
                color: "transparent"
                visible: avatarImage.status === Image.Ready

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: SysInfo.avatarUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 80
                    sourceSize.height: 80
                    asynchronous: true
                    cache: false
                }
            }
            MouseArea {
                id: avatarMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.headerAction("avatar")
                onContainsMouseChanged: root.hintRequested(containsMouse, "avatar", avatarFrame)
            }
        }

        Column {
            anchors.left: avatarFrame.right
            anchors.leftMargin: 10
            anchors.right: headerButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            CcLabel {
                width: parent.width
                text: SysInfo.user
                font.weight: Font.DemiBold
            }
            CcLabel {
                width: parent.width
                text: `Up for ${SysInfo.uptime}`
                color: CcTheme.dim
                font.pixelSize: CcTheme.fontSize - 2
            }
        }

        Row {
            id: headerButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Battery: percentage and icon; opens the battery page (power profiles).
            Rectangle {
                id: batteryButton
                anchors.verticalCenter: parent.verticalCenter
                visible: Battery.available
                width: batteryRow.implicitWidth + 16
                height: 32
                radius: height / 2
                color: batteryMouse.pressed ? CcTheme.pressed : batteryMouse.containsMouse ? CcTheme.hover : "transparent"

                Row {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 6

                    CcLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(Battery.percent)}%`
                        color: CcTheme.dim
                        font.pixelSize: CcTheme.fontSize - 1
                    }
                    BatteryIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 20
                        showPercent: false
                        present: Battery.available
                        percent: Battery.percent
                        charging: Battery.charging
                    }
                }
                MouseArea {
                    id: batteryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => event.button === Qt.RightButton ? root.menuRequested("battery", batteryButton) : root.pageRequested("battery")
                    onContainsMouseChanged: root.hintRequested(containsMouse, "batterypage", batteryButton)
                }
            }

            Repeater {
                model: [
                    {
                        id: "system",
                        glyph: "\u{F061A}"
                    },
                    {
                        id: "settings",
                        glyph: "\u{F0493}"
                    },
                    {
                        id: "lock",
                        glyph: "\u{F033E}"
                    },
                    {
                        id: "power",
                        glyph: "\u{F0425}"
                    }
                ]

                CcIconButton {
                    id: headerButton
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    onClicked: root.headerAction(modelData.id)
                    rightClickable: true
                    onRightClicked: root.menuRequested(modelData.id, headerButton)
                    onHoveredChanged: root.hintRequested(hovered, modelData.id, headerButton)

                    CcLabel {
                        text: headerButton.modelData.glyph
                        font.family: CcTheme.nerdFont
                        font.pixelSize: 17
                        elide: Text.ElideNone
                        color: CcTheme.icon
                    }
                }
            }
        }
    }

    // Tiles: two columns; an odd last tile takes the whole row.
    Flow {
        id: tileFlow
        width: parent.width
        spacing: 10

        readonly property real half: (width - spacing) / 2
        // What is offered is CcToggles', in the order and with the tiles the host asks for; what is
        // not available is left out.
        readonly property var ids: root.tiles.filter(t => CcToggles.shown.some(x => x.id === t))

        Repeater {
            model: tileFlow.ids

            CcToggleTile {
                required property string modelData
                required property int index

                toggleId: modelData
                width: index === tileFlow.ids.length - 1 && index % 2 === 0 ? tileFlow.width : tileFlow.half
                onPageRequested: page => root.pageRequested(page)
                onMenuRequested: root.menuRequested(modelData, this)
            }
        }
    }

    // Sliders.
    Column {
        width: parent.width
        spacing: 10

        BigSlider {
            id: volumeSlider
            width: parent.width
            value: Audio.volume
            muted: Audio.muted
            label: Audio.muted ? "Muted" : `${Math.round(Audio.volume * 100)}%`
            iconClickable: true
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()

            VolumeIcon {
                size: 16
                color: volumeSlider.iconColor
                level: Audio.volume
                muted: Audio.muted
            }
        }

        BigSlider {
            id: micSlider
            width: parent.width
            visible: Audio.source !== null && Audio.source !== undefined
            value: Audio.micVolume
            muted: Audio.micMuted
            label: Audio.micMuted ? "Mic off" : `${Math.round(Audio.micVolume * 100)}%`
            iconClickable: true
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()

            CcLabel {
                text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
                font.family: CcTheme.nerdFont
                font.pixelSize: 16
                elide: Text.ElideNone
                color: micSlider.iconColor
            }
        }

        BigSlider {
            id: brightnessSlider
            width: parent.width
            visible: Brightness.available
            value: Brightness.percent / 100
            label: `${Brightness.percent}%`
            // Every change is a process (brightnessctl): at most one per CcTheme.sliderThrottleMs.
            throttle: CcTheme.sliderThrottleMs
            onMoved: v => Brightness.set(v * 100)

            BrightnessIcon {
                size: 16
                color: brightnessSlider.iconColor
                level: Brightness.percent / 100
            }
        }
    }

    CcMediaRow {
        width: parent.width
        onPageRequested: root.pageRequested("media")
    }

    // Shortcuts: icon buttons spread over the width; the pointer on one shows what it does.
    Row {
        id: shortcutRow
        width: parent.width

        readonly property var ids: root.shortcuts.filter(id => CcShortcuts.shown.some(x => x.id === id))
        visible: ids.length > 0

        Repeater {
            model: shortcutRow.ids

            Item {
                id: shortcutCell
                required property string modelData
                width: shortcutRow.width / Math.max(1, shortcutRow.ids.length)
                height: 40

                Rectangle {
                    anchors.centerIn: parent
                    width: 44
                    height: 36
                    radius: 18
                    color: shortcutMouse.pressed ? CcTheme.pressed : shortcutMouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.04)
                    border.width: 1
                    border.color: CcTheme.border

                    CcLabel {
                        anchors.centerIn: parent
                        text: CcShortcuts.get(shortcutCell.modelData)?.glyph ?? ""
                        font.family: CcTheme.nerdFont
                        font.pixelSize: 18
                        elide: Text.ElideNone
                        color: CcTheme.icon
                    }
                    MouseArea {
                        id: shortcutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => event.button === Qt.RightButton ? root.menuRequested(shortcutCell.modelData, parent) : CcShortcuts.run(shortcutCell.modelData)
                        onContainsMouseChanged: root.hintRequested(containsMouse, shortcutCell.modelData, parent)
                    }
                }
            }
        }
    }

    NotificationCentre {
        id: notifCentre
        width: parent.width
        rowHeight: root.notificationRowHeight
        visibleRows: root.visibleRows
    }
}
