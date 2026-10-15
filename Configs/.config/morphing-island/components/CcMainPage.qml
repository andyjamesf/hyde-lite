import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.core
import qs.icons
import qs.services
import qs.theme

// Main page of the control center: header (your picture and name, time since boot, battery,
// settings, lock, power), quick-toggle tiles (ControlCenter.tiles), volume, microphone and
// brightness sliders, a media row, HyDE shortcuts (ControlCenter.shortcuts) and, at the bottom, the
// notification history. The height grows with the history (up to maxRows rows, and never past the
// bottom of the island's window: the rows that don't fit scroll).
Item {
    id: root

    // True while this is the page on screen with the control center open.
    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int gap: ControlCenter.spacing
    readonly property int notifRowHeight: ControlCenter.notificationRowHeight
    readonly property int maxRows: ControlCenter.maxNotificationRows
    readonly property int notifCount: Notifications.count
    // Rows that fit under everything above the list inside the island's window (its height is
    // capped by the screen): the list scrolls past them.
    readonly property int windowHeight: QsWindow.window?.height ?? 760
    readonly property int fitRows: Math.max(1, Math.floor((windowHeight - Pill.topMargin - 12 - 2 * pad - notifList.y) / notifRowHeight))
    readonly property int visibleRows: Math.min(notifCount, maxRows, fitRows)

    readonly property string outputName: (Audio.sinks ?? []).find(s => s.isDefault)?.name ?? ""

    implicitWidth: ControlCenter.width
    implicitHeight: column.implicitHeight + 2 * pad

    // Hint under a hovered header or shortcut button (text: Shortcuts.hint).
    function hint(on, id, item) {
        if (on) {
            IslandController.hintScreen = QsWindow.window?.screen?.name ?? "";
            IslandController.hintAt = item.mapToItem(null, item.width / 2, item.height);
            IslandController.hint = id;
        } else if (IslandController.hint === id) {
            IslandController.hint = "";
        }
    }

    // Right-click menu of a tile or button, under it.
    function menu(id, item) {
        if (Menus.has(id))
            IslandController.openMenu(id, item, QsWindow.window?.screen?.name ?? "");
    }

    // Switches pages inside the control center, on the same screen.
    function go(p) {
        IslandController.mode = p;
    }

    // "now", "5m", "2h", "3d" (Time.now ticks every second, which is plenty for this).
    function ago(d) {
        const s = Math.max(0, (Time.now.getTime() - new Date(d).getTime()) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    Column {
        id: column
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.gap

        // Header: your picture (click: choose another), name and time since boot on the left; battery
        // (click: battery page), settings, lock and power on the right.
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
                color: Theme.surface
                border.width: 1
                border.color: avatarMouse.containsMouse ? Theme.accent : Theme.border

                Label {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: SysInfo.user.charAt(0).toUpperCase()
                    color: Theme.accent
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
                        source: `file://${SysInfo.avatar}?v=${SysInfo.avatarVersion}`
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
                    onClicked: SysInfo.chooseAvatar()
                    onContainsMouseChanged: root.hint(containsMouse, "avatar", avatarFrame)
                }
            }

            Column {
                anchors.left: avatarFrame.right
                anchors.leftMargin: 10
                anchors.right: headerButtons.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: SysInfo.user
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    text: `Up for ${SysInfo.uptime}`
                    color: Theme.dim
                    font.pixelSize: Appearance.fontSize - 2
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
                    color: batteryMouse.pressed ? Theme.pressed : batteryMouse.containsMouse ? Theme.hover : "transparent"

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 6

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${Math.round(Battery.percent)}%`
                            color: Theme.dim
                            font.pixelSize: Appearance.fontSize - 1
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
                        onClicked: event => event.button === Qt.RightButton ? root.menu("battery", batteryButton) : root.go(IslandState.battery)
                        onContainsMouseChanged: root.hint(containsMouse, "batterypage", batteryButton)
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

                    IconButton {
                        id: headerButton
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        size: 32
                        onClicked: Shortcuts.run(modelData.id)
                        rightClickable: Menus.has(modelData.id)
                        onRightClicked: root.menu(modelData.id, headerButton)
                        onHoveredChanged: root.hint(hovered, modelData.id, headerButton)

                        Label {
                            text: headerButton.modelData.glyph
                            font.family: Appearance.nerdFont
                            font.pixelSize: 17
                            elide: Text.ElideNone
                            color: Theme.icon
                        }
                    }
                }
            }
        }

        // Tiles: two columns, in the order of ControlCenter.tiles; an odd last tile takes the whole row.
        Flow {
            id: tiles
            width: parent.width
            spacing: 10

            readonly property real half: (width - spacing) / 2
            readonly property var ids: ControlCenter.tiles.filter(t => root.tileComponents[t] !== undefined)

            Repeater {
                model: tiles.ids

                Loader {
                    required property string modelData
                    required property int index

                    id: tileLoader
                    width: index === tiles.ids.length - 1 && index % 2 === 0 ? tiles.width : tiles.half
                    sourceComponent: root.tileComponents[modelData]

                    // Right click: the tile's menu (services/Menus.qml).
                    Connections {
                        target: tileLoader.item
                        ignoreUnknownSignals: true
                        function onMenuRequested() {
                            root.menu(tileLoader.modelData, tileLoader.item);
                        }
                    }
                }
            }
        }

        // Sliders
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

                Label {
                    text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
                    font.family: Appearance.nerdFont
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
                // Every change is a process (brightnessctl): at most one per ControlCenter.sliderThrottleMs.
                throttle: ControlCenter.sliderThrottleMs
                onMoved: v => Brightness.set(v * 100)

                BrightnessIcon {
                    size: 16
                    color: brightnessSlider.iconColor
                    level: Brightness.percent / 100
                }
            }
        }

        // Media: compact row that opens the player subview.
        Rectangle {
            id: mediaRow
            width: parent.width
            height: 56
            visible: Media.active
            radius: 18
            color: mediaMouse.pressed ? Theme.pressed : mediaMouse.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.04)
            border.width: 1
            border.color: Theme.border

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(120)
                }
            }

            MouseArea {
                id: mediaMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(IslandState.media)
            }

            // Cover with rounded corners (mask); without a cover, a tinted square.
            Item {
                id: art
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40

                readonly property bool hasCover: cover.status === Image.Ready

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: Qt.alpha(Theme.accent, 0.22)
                    visible: !art.hasCover

                    MediaIcon {
                        anchors.centerIn: parent
                        kind: "play"
                        size: 16
                        color: Theme.accent
                    }
                }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.artUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 80
                    sourceSize.height: 80
                    asynchronous: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: parent
                    source: cover
                    visible: art.hasCover
                    maskEnabled: true
                    maskSource: artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Item {
                    id: artMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "black"
                    }
                }
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 12
                anchors.right: playButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                    width: parent.width
                    text: Media.title || Media.identity || "Unknown"
                    textFormat: Text.PlainText
                    font.weight: Font.Medium
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: Media.artist
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font.pixelSize: Appearance.fontSize - 2
                }
            }

            IconButton {
                id: playButton
                anchors.right: mediaChevron.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                onClicked: Media.togglePlaying()

                MediaIcon {
                    kind: Media.playing ? "pause" : "play"
                    size: 16
                    color: Theme.icon
                }
            }

            Glyph {
                id: mediaChevron
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                kind: "chevron"
                size: 14
                color: mediaMouse.containsMouse ? Theme.foreground : Theme.faint
            }
        }

        // HyDE shortcuts (ControlCenter.shortcuts): icon buttons spread over the width; the pointer
        // on one shows what it does.
        Row {
            id: shortcutRow
            width: parent.width
            visible: ControlCenter.shortcuts.length > 0

            readonly property var glyphs: ({
                    nextwallpaper: "\u{F04AD}",
                    wallpaper: "\u{F02E9}",
                    hydetheme: "\u{F03D8}",
                    animations: "\u{F05D8}",
                    keybindings: "\u{F030C}"
                })

            Repeater {
                model: ControlCenter.shortcuts.filter(id => shortcutRow.glyphs[id] !== undefined)

                Item {
                    id: shortcutCell
                    required property string modelData
                    width: shortcutRow.width / Math.max(1, ControlCenter.shortcuts.length)
                    height: 40

                    Rectangle {
                        anchors.centerIn: parent
                        width: 44
                        height: 36
                        radius: 18
                        color: shortcutMouse.pressed ? Theme.pressed : shortcutMouse.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.04)
                        border.width: 1
                        border.color: Theme.border

                        Label {
                            anchors.centerIn: parent
                            text: shortcutRow.glyphs[shortcutCell.modelData]
                            font.family: Appearance.nerdFont
                            font.pixelSize: 18
                            elide: Text.ElideNone
                            color: Theme.icon
                        }
                        MouseArea {
                            id: shortcutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: event => event.button === Qt.RightButton ? root.menu(shortcutCell.modelData, parent) : Shortcuts.run(shortcutCell.modelData)
                            onContainsMouseChanged: root.hint(containsMouse, shortcutCell.modelData, parent)
                        }
                    }
                }
            }
        }

        // Notifications: header + "Clear All".
        Item {
            width: parent.width
            height: 26

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: root.notifCount > 0 ? `Notifications  ·  ${root.notifCount}` : "Notifications"
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 1
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + 20
                height: 24
                radius: height / 2
                visible: root.notifCount > 0
                color: clearMouse.pressed ? Theme.pressed : clearMouse.containsMouse ? Theme.hover : "transparent"

                Label {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear All"
                    color: clearMouse.containsMouse ? Theme.foreground : Theme.dim
                    font.pixelSize: Appearance.fontSize - 1
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.clear()
                }
            }
        }

        // No notifications
        Column {
            width: parent.width
            visible: root.notifCount === 0
            topPadding: 4
            bottomPadding: 8
            spacing: 2

            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "No notifications"
                color: Theme.faint
            }

            Label {
                width: parent.width
                visible: Notifications.peaceMode
                horizontalAlignment: Text.AlignHCenter
                text: "Peace Mode is on"
                color: Theme.faint
                font.pixelSize: Appearance.fontSize - 2
            }
        }

        ListView {
            id: notifList
            width: parent.width
            height: root.visibleRows * root.notifRowHeight
            visible: root.notifCount > 0
            clip: true
            interactive: root.notifCount > root.visibleRows
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: Notifications.list
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Animations.duration(140)
                }
            }
            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Animations.duration(180)
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Animations.duration(180)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Animations.duration(120)
                }
            }

            delegate: Item {
                id: notifRow

                required property var modelData
                readonly property var n: modelData

                width: ListView.view.width
                height: root.notifRowHeight

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismiss(notifRow.n)
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 14
                    color: rowMouse.pressed ? Theme.pressed : rowMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Animations.duration(120)
                        }
                    }
                }

                // App icon (or its initial, if there is none).
                Item {
                    id: lead
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28

                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        source: Notifications.imageOf(notifRow.n)
                        visible: status === Image.Ready
                        asynchronous: true
                        mipmap: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: appIcon.status !== Image.Ready
                        radius: width / 2
                        color: Qt.alpha(Theme.accent, 0.18)

                        Label {
                            anchors.centerIn: parent
                            text: (notifRow.n?.appName || "?").charAt(0).toUpperCase()
                            color: Theme.accent
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Column {
                    anchors.left: lead.right
                    anchors.leftMargin: 10
                    anchors.right: trail.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Label {
                        width: parent.width
                        text: notifRow.n?.summary || notifRow.n?.appName || ""
                        textFormat: Text.PlainText
                        font.pixelSize: Appearance.fontSize - 1
                        font.weight: Font.Medium
                    }

                    Label {
                        width: parent.width
                        text: notifRow.n?.appName || "Notification"
                        textFormat: Text.PlainText
                        color: Theme.dim
                        font.pixelSize: Appearance.fontSize - 3
                    }
                }

                // Relative time; with the pointer over it, a "×" (clicking dismisses).
                Item {
                    id: trail
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(timeLabel.implicitWidth, 16)
                    height: 20

                    Label {
                        id: timeLabel
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !rowMouse.containsMouse
                        text: root.ago(Notifications.timeOf(notifRow.n))
                        color: Theme.faint
                        font.pixelSize: Appearance.fontSize - 2
                    }

                    Glyph {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowMouse.containsMouse
                        kind: "close"
                        size: 14
                        color: Theme.dim
                    }
                }
            }
        }
    }

    // Tile id → component (see ControlCenter.tiles).
    readonly property var tileComponents: ({
            wifi: wifiTileComponent,
            bluetooth: btTileComponent,
            sound: soundTileComponent,
            peace: peaceTileComponent,
            nightlight: nightTileComponent,
            caffeine: caffeineTileComponent,
            mic: micTileComponent,
            profile: profileTileComponent
        })

    Component {
        id: wifiTileComponent

        CcTile {
            id: wifiTile
            width: parent?.width ?? 0
            title: "Wi‑Fi"
            status: !Network.wifiEnabled ? (Network.wired ? "Ethernet" : "Off") : Network.connected ? Network.name : "Not connected"
            active: Network.wifiEnabled
            expandable: true
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            onOpened: root.go(IslandState.wifi)

            WifiIcon {
                size: 18
                color: wifiTile.iconColor
                level: Network.wired ? 4 : Network.level
                enabled: Network.wifiEnabled || Network.wired
                connected: Network.connected
            }
        }
    }

    Component {
        id: btTileComponent

        CcTile {
            id: btTile
            width: parent?.width ?? 0
            title: "Bluetooth"
            status: Bluetooth.summary
            active: Bluetooth.enabled
            enabled: Bluetooth.available
            expandable: true
            onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
            onOpened: root.go(IslandState.bluetooth)

            BluetoothIcon {
                size: 18
                color: btTile.iconColor
                enabled: Bluetooth.enabled
                connected: Bluetooth.connected
            }
        }
    }

    Component {
        id: soundTileComponent

        CcTile {
            id: audioTile
            width: parent?.width ?? 0
            title: "Sound"
            status: Audio.muted ? "Muted" : root.outputName || `${Math.round(Audio.volume * 100)}%`
            active: !Audio.muted
            expandable: true
            onToggled: Audio.toggleMute()
            onOpened: root.go(IslandState.audio)

            VolumeIcon {
                size: 18
                color: audioTile.iconColor
                level: Audio.volume
                muted: Audio.muted
            }
        }
    }

    Component {
        id: peaceTileComponent

        CcTile {
            id: peaceTile
            width: parent?.width ?? 0
            title: "Peace Mode"
            status: Notifications.peaceMode ? "On" : "Off"
            active: Notifications.peaceMode
            onToggled: Notifications.togglePeace()

            Glyph {
                kind: Notifications.peaceMode ? "bellOff" : "bell"
                size: 18
                color: peaceTile.iconColor
            }
        }
    }

    Component {
        id: nightTileComponent

        CcTile {
            id: nightTile
            width: parent?.width ?? 0
            title: "Night Light"
            status: !NightLight.available ? "Unavailable" : NightLight.active ? "On" : "Off"
            active: NightLight.active
            enabled: NightLight.available
            onToggled: NightLight.toggle()

            MoonIcon {
                size: 17
                color: nightTile.iconColor
            }
        }
    }

    Component {
        id: micTileComponent

        CcTile {
            id: micTile
            width: parent?.width ?? 0
            title: "Microphone"
            status: Audio.micMuted ? "Off" : `${Math.round(Audio.micVolume * 100)}%`
            active: !Audio.micMuted
            expandable: true
            onToggled: Audio.toggleMicMute()
            onOpened: root.go(IslandState.audio)

            Label {
                text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
                font.family: Appearance.nerdFont
                font.pixelSize: 18
                elide: Text.ElideNone
                color: micTile.iconColor
            }
        }
    }

    // Power profile: a click goes to the next one; the arrow opens the battery page with all three.
    Component {
        id: profileTileComponent

        CcTile {
            id: profileTile
            width: parent?.width ?? 0
            title: "Power Profile"
            status: Battery.profileName
            active: Battery.profile !== 1
            expandable: true
            onToggled: Battery.cycleProfile()
            onOpened: root.go(IslandState.battery)

            Label {
                text: ["\u{F032A}", "\u{F05D1}", "\u{F14DE}"][Battery.profile] ?? "\u{F05D1}"
                font.family: Appearance.nerdFont
                font.pixelSize: 18
                elide: Text.ElideNone
                color: profileTile.iconColor
            }
        }
    }

    // Caffeine: an idle inhibitor on the island window (no dimming, lock or suspend while on).
    Component {
        id: caffeineTileComponent

        CcTile {
            id: caffeineTile
            width: parent?.width ?? 0
            title: "Caffeine"
            status: Caffeine.active ? "Staying awake" : "Off"
            active: Caffeine.active
            onToggled: Caffeine.toggle()

            Glyph {
                kind: "coffee"
                size: 18
                color: caffeineTile.iconColor
            }
        }
    }
}
