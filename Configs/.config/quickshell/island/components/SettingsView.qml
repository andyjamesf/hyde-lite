import QtQuick
import Quickshell.Widgets
import qs.island.config
import qs.island.icons
import qs.island.core
import qs.island.services
import qs.island.theme
import qs.shared.services

// Settings in the island ("settings" mode): appearance, behaviour and animations. Everything
// applies live (the bar height resizes the collapsed island on every screen at once) and is stored
// as overrides in prefs.json (services/Prefs.qml) after a short delay, so the file is not written
// for every pixel of a drag. Ranges: config/SettingsScreen.qml.
// Keyboard: Tab/Shift+Tab or up/down move the ring between rows · left/right adjust the sliders ·
// Enter/Space toggle or open · Esc is left to the island (not accepted here).
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through ModeSlot).
    property bool open: false

    readonly property real islandRadius: 26
    readonly property int pad: 20
    // Maximum height of the whole; beyond it the body scrolls.
    readonly property int maxHeight: SettingsScreen.maxHeight
    readonly property real bodyWidth: implicitWidth - 2 * pad

    // Rows navigable by keyboard, in screen order.
    readonly property var rows: [barRow, fontRow, themeRow, wallpaperRow, hoverRow, peaceRow, animationsRow, speedRow, clockRow, topRow, statusPillRow, nearClockRow, statusIconsRow, shortcutsRow, pillsRow, updateRow, systemRow, resetRow]
    property int current: 0
    // The ring only shows after using the keyboard.
    property bool keyNav: false

    // Current theme (base colours, without applying it) and thumbnail of the current wallpaper.
    readonly property var themePreview: Theme.preview(ThemeConfig.name)
    readonly property var wallpaperEntry: Wallpapers.list.find(e => e.path === Wallpapers.current) ?? null
    readonly property string wallpaperThumb: wallpaperEntry ? wallpaperEntry.thumb : Wallpapers.current !== "" ? Wallpapers.fileUrl(Wallpapers.current) : ""
    readonly property string wallpaperName: {
        if (wallpaperEntry)
            return wallpaperEntry.name;
        const c = Wallpapers.current;
        return c === "" ? "None" : c.slice(c.lastIndexOf("/") + 1);
    }

    focus: true
    implicitWidth: SettingsScreen.width
    implicitHeight: Math.min(maxHeight, body.y + content.implicitHeight + pad)

    onOpenChanged: {
        if (open) {
            reset();
            Updates.refreshHydeLite();
            Updates.refresh();
        } else {
            Prefs.flush();
        }
    }
    Component.onCompleted: if (open)
        reset()
    Component.onDestruction: Prefs.flush()

    // Every opening starts at the top, without the keyboard ring.
    function reset() {
        current = 0;
        keyNav = false;
        body.contentY = 0;
        // The window's keyboard focus only arrives a moment later (and the island still reclaims it
        // when changing mode): try again after that.
        focusRetry.start();
    }

    // "Reset to defaults": removes the overrides, so the config file defaults apply again.
    function resetDefaults() {
        Prefs.reset(SettingsScreen.resetKeys);
        Prefs.flush();
    }

    function move(delta) {
        current = Math.max(0, Math.min(rows.length - 1, current + delta));
        ensureVisible(rows[current]);
    }

    // Scrolls until the row is fully visible.
    function ensureVisible(item) {
        if (!item)
            return;
        const top = item.mapToItem(content, 0, 0).y;
        const bottom = top + item.height;
        if (top < body.contentY)
            body.contentY = Math.max(0, top - 8);
        else if (bottom > body.contentY + body.height)
            body.contentY = Math.min(body.contentHeight - body.height, bottom - body.height + 8);
    }

    Keys.onPressed: event => {
        const row = rows[current];
        switch (event.key) {
        case Qt.Key_Tab:
        case Qt.Key_Down:
            move(1);
            break;
        case Qt.Key_Backtab:
        case Qt.Key_Up:
            move(-1);
            break;
        case Qt.Key_Home:
            current = 0;
            ensureVisible(rows[current]);
            break;
        case Qt.Key_End:
            current = rows.length - 1;
            ensureVisible(rows[current]);
            break;
        case Qt.Key_Left:
            row.adjustRequested(-1);
            break;
        case Qt.Key_Right:
            row.adjustRequested(1);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            row.triggered();
            break;
        default:
            // Esc and the rest go on to the island.
            return;
        }
        keyNav = true;
        event.accepted = true;
    }

    FocusRetry {
        id: focusRetry
        target: root
        when: root.open
    }

    // Under everything: swallows clicks outside the rows and gives the focus back to the view.
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    Item {
        id: header
        x: root.pad
        y: 14
        width: root.bodyWidth
        height: 28

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Settings"
            font.pixelSize: Appearance.fontSize + 3
            font.weight: Font.DemiBold
        }
    }

    Flickable {
        id: body
        x: root.pad - 6
        y: header.y + header.height + 8
        width: root.bodyWidth + 12
        height: root.height - y - root.pad
        contentHeight: content.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            x: 6
            width: root.bodyWidth
            spacing: 2

            // --- Appearance ---------------------------------------------------------------------------
            SettingsSectionTitle {
                text: "Appearance"
            }

            SettingsSliderRow {
                id: barRow
                width: parent.width
                title: "Bar height"
                from: SettingsScreen.barHeightMin
                to: SettingsScreen.barHeightMax
                step: 1
                value: Pill.height
                valueText: `${Pill.height} px`
                focused: root.keyNav && root.current === 0
                onEntered: root.current = 0
                onValueEdited: v => Prefs.set("pill.height", Math.round(v))
            }

            SettingsSliderRow {
                id: fontRow
                width: parent.width
                title: "Font size"
                from: SettingsScreen.fontSizeMin
                to: SettingsScreen.fontSizeMax
                step: 1
                value: Appearance.fontSize
                valueText: `${Appearance.fontSize} px`
                focused: root.keyNav && root.current === 1
                onEntered: root.current = 1
                onValueEdited: v => Prefs.set("appearance.fontSize", Math.round(v))
            }

            SettingsRow {
                id: themeRow
                width: parent.width
                title: "Theme"
                focused: root.keyNav && root.current === 2
                onEntered: root.current = 2
                onTriggered: IslandController.open(IslandState.theme)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ThemeConfig.name
                    color: Theme.dim
                }

                // Minimal theme swatch: background, surface pill and accent dot.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    height: 24
                    radius: 7
                    color: root.themePreview.background
                    border.width: 1
                    border.color: root.themePreview.kind === "eink" ? root.themePreview.foreground : Qt.alpha(root.themePreview.foreground, 0.2)

                    Rectangle {
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 6
                        radius: 3
                        color: root.themePreview.surface
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: root.themePreview.accent
                    }
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "chevron"
                    size: 14
                    color: Theme.dim
                }
            }

            SettingsRow {
                id: wallpaperRow
                width: parent.width
                title: "Wallpaper"
                focused: root.keyNav && root.current === 3
                onEntered: root.current = 3
                onTriggered: IslandController.open(IslandState.wallpaper)

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 170)
                    text: root.wallpaperName
                    color: Theme.dim
                }

                ClippingRectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 30
                    radius: 7
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    Image {
                        anchors.fill: parent
                        source: root.wallpaperThumb
                        sourceSize.width: 96
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "chevron"
                    size: 14
                    color: Theme.dim
                }
            }

            // --- Behaviour ----------------------------------------------------------------------------
            SettingsSectionTitle {
                text: "Behaviour"
            }

            SettingsRow {
                id: hoverRow
                width: parent.width
                title: "Expand on hover"
                subtitle: "Open the island when the pointer rests on it"
                focused: root.keyNav && root.current === 4
                onEntered: root.current = 4
                onTriggered: Prefs.set("pill.hoverExpand", !Pill.hoverExpand)

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Pill.hoverExpand
                    onToggled: hoverRow.triggered()
                }
            }

            SettingsRow {
                id: peaceRow
                width: parent.width
                title: "Peace Mode"
                subtitle: "Hide notification popups"
                focused: root.keyNav && root.current === 5
                onEntered: root.current = 5
                onTriggered: Prefs.set("notifications.peaceMode", !Notifications.peaceMode)

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Notifications.peaceMode
                    onToggled: peaceRow.triggered()
                }
            }

            // --- Animations ---------------------------------------------------------------------------
            SettingsSectionTitle {
                text: "Animations"
            }

            SettingsRow {
                id: animationsRow
                width: parent.width
                title: "Animations"
                subtitle: "Springs, fades and colour transitions"
                focused: root.keyNav && root.current === 6
                onEntered: root.current = 6
                onTriggered: Prefs.set("animations.enabled", !Animations.enabled)

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Animations.enabled
                    onToggled: animationsRow.triggered()
                }
            }

            SettingsSliderRow {
                id: speedRow
                width: parent.width
                title: "Speed"
                from: SettingsScreen.speedMin
                to: SettingsScreen.speedMax
                step: SettingsScreen.speedStep
                value: Animations.speed
                valueText: `${Number(Animations.speed).toFixed(1)}×`
                // Without animations the speed hardly matters: it is dimmed (but still editable).
                opacity: Animations.enabled ? 1 : 0.5
                focused: root.keyNav && root.current === 7
                onEntered: root.current = 7
                onValueEdited: v => Prefs.set("animations.speed", Math.round(v * 10) / 10)
            }

            // --- Pill ---------------------------------------------------------------------------------
            SettingsSectionTitle {
                text: "Pill"
            }

            SettingsRow {
                id: clockRow
                width: parent.width
                title: "12-hour clock"
                subtitle: "1:05 PM instead of 13:05 (also on the login screen)"
                focused: root.keyNav && root.current === 8
                onEntered: root.current = 8
                onTriggered: Prefs.set("clock.hour12", !Prefs.get("clock.hour12", false))

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Prefs.get("clock.hour12", false)
                    onToggled: clockRow.triggered()
                }
            }

            SettingsSliderRow {
                id: topRow
                width: parent.width
                title: "Top margin"
                from: SettingsScreen.topMarginMin
                to: SettingsScreen.topMarginMax
                step: 1
                value: Pill.topMargin
                valueText: `${Pill.topMargin} px`
                focused: root.keyNav && root.current === 9
                onEntered: root.current = 9
                onValueEdited: v => Prefs.set("pill.topMargin", Math.round(v))
            }

            SettingsRow {
                id: statusPillRow
                width: parent.width
                title: "Status pill"
                subtitle: "The small pill with the status icons"
                focused: root.keyNav && root.current === 10
                onEntered: root.current = 10
                onTriggered: Prefs.set("statusPill.enabled", !StatusPillConfig.enabled)

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: StatusPillConfig.enabled
                    onToggled: statusPillRow.triggered()
                }
            }

            SettingsRow {
                id: nearClockRow
                width: parent.width
                title: "Status pill next to the clock"
                subtitle: "Instead of the screen's right edge"
                opacity: StatusPillConfig.enabled ? 1 : 0.5
                focused: root.keyNav && root.current === 11
                onEntered: root.current = 11
                onTriggered: Prefs.set("statusPill.nearClock", StatusPillConfig.placement !== "clock")

                CcSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: StatusPillConfig.placement === "clock"
                    onToggled: nearClockRow.triggered()
                }
            }

            // --- Icons --------------------------------------------------------------------------------
            SettingsSectionTitle {
                text: "Icons"
            }

            IconListEditor {
                id: statusIconsRow
                width: parent.width
                title: "Status"
                subtitle: "Pill on the right, and the expanded island"
                prefKey: "statusPill.icons"
                current: StatusPillConfig.icons
                choices: SettingsScreen.statusIconChoices
                focused: root.keyNav && root.current === 12
                onEntered: root.current = 12
            }

            IconListEditor {
                id: shortcutsRow
                width: parent.width
                title: "Shortcuts"
                subtitle: "Buttons next to them, as many as fit"
                prefKey: "expanded.extraButtons"
                current: Expanded.extraButtons
                choices: SettingsScreen.shortcutChoices
                focused: root.keyNav && root.current === 13
                onEntered: root.current = 13
            }

            SettingsSectionTitle {
                text: "Extra pills"
            }

            PillsEditor {
                id: pillsRow
                width: parent.width
                focused: root.keyNav && root.current === 14
                onEntered: root.current = 14
            }

            SettingsSectionTitle {
                text: "hyde-lite"
            }

            SettingsRow {
                id: updateRow
                width: parent.width
                title: "Update hyde-lite"
                subtitle: Updates.hydeLiteChecking ? "Checking…" : Updates.hydeLiteSummary
                clickable: false
                focused: root.keyNav && root.current === 15
                onEntered: root.current = 15
                onTriggered: Updates.updateHydeLite()

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    CcTextButton {
                        text: "Check"
                        enabled: !Updates.hydeLiteChecking
                        onClicked: Updates.refreshHydeLite()
                    }

                    CcTextButton {
                        text: "Update"
                        primary: Updates.hydeLiteState === "available" || Updates.hydeLiteState === "unfinished"
                        onClicked: updateRow.triggered()
                    }
                }
            }

            // The system's own updates (pacman, AUR, flatpak), kept apart from the hyde-lite one on purpose: a
            // terminal lists what is waiting and asks before it updates (HyDE's system.update.py, as the Updates icon).
            SettingsRow {
                id: systemRow
                width: parent.width
                title: "System updates"
                subtitle: Updates.checking ? "Checking…" : Updates.count > 0 ? Updates.summary : "Up to date"
                clickable: false
                focused: root.keyNav && root.current === 16
                onEntered: root.current = 16
                onTriggered: Updates.open()

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    CcTextButton {
                        text: "Check"
                        enabled: !Updates.checking
                        onClicked: Updates.refresh()
                    }

                    CcTextButton {
                        text: "Update"
                        primary: Updates.count > 0
                        enabled: !Updates.updating
                        onClicked: systemRow.triggered()
                    }
                }
            }

            Item {
                width: 1
                height: 6
            }

            SettingsRow {
                id: resetRow
                width: parent.width
                clickable: false
                focused: root.keyNav && root.current === 17
                onEntered: root.current = 17
                onTriggered: root.resetDefaults()

                CcTextButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Reset to defaults"
                    onClicked: resetRow.triggered()
                }
            }
        }
    }
}
