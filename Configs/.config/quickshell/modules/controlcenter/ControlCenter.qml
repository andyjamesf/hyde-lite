import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.components
import qs.services
import qs.modules.controls
import qs.modules.notifications

// Control center: side panel with quick toggles, sliders, media, HyDE shortcuts and
// detail pages (Wi-Fi, Bluetooth, sound). Opens on the focused screen; closes with Esc or
// an outside click. `qs ipc call controlcenter toggle`.
PanelWindow {
    id: panel

    required property ShellScreen modelData
    readonly property bool open: ShellState.controlCenterOpen && (ShellState.controlCenterScreen === "" || ShellState.controlCenterScreen === modelData.name)
    // 0 = open, 1 = closed (off screen).
    property real slide: open ? 0 : 1

    Behavior on slide {
        NumberAnim {
            duration: Anim.normal
            easing.bezierCurve: panel.open ? Anim.emphasized : Anim.standardAccel
        }
    }

    // The window always stays created (creating a layer surface on every open delayed the panel);
    // when closed it shows no content and the empty mask lets clicks through.
    screen: modelData
    visible: true
    mask: Region {
        item: panel.open || panel.slide < 1 ? bg : null
    }
    anchors {
        top: BarLayout.atTop
        bottom: !BarLayout.atTop
        right: true
    }
    margins {
        top: BarLayout.atTop ? 6 : 0
        bottom: BarLayout.atTop ? 0 : 6
        right: 6
    }
    implicitWidth: 360
    implicitHeight: Math.min(content.implicitHeight + 2 * Theme.space5, modelData.height - BarLayout.height - BarLayout.margin - Theme.space6)
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell:controlcenter"
    WlrLayershell.layer: WlrLayer.Top
    // Keyboard only on demand: for typing the Wi-Fi password and for Esc.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Always opens at the top (the Flickable kept the position from last time).
    onOpenChanged: if (open) {
        flick.contentY = 0;
        SysInfo.refresh();
        NightLight.refresh();
    }

    Connections {
        target: ShellState
        function onControlCenterPageChanged() {
            flick.contentY = 0;
        }
    }

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: ShellState.closeControlCenter()
    }

    Rectangle {
        id: bg

        width: parent.width
        height: parent.height
        x: panel.slide * (panel.width + Theme.space3)
        opacity: 1 - panel.slide * 0.6
        radius: Theme.shapeXL
        color: Theme.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.border
        focus: panel.open
        Keys.onEscapePressed: ShellState.controlCenterPage !== "" ? ShellState.controlCenterPage = "" : ShellState.closeControlCenter()

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.space5
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: parent.width
                spacing: Theme.space5

                Loader {
                    id: page
                    Layout.fillWidth: true
                    sourceComponent: ({
                            "wifi": wifiPage,
                            "bluetooth": bluetoothPage,
                            "audio": audioPage,
                            "notifications": notificationsPage
                        })[ShellState.controlCenterPage] ?? mainPage

                    // Page change: shared axis (the new content slides in from the side
                    // being navigated to, with a fade).
                    onLoaded: {
                        item.opacity = 0;
                        item.x = ShellState.controlCenterPage === "" ? -Theme.space6 : Theme.space6;
                        pageIn.restart();
                    }

                    ParallelAnimation {
                        id: pageIn
                        NumberAnimation {
                            target: page.item
                            property: "opacity"
                            to: 1
                            duration: Anim.enter
                        }
                        NumberAnimation {
                            target: page.item
                            property: "x"
                            to: 0
                            duration: Anim.enter
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.emphasized
                        }
                    }
                }
            }
        }
    }

    component Header: RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        ClippingRectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: height / 2
            color: Theme.primaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                icon: "person"
                size: 22
                fill: 1
                color: Theme.onPrimaryContainer
            }

            Image {
                id: avatar
                anchors.fill: parent
                source: SysInfo.avatar
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 80
                sourceSize.height: 80
                cache: false
            }

            // Click the picture: choose another one.
            StateLayer {
                anchors.fill: parent
                onClicked: {
                    ShellState.closeControlCenter();
                    SysInfo.chooseAvatar();
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: SysInfo.user
                font.pixelSize: Theme.titleMedium
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                // Only hours once it is past one hour (the minutes didn't fit).
                text: `Up for ${SysInfo.uptime.replace(/^(\d+ h) \d+ min$/, "$1")}`
                font.pixelSize: Theme.bodySmall
                color: Theme.textDim
            }
        }

        Row {
            spacing: Theme.space2

            IconButton {
                icon: "settings"
                size: 40
                tonal: true
                tooltip: "Shell settings"
                onClicked: {
                    ShellState.closeControlCenter();
                    // The shell folder and config.json in a code editor (the first one that exists).
                    const dir = Quickshell.shellPath("");
                    const cfg = Quickshell.shellPath("config/config.json");
                    Utils.run(`for e in code codium zeditor; do command -v $e >/dev/null && exec $e "${dir}" "${cfg}"; done; exec kitty nvim "${cfg}"`);
                }
            }

            IconButton {
                icon: "lock"
                size: 40
                tonal: true
                tooltip: "Lock"
                onClicked: {
                    ShellState.closeControlCenter();
                    Utils.run("loginctl lock-session");
                }
            }

            IconButton {
                icon: "power_settings_new"
                size: 40
                background: Theme.alpha(Theme.error, 0.16)
                color: Theme.error
                tooltip: "Session"
                onClicked: ShellState.togglePowerMenu()
            }
        }
    }

    // Compact player: cover, title/artist and the controls on the right; progress at the bottom.
    component MediaStrip: Card {
        id: strip

        readonly property var player: Media.active

        padding: Theme.space3

        // MPRIS doesn't signal when the position advances; an update is requested every second.
        Timer {
            interval: 1000
            repeat: true
            running: strip.visible && Media.playing && panel.open
            onTriggered: strip.player?.positionChanged()
        }

        ColumnLayout {
            width: parent.width
            spacing: Theme.space3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                ClippingRectangle {
                    implicitWidth: 56
                    implicitHeight: 56
                    radius: Theme.shapeMedium
                    color: Theme.surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        icon: "music_note"
                        size: 26
                        fill: 1
                        color: Theme.primary
                    }

                    Image {
                        id: art
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 112
                        sourceSize.height: 112
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Media.title || "Untitled"
                        font.pixelSize: Theme.titleSmall
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Media.artist || (strip.player?.identity ?? "")
                        font.pixelSize: Theme.bodySmall
                        color: Theme.textDim
                    }
                }

                IconButton {
                    icon: "skip_previous"
                    size: 36
                    enabled: strip.player?.canGoPrevious ?? false
                    onClicked: Media.previous()
                }

                IconButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 40
                    checked: true
                    onClicked: Media.togglePlaying()
                }

                IconButton {
                    icon: "skip_next"
                    size: 36
                    enabled: strip.player?.canGoNext ?? false
                    onClicked: Media.next()
                }
            }

            Rectangle {
                visible: (strip.player?.lengthSupported ?? false) && strip.player.length > 0
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: strip.player && strip.player.length > 0 ? parent.width * Math.min(1, strip.player.position / strip.player.length) : 0
                    height: parent.height
                    radius: 2
                    color: Theme.primary
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -Theme.space2
                    anchors.bottomMargin: -Theme.space2
                    enabled: strip.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => strip.player.position = mouse.x / width * strip.player.length
                }
            }
        }
    }

    Component {
        id: wifiPage

        WifiPanel {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
            canType: true
        }
    }

    Component {
        id: bluetoothPage

        BluetoothPanel {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
        }
    }

    Component {
        id: notificationsPage

        NotificationList {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
        }
    }

    Component {
        id: audioPage

        AudioPanel {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
        }
    }

    Component {
        id: mainPage

        ColumnLayout {
            spacing: Theme.space4

            Header {}

            // Quick toggles: 4 per row. Click toggles; right click, press and hold
            // or the badge opens the detail page (Wi-Fi, Bluetooth).
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 0
                rowSpacing: Theme.space3

                QuickToggle {
                    Layout.fillWidth: true
                    icon: Network.wired ? "lan" : Network.icon
                    label: "Wi-Fi"
                    checked: Network.wifiEnabled
                    expandable: true
                    onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
                    onExpand: ShellState.controlCenterPage = "wifi"
                }

                QuickToggle {
                    Layout.fillWidth: true
                    visible: Bluetooth.available
                    icon: Bluetooth.icon
                    label: "Bluetooth"
                    checked: Bluetooth.enabled
                    expandable: true
                    onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                    onExpand: ShellState.controlCenterPage = "bluetooth"
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: Notifs.dnd ? "notifications_off" : "notifications"
                    label: "Silent"
                    checked: Notifs.dnd
                    onToggled: Notifs.toggleDnd()
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "nightlight"
                    label: "Night light"
                    checked: NightLight.active
                    onToggled: NightLight.toggle()
                }

                QuickToggle {
                    Layout.fillWidth: true
                    visible: Battery.available || PowerProfiles.profile !== undefined
                    icon: Battery.profileIcon
                    label: Battery.profileName
                    checked: Battery.profile !== 1
                    onToggled: Battery.setProfile((Battery.profile + 1) % (PowerProfiles.hasPerformanceProfile ? 3 : 2))
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "coffee"
                    label: "Caffeine"
                    checked: ShellState.idleInhibited
                    onToggled: ShellState.idleInhibited = !ShellState.idleInhibited
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: Audio.micIcon
                    label: "Microphone"
                    checked: !Audio.micMuted
                    expandable: true
                    onToggled: Audio.toggleMicMute()
                    onExpand: ShellState.controlCenterPage = "audio"
                }

                QuickToggle {
                    Layout.fillWidth: true
                    icon: "wallpaper"
                    label: "Colors"
                    checked: Prefs.colorSource === "wallpaper"
                    onToggled: Theme.setColorSource(Prefs.colorSource === "wallpaper" ? "hyde" : "wallpaper")
                }
            }

            Card {
                Layout.fillWidth: true
                padding: Theme.space3

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.space2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space1

                        StyledSlider {
                            Layout.fillWidth: true
                            icon: Audio.icon
                            value: Audio.muted ? 0 : Audio.volume
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()
                        }

                        IconButton {
                            icon: "chevron_right"
                            size: 32
                            color: Theme.textDim
                            tooltip: "Outputs and apps"
                            onClicked: ShellState.controlCenterPage = "audio"
                        }
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        Layout.rightMargin: 32 + Theme.space1
                        icon: Audio.micIcon
                        value: Audio.micMuted ? 0 : Audio.micVolume
                        onMoved: v => Audio.setMicVolume(v)
                        onIconClicked: Audio.toggleMicMute()
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        Layout.rightMargin: 32 + Theme.space1
                        visible: Brightness.available
                        icon: Brightness.icon
                        value: Brightness.percent / 100
                        onMoved: v => Brightness.set(v * 100)
                    }
                }
            }

            MediaStrip {
                visible: Media.active !== null
                Layout.fillWidth: true
            }

            // Notifications: the most recent ones (fewer when music is playing, so it fits on screen).
            ColumnLayout {
                id: notifSection

                readonly property int limit: Media.active !== null ? 1 : 2

                Layout.fillWidth: true
                spacing: Theme.space2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2

                    StyledText {
                        text: "Notifications"
                        font.pixelSize: Theme.titleSmall
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: Notifs.count > 0
                        implicitWidth: Math.max(implicitHeight, countText.implicitWidth + Theme.space3)
                        implicitHeight: 20
                        radius: height / 2
                        color: Theme.primaryContainer

                        StyledText {
                            id: countText
                            anchors.centerIn: parent
                            text: Notifs.count
                            font.pixelSize: Theme.labelSmall
                            font.weight: Font.DemiBold
                            color: Theme.onPrimaryContainer
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    TextButton {
                        visible: Notifs.count > notifSection.limit
                        text: "See all"
                        onClicked: ShellState.controlCenterPage = "notifications"
                    }

                    TextButton {
                        visible: Notifs.count > 0
                        text: "Clear"
                        onClicked: Notifs.clear()
                    }
                }

                StyledText {
                    visible: Notifs.count === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    horizontalAlignment: Text.AlignHCenter
                    text: Notifs.dnd ? "Silent mode on" : "No notifications"
                    font.pixelSize: Theme.bodyMedium
                    color: Theme.textFaint
                }

                NotificationList {
                    Layout.fillWidth: true
                    visible: Notifs.count > 0
                    showHeader: false
                    compact: true
                    limit: notifSection.limit
                }
            }

            // HyDE shortcuts: a row of buttons with tooltips.
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [
                        {
                            icon: "skip_next",
                            label: "Next wallpaper",
                            cmd: "hyde-shell app -t scope -- wallpaper.sh --next --global"
                        },
                        {
                            icon: "image",
                            label: "Choose wallpaper",
                            cmd: "hyde-shell app -t scope -- wallpaper.sh --select --global"
                        },
                        {
                            icon: "palette",
                            label: "Choose theme",
                            cmd: "hyde-shell app -t scope -- theme.select.sh"
                        },
                        {
                            icon: "view_quilt",
                            label: "Next bar layout",
                            action: () => BarLayout.cycle(1)
                        },
                        {
                            icon: "animation",
                            label: "Animations",
                            cmd: "hyde-shell animations --select"
                        },
                        {
                            icon: "keyboard",
                            label: "Keybindings",
                            action: () => ShellState.toggleLauncher("keys")
                        }
                    ]

                    Item {
                        id: tile

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 44

                        IconButton {
                            anchors.centerIn: parent
                            icon: tile.modelData.icon
                            size: 44
                            iconSize: 22
                            tonal: true
                            tooltip: tile.modelData.label
                            tooltipBelow: false
                            onClicked: {
                                if (tile.modelData.action) {
                                    tile.modelData.action();
                                } else {
                                    ShellState.closeControlCenter();
                                    Utils.run(tile.modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Text-only button in the accent color (secondary actions of a section).
    component TextButton: Item {
        id: tb

        property string text

        signal clicked

        implicitWidth: tbText.implicitWidth + 2 * Theme.space3
        implicitHeight: 28

        StateLayer {
            anchors.fill: parent
            onClicked: tb.clicked()
        }

        StyledText {
            id: tbText
            anchors.centerIn: parent
            text: tb.text
            font.pixelSize: Theme.labelLarge
            font.weight: Font.Medium
            color: Theme.primary
        }
    }
}
