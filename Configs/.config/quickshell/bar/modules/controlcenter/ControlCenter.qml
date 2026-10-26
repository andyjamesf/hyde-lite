import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
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
    implicitWidth: CcTheme.panelWidth
    implicitHeight: Math.min(content.implicitHeight + 2 * 16, modelData.height - BarLayout.height - BarLayout.margin - Theme.space6)
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
        color: Theme.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.border
        focus: panel.open
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

    // The main page is the island's, shared (shared/controlcenter/CcMainView.qml); this panel only
    // says what a click leads to.
    Component {
        id: mainPage

        CcMainView {
            width: parent?.width ?? 0
            // The bar has one more button: cycle its layout.
            shortcuts: ["nextwallpaper", "wallpaper", "hydetheme", "animations", "keybindings", "syncshell", "barlayout"]
            visibleRows: Math.min(Notifications.count, Media.active ? 3 : 4)

            onPageRequested: page => {
                // The island has a player page; the bar has none, so the row only shows what plays.
                if (page !== "media")
                    ShellState.controlCenterPage = page;
            }
            onHeaderAction: id => {
                if (id === "system") {
                    ShellState.controlCenterPage = "system";
                } else if (id === "power") {
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
                    Utils.run(`for e in code codium zeditor; do command -v $e >/dev/null && exec $e "${dir}" "${cfg}"; done; exec kitty nvim "${cfg}"`);
                }
            }
        }
    }

}
