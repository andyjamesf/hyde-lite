pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.bar.modules.launcher
import qs.bar.modules.notes
import qs.shared.services
import qs.shared.controlcenter

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
        // Anchored to neither side, a layer surface is centred: that is where this opens while
        // the minimal bar is in charge (BarLayout.centerPanels).
        right: !BarLayout.centerPanels
    }
    margins {
        top: BarLayout.atTop ? 6 : 0
        bottom: BarLayout.atTop ? 0 : 6
        right: BarLayout.centerPanels ? 0 : 6
    }
    // The main page is drawn at `compact` of the island's size (this is a desktop, not a tablet):
    // laid out `pageWidth` wide with three tiles to a row, then scaled down, so the panel is both
    // narrower and lower than the island's. The detail pages keep the narrow panel they were made for.
    readonly property real compact: 0.88
    readonly property int pageWidth: 840
    implicitWidth: ShellState.controlCenterPage === "" ? Math.round(pageWidth * compact) + 2 * 16 : 360
    implicitHeight: Math.min(content.implicitHeight + 2 * 16, modelData.height - BarLayout.height - BarLayout.margin - Theme.space6)
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell:controlcenter"
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive while open, as in the launcher and the power menu, which use the same focus grab: the keys
    // go to the panel at once. (On demand, the grab was cleared by the first click on the panel.)
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Always opens at the top (the Flickable kept the position from last time).
    onOpenChanged: {
        grabReady = false;
        if (!open) {
            hint.reset();
            return;
        }
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

    // Name of an icon-only button, shown after the pointer rests on it for a second.
    QtObject {
        id: hint

        property Item target: null
        property string text: ""

        readonly property var names: ({
                avatar: "Change picture",
                system: "System",
                settings: "Settings",
                lock: "Lock",
                power: "Power menu",
                batterypage: "Battery",
                "media-prev": "Previous",
                "media-play": Media.playing ? "Pause" : "Play",
                "media-next": "Next"
            })

        // The panel closing sends no "pointer left": without this the last hint came back on the next open.
        function reset() {
            timer.stop();
            target = null;
            text = "";
        }

        function show(on, id, item) {
            if (!on) {
                if (target === item) {
                    timer.stop();
                    target = null;
                }
                return;
            }
            text = id.startsWith("tab:") ? id.slice(4) : names[id] ?? CcShortcuts.get(id)?.label ?? "";
            target = null;
            timer.pending = item;
            timer.restart();
        }

        readonly property Timer timer: Timer {
            property Item pending: null
            interval: 1000
            onTriggered: if (hint.text !== "")
                hint.target = pending
        }
    }

    Loader {
        active: hint.target !== null && panel.open
        sourceComponent: Tooltip {
            target: hint.target
            text: hint.text
            below: true
        }
    }

    // Tab goes to the next tab and Shift+Tab to the previous one, round all of them (Home to More).
    readonly property var tabIds: ["home", "apps", "clipboard", "keys", "files", "notes", "calendar", "system", "power", "more"]

    function cycleTab(step) {
        const i = Math.max(0, tabIds.indexOf(ShellState.controlCenterTab));
        const next = tabIds[(i + step + tabIds.length) % tabIds.length];
        if (next === "more")
            ShellState.launcherMode = "pick:menu";
        ShellState.controlCenterTab = next;
        // A tab without a field would leave the keys with nothing to hear them.
        if (["home", "calendar", "system", "power"].includes(next))
            bg.forceActiveFocus();
    }

    // The grab only starts once the panel is already open on screen (as in the launcher: activating
    // it in the same instant made Hyprland cancel it).
    property bool grabReady: false

    Timer {
        running: panel.open && !panel.grabReady
        interval: 60
        onTriggered: panel.grabReady = true
    }

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open && panel.grabReady
        onCleared: {
            // Hyprland sometimes cancels the grab on the first click ON the panel, which is not a click
            // outside: the pointer is still over it. Then the grab is armed again and the panel stays.
            if (panel.open && overPanel.hovered) {
                panel.grabReady = false;
                return;
            }
            ShellState.closeControlCenter();
        }
    }

    Rectangle {
        id: bg
        // Whether the pointer is over the panel (the compositor says so when it enters the surface).
        HoverHandler {
            id: overPanel
        }

        // Closed, the panel sat off to the side at 40% opacity but was still drawn: anything animating
        // inside it kept the window rendering frames nobody sees, which costs battery. Same condition as
        // the input mask.
        visible: panel.open || panel.slide < 1
        width: parent.width
        height: parent.height
        // It comes in from the right for the normal bar, whose buttons are in that corner.
        // Centred instead (BarLayout.centerPanels), it grows out of a point at the top middle,
        // under the clock, which is the part of the bar it belongs to: sliding in sideways from
        // a corner that has no button in it read as coming from nowhere.
        x: BarLayout.centerPanels ? 0 : panel.slide * (panel.width + Theme.space3)
        opacity: 1 - panel.slide * (BarLayout.centerPanels ? 1 : 0.6)
        transform: Scale {
            origin.x: bg.width / 2
            origin.y: 0
            xScale: BarLayout.centerPanels ? 1 - panel.slide * 0.35 : 1
            yScale: xScale
        }
        radius: Theme.shapeXL
        // Tunable in config.json (controlCenter.opacity, 0.2 to 1).
        color: Theme.alpha(Theme.surfaceContainer, Math.max(Config.controlCenter.opacity, Theme.panelOpacity))
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.45)
        focus: panel.open

        // What the tab's own field does not take (and Ctrl+Tab even there, for the notes page).
        Keys.onTabPressed: event => {
            panel.cycleTab(1);
            event.accepted = true;
        }
        Keys.onBacktabPressed: event => {
            panel.cycleTab(-1);
            event.accepted = true;
        }
        Keys.onEscapePressed: ShellState.controlCenterPage !== "" ? ShellState.controlCenterPage = "" : ShellState.closeControlCenter()

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 16
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
                            "notifications": notificationsPage,
                            "battery": batteryPage,
                            "system": systemPage
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

    // Power profiles: where the arrow on the Power profile tile goes. The panel was only ever a
    // popout from the bar's battery widget, so in the control centre that arrow led nowhere.
    Component {
        id: batteryPage

        ColumnLayout {
            width: 320
            spacing: Theme.space3

            // The panel itself is the one the bar's battery widget pops out, unchanged; here it
            // just gets a header to come back from.
            PanelHeader {
                backButton: true
                onBack: ShellState.controlCenterPage = ""
                icon: Battery.icon
                title: "Battery"
                subtitle: Battery.profileName
            }

            BatteryPanel {
                Layout.fillWidth: true
            }
        }
    }

    // The PC's statistics, which until now only the island had.
    Component {
        id: systemPage

        SystemPanel {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
        }
    }

    Component {
        id: notificationsPage

        ColumnLayout {
            spacing: Theme.space2

            PanelHeader {
                backButton: true
                onBack: ShellState.controlCenterPage = ""
                icon: Notifications.dnd ? "notifications_off" : "notifications"
                title: "Notifications"
                subtitle: Notifications.dnd ? "Do not disturb is on" : ""

                IconButton {
                    icon: "do_not_disturb_on"
                    size: 32
                    checked: Notifications.dnd
                    onClicked: Notifications.toggleDnd()
                }
            }

            NotificationCentre {
                Layout.fillWidth: true
                foreground: Theme.text
                accent: Theme.primary
                dim: Theme.textDim
                faint: Theme.textFaint
                hover: Theme.hover
                pressed: Theme.pressed
                fontFamily: Config.appearance.font
                fontSize: Theme.bodyMedium
                visibleRows: Math.min(Notifications.count, 8)
            }
        }
    }

    Component {
        id: audioPage

        AudioPanel {
            backButton: true
            onBack: ShellState.controlCenterPage = ""
        }
    }

    // Compact player: cover, title/artist and the controls on the right; progress at the bottom.
    component MediaStrip: Card {
        id: strip

        readonly property var player: Media.player

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

    // The tabs of the panel. The ones that search (apps, clipboard, keys and the pickers under "More")
    // are the launcher's view pinned to one mode; Notes and Calendar are the notes page and the month.
    Component {
        id: searchTab

        LauncherView {
            id: searchView
            // "More" shows the picker that was asked for, or the menu of them.
            pinnedMode: ShellState.controlCenterTab === "more" ? (ShellState.launcherMode.startsWith("pick:") ? ShellState.launcherMode : "pick:menu") : ShellState.controlCenterTab
            open: panel.open && ShellState.controlCenterPage === ""
            showChips: false
            listMax: Math.max(160, height - 100)
            // Esc: out of a picker back to the menu of them, anywhere else shut the panel.
            onCloseRequested: {
                if (!searchView.closingDone && ShellState.controlCenterTab === "more" && ShellState.launcherMode !== "pick:menu")
                    ShellState.launcherMode = "pick:menu";
                else
                    ShellState.closeControlCenter();
            }
            onCycleTabRequested: step => panel.cycleTab(step)
        }
    }

    Component {
        id: notesTab

        NotesView {
            open: panel.open && ShellState.controlCenterPage === "" && ShellState.controlCenterTab === "notes"
            // Esc: out of the list of notes back to the note, otherwise shut the panel.
            onCloseRequested: {
                if (ShellState.notesMode === "list")
                    ShellState.notesMode = "edit";
                else
                    ShellState.closeControlCenter();
            }
            // Tab goes on round the tabs here instead of typing a tab into the note.
            tabCycles: true
            onCycleTabRequested: step => panel.cycleTab(step)
        }
    }

    Component {
        id: calendarTab

        CalendarWide {}
    }

    // System: the resource manager (load per core, memory, temperatures, storage, network, the heaviest
    // processes), the same view as the System page, filling the tab.
    Component {
        id: systemTab

        Flickable {
            id: sysFlick
            clip: true
            contentHeight: sysView.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds

            // The script behind the numbers only runs while something is showing them.
            Component.onCompleted: SysStats.pageShown = true
            Component.onDestruction: SysStats.pageShown = false

            SysStatsView {
                id: sysView
                x: 12
                y: 12
                width: sysFlick.width - 24

                accent: Theme.primary
                accentContent: Theme.onPrimary
                border: Theme.border
                danger: Theme.error
                dim: Theme.textDim
                faint: Theme.textFaint
                foreground: Theme.text
                hover: Theme.hover
                fontFamily: Config.appearance.font
                fontSize: Theme.bodyMedium
                animationDuration: Anim.normal
                sortBy: SysStats.sortBy
                onSortByChanged: SysStats.sortBy = sortBy
            }
        }
    }

    // Power: the session actions as big buttons. The ones that end the session ask for a second click.
    Component {
        id: powerTab

        Item {
            id: powerRoot

            property int armed: -1
            readonly property var actions: [
                {
                    glyph: "\u{F033E}",
                    label: "Lock",
                    cmd: "loginctl lock-session",
                    confirm: false
                },
                {
                    glyph: "\u{F0904}",
                    label: "Suspend",
                    cmd: "systemctl suspend",
                    confirm: false
                },
                {
                    glyph: "\u{F04B2}",
                    label: "Hibernate",
                    cmd: "systemctl hibernate",
                    confirm: false
                },
                {
                    glyph: "\u{F0343}",
                    label: "Log out",
                    cmd: "hyprctl dispatch 'hl.dsp.exit()'",
                    confirm: true
                },
                {
                    glyph: "\u{F0709}",
                    label: "Restart",
                    cmd: "systemctl reboot",
                    confirm: true
                },
                {
                    glyph: "\u{F0425}",
                    label: "Shut down",
                    cmd: "systemctl poweroff",
                    confirm: true
                }
            ]

            Timer {
                id: disarm
                interval: 3000
                onTriggered: powerRoot.armed = -1
            }

            Grid {
                anchors.fill: parent
                columns: 3
                spacing: 14

                Repeater {
                    model: powerRoot.actions

                    Rectangle {
                        id: btn
                        required property var modelData
                        required property int index
                        readonly property bool armed: powerRoot.armed === index
                        readonly property bool danger: modelData.label === "Restart" || modelData.label === "Shut down"

                        // The panel shared out between 3 columns and 2 rows.
                        width: (parent.width - 28) / 3
                        height: (parent.height - 14) / 2 - 8
                        radius: 22
                        color: btn.armed ? Theme.alpha(Theme.error, 0.25) : btn.danger ? Theme.alpha(Theme.error, 0.12) : btnMouse.pressed ? Theme.pressed : btnMouse.containsMouse ? Theme.hover : Theme.alpha(Theme.text, 0.05)
                        border.width: 1
                        border.color: btn.armed || btn.danger ? Theme.alpha(Theme.error, 0.45) : Theme.border

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.modelData.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 34
                                elide: Text.ElideNone
                                color: btn.armed || btn.danger ? Theme.error : Theme.text
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.armed ? "Click again to confirm" : btn.modelData.label
                                font.pixelSize: Theme.bodyMedium
                                color: btn.armed ? Theme.error : Theme.text
                            }
                        }

                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData.confirm && powerRoot.armed !== btn.index) {
                                    powerRoot.armed = btn.index;
                                    disarm.restart();
                                    return;
                                }
                                ShellState.closeControlCenter();
                                Utils.run(btn.modelData.cmd);
                            }
                        }
                    }
                }
            }
        }
    }

    // The main page is the island's, shared (shared/controlcenter/CcMainView.qml); this panel only
    // says what a click leads to.
    Component {
        id: mainPage

        // Scaled with a transform, which does not change the layout size: the wrapper reports the scaled one.
        Item {
            width: parent?.width ?? 0
            implicitHeight: view.implicitHeight * panel.compact
            height: implicitHeight

            CcWideView {
                id: view
                badge: Theme.source
                width: panel.pageWidth
                scale: panel.compact
                transformOrigin: Item.TopLeft
                // The bar's own extra button: cycle its layout.
                shortcuts: ["nextwallpaper", "wallpaper", "animations", "keybindings", "syncshell", "barlayout"]
                visibleRows: Math.min(Math.max(Notifications.count, 1), 3)
                tabs: Config.controlCenter.tabs ? [
                    {
                        id: "home",
                        glyph: "\u{F02DC}",
                        label: "Home"
                    },
                    {
                        id: "apps",
                        glyph: "\u{F0570}",
                        label: "Apps"
                    },
                    {
                        id: "clipboard",
                        glyph: "\u{F014C}",
                        label: "Clipboard"
                    },
                    {
                        id: "keys",
                        glyph: "\u{F030C}",
                        label: "Keys"
                    },
                    {
                        id: "files",
                        glyph: "\u{F024B}",
                        label: "Files"
                    },
                    {
                        id: "notes",
                        glyph: "\u{F09A8}",
                        label: "Notes"
                    },
                    {
                        id: "calendar",
                        glyph: "\u{F00ED}",
                        label: "Calendar"
                    },
                    {
                        id: "system",
                        glyph: "\u{F061A}",
                        label: "System"
                    },
                    {
                        id: "power",
                        glyph: "\u{F0425}",
                        label: "Power"
                    },
                    {
                        id: "more",
                        glyph: "\u{F01D9}",
                        label: "More"
                    }
                ] : []
                tab: ShellState.controlCenterTab
                onTabRequested: id => ShellState.controlCenterTab = id
                tabContent: Component {
                    Loader {
                        sourceComponent: ({
                                notes: notesTab,
                                calendar: calendarTab,
                                system: systemTab,
                                power: powerTab
                            })[ShellState.controlCenterTab] ?? searchTab
                    }
                }

                onPageRequested: page => {
                    // The island has a player page; the bar has none, so the row only shows what plays.
                    if (page !== "media")
                        ShellState.controlCenterPage = page;
                }
                onHintRequested: (on, id, item) => hint.show(on, id, item)
                onHeaderAction: id => {
                    if (id === "system") {
                        if (Config.controlCenter.tabs)
                            ShellState.controlCenterTab = "system";
                        else
                            ShellState.controlCenterPage = "system";
                    } else if (id === "power") {
                        if (Config.controlCenter.tabs)
                            ShellState.controlCenterTab = "power";
                        else
                            ShellState.togglePowerMenu();
                    } else if (id === "lock") {
                        ShellState.closeControlCenter();
                        Utils.run("loginctl lock-session");
                    } else if (id === "avatar") {
                        ShellState.closeControlCenter();
                        SysInfo.chooseAvatar();
                    } else if (id === "settings") {
                        ShellState.closeControlCenter();
                        // The shell folder and config.json in a code editor (the first one that exists).
                        const dir = Quickshell.shellPath("bar");
                        const cfg = Quickshell.shellPath("bar/config/config.json");
                        // The paths are arguments ("$1", "$2"), not part of the command text.
                        Quickshell.execDetached(["sh", "-c", 'for e in code codium zeditor; do command -v $e >/dev/null && exec $e "$1" "$2"; done; exec kitty nvim "$2"', "sh", dir, cfg]);
                    }
                }
            }
        }
    }

}
