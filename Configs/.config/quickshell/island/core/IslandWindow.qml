import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.island.config
import qs.island.services
import qs.island.components
import qs.island.theme
import qs.shared.services

// One window per screen: transparent, as big as the island's largest shape, but only the island
// receives clicks (mask). Reserves the space of the collapsed island at the top.
PanelWindow {
    id: win

    required property ShellScreen modelData
    // Pointer over the island (or faked by IPC).
    readonly property bool rawHover: island.hovered || IslandController.forceHover
    // Hover as seen by the base mode: on at once, off Pill.hoverCollapseDelay ms after leaving.
    property bool hoverHeld: false
    readonly property string displayMode: IslandController.modeFor(modelData?.name, hoverHeld)
    readonly property bool surface: IslandState.isSurface(displayMode)
    // With the pointer over this screen's OSD/notification, the countdown pauses (and resumes on
    // leaving). Also re-evaluated when the transient moves to another screen, not only on hover.
    readonly property bool holding: rawHover && modelData?.name === IslandController.effectiveScreen
    onHoldingChanged: IslandController.held = holding

    onRawHoverChanged: {
        if (rawHover) {
            collapseTimer.stop();
            hoverHeld = true;
        } else {
            collapseTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: Pill.hoverCollapseDelay
        onTriggered: win.hoverHeld = false
    }

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    // The window has to fit the tallest shape the island can take; anything beyond it is clipped.
    //
    // This was `Math.min(screenHeight - 40, 760)`. On this laptop panel -- 1920x1200 at scale 1.5,
    // so 800 logical -- `800 - 40` is exactly 760, which means the cap was the panel's own height
    // written down as a constant, and the two terms were the same number by coincidence. On a taller
    // screen the cap won and the rest went unused: measured at 760 of 1080 logical on the external
    // one. The margin alone says the same thing on the laptop and scales everywhere else.
    //
    // `modelData` is only null while the window is being torn down, where this is not used for
    // anything: 800 is a placeholder, not a panel size.
    implicitHeight: Math.max(Pill.reservedHeight, Math.round((modelData?.height ?? 800) - Pill.bottomMargin))
    // With the pill hidden only surfaces and transients show; the clock slides up off screen.
    readonly property bool baseHidden: Pill.hidden && (displayMode === IslandState.clock || displayMode === IslandState.expanded)

    exclusiveZone: Pill.hidden ? 0 : Pill.reservedHeight
    color: "transparent"
    mask: Region {
        item: win.baseHidden ? null : island

        Region {
            item: win.satelliteShown ? satellite : null
        }
        Region {
            item: win.statusShown ? statusPill : null
        }
        Region {
            item: extra0.active ? extra0 : null
        }
        Region {
            item: extra1.active ? extra1 : null
        }
        Region {
            item: extra2.active ? extra2 : null
        }
        Region {
            item: extra3.active ? extra3 : null
        }
        Region {
            item: menuCard.showing ? menuCard : null
        }
    }

    WlrLayershell.namespace: "quickshell:island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: IslandState.keyboardModes.includes(displayMode) ? WlrKeyboardFocus.Exclusive : surface ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Caffeine (control center tile): keeps the session from going idle while on.
    IdleInhibitor {
        window: win
        enabled: Caffeine.active
    }

    // Open surfaces: clicking outside closes them.
    // The grab only starts 60 ms after the surface opens: at the same time as the exclusive
    // keyboard focus, Hyprland cancelled it right away (the surface closed as soon as it opened).
    property bool grabReady: false
    // Re-armed on every mode change, also between two surfaces (e.g. media page → theme picker),
    // otherwise the new surface's grab starts too early and Hyprland cancels it.
    onDisplayModeChanged: grabReady = false

    Timer {
        running: win.surface && !win.grabReady
        interval: 60
        onTriggered: win.grabReady = true
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.surface && win.grabReady
        onCleared: IslandController.close()
    }

    // A right-click menu over the pill (no surface open): clicking outside closes it. (With a
    // surface open, the grab above covers it and closing the surface closes the menu too.)
    property bool menuGrabReady: false
    Timer {
        running: menuCard.showing && !win.menuGrabReady
        interval: 60
        onTriggered: win.menuGrabReady = true
    }
    HyprlandFocusGrab {
        windows: [win]
        active: menuCard.showing && !win.surface && win.menuGrabReady
        onCleared: IslandController.closeMenu()
    }

    // Hiding/showing the pill: it slides up off screen (and back) with the same spring.
    Spring {
        id: ySpring
        target: win.baseHidden ? -island.height - 16 : Pill.topMargin
    }

    // Workspace indicator pill (config/WorkspacesConfig.qml): at the screen's left edge or next to the
    // clock pill (WorkspacesConfig.placement). When the island leaves the clock (expands on hover or
    // pin, or shows anything else) it slides under the island and fades, as if absorbed; the
    // expanded island shows the workspaces itself.
    readonly property bool satelliteShown: WorkspacesConfig.enabled && displayMode === IslandState.clock && !baseHidden

    Spring {
        id: satX
        target: !win.satelliteShown ? island.x + (island.width - satellite.width) / 2 : WorkspacesConfig.placement === "clock" ? island.x - WorkspacesConfig.gap - satellite.width : WorkspacesConfig.edgeMargin
    }

    IslandSurface {
        id: satellite
        // Under the island, so it disappears behind it when absorbed.
        z: -1
        x: Math.round(satX.value)
        y: ySpring.value
        targetWidth: workspaces.implicitWidth + 2 * WorkspacesConfig.padding
        targetHeight: Pill.height
        opacity: win.satelliteShown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(win.satelliteShown ? Animations.fadeIn : Animations.fadeOut)
                easing.type: Easing.OutCubic
            }
        }

        WorkspacesView {
            id: workspaces
            anchors.centerIn: parent
        }
    }

    // Status pill (config/StatusPillConfig.qml): battery (percentage and time left) and other status,
    // at the screen's right edge or next to the clock. Absorbed into the island like the workspace
    // pill; the expanded island shows the status in its right zone.
    readonly property bool statusShown: StatusPillConfig.enabled && displayMode === IslandState.clock && !baseHidden

    Spring {
        id: statusX
        target: !win.statusShown ? island.x + (island.width - statusPill.width) / 2 : StatusPillConfig.placement === "clock" ? island.x + island.width + StatusPillConfig.gap : win.width - StatusPillConfig.edgeMargin - statusPill.width
    }

    IslandSurface {
        id: statusPill
        z: -1
        x: Math.round(statusX.value)
        y: ySpring.value
        targetWidth: status.implicitWidth + 2 * StatusPillConfig.padding
        targetHeight: Pill.height
        opacity: win.statusShown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(win.statusShown ? Animations.fadeIn : Animations.fadeOut)
                easing.type: Easing.OutCubic
            }
        }

        StatusZone {
            id: status
            anchors.centerIn: parent
            icons: StatusPillConfig.icons
            batteryPercent: StatusPillConfig.batteryPercent
            batteryTime: StatusPillConfig.batteryTime
            alwaysShowBell: StatusPillConfig.alwaysShowBell
        }
    }

    // Extra pills (config/PillsConfig.qml): four slots, each used when the pill list has an entry for it. Left
    // pills stack rightwards from just after the workspace pill (or the screen's edge), right pills leftwards
    // from just before the status pill, so they never cover the two built-in ones. A fixed set of slots, each
    // with its own mask region, keeps every pill clickable.
    readonly property real extraLeftStart: WorkspacesConfig.enabled && WorkspacesConfig.placement !== "clock" ? WorkspacesConfig.edgeMargin + satellite.targetWidth + PillsConfig.gap : WorkspacesConfig.edgeMargin
    readonly property real extraRightStart: StatusPillConfig.enabled && StatusPillConfig.placement !== "clock" ? win.width - StatusPillConfig.edgeMargin - statusPill.targetWidth - PillsConfig.gap : win.width - StatusPillConfig.edgeMargin
    readonly property var extraWidths: [extra0.targetWidth, extra1.targetWidth, extra2.targetWidth, extra3.targetWidth]
    // The plain clock pill only. "clock" is IslandState.clock written out: qmllint counts a read of one of
    // IslandState's members from a binding here (tools/tests/test_pills.py keeps the two equal).
    readonly property bool extraAllowed: displayMode === "clock" && !baseHidden

    function extraX(k) {
        return k < PillsConfig.extra.length ? PillsConfig.xFor(PillsConfig.extra, extraWidths, k, extraLeftStart, extraRightStart, PillsConfig.gap) : 0;
    }

    ExtraPill {
        id: extra0
        spec: PillsConfig.extra[0] ?? null
        allowed: win.extraAllowed
        shownX: win.extraX(0)
        absorbedX: island.x + (island.width - targetWidth) / 2
        y: ySpring.value
    }
    ExtraPill {
        id: extra1
        spec: PillsConfig.extra[1] ?? null
        allowed: win.extraAllowed
        shownX: win.extraX(1)
        absorbedX: island.x + (island.width - targetWidth) / 2
        y: ySpring.value
    }
    ExtraPill {
        id: extra2
        spec: PillsConfig.extra[2] ?? null
        allowed: win.extraAllowed
        shownX: win.extraX(2)
        absorbedX: island.x + (island.width - targetWidth) / 2
        y: ySpring.value
    }
    ExtraPill {
        id: extra3
        spec: PillsConfig.extra[3] ?? null
        allowed: win.extraAllowed
        shownX: win.extraX(3)
        absorbedX: island.x + (island.width - targetWidth) / 2
        y: ySpring.value
    }

    // Hint under a hovered status icon or shortcut button (IslandController.hint; text from
    // Shortcuts.hint), after the pointer rests a moment. Once one shows, moving to a neighbour
    // switches at once (hintArmed stays on while the pointer is off the icons less than 300 ms).
    property bool hintArmed: false

    Timer {
        id: hintDelay
        interval: 450
        onTriggered: win.hintArmed = true
    }
    Timer {
        id: hintGrace
        interval: 300
        onTriggered: win.hintArmed = false
    }
    Connections {
        target: IslandController
        function onHintPinnedChanged() {
            if (IslandController.hintPinned && IslandController.hintScreen === win.modelData?.name) {
                hintDelay.stop();
                hintGrace.stop();
                win.hintArmed = true;
            }
        }
        function onHintChanged() {
            if (IslandController.hint !== "" && IslandController.hintScreen === win.modelData?.name) {
                hintGrace.stop();
                if (IslandController.hintPinned)
                    win.hintArmed = true;
                else if (!win.hintArmed)
                    hintDelay.restart();
            } else {
                hintDelay.stop();
                hintGrace.restart();
            }
        }
    }

    Rectangle {
        id: hintPill
        readonly property bool showing: IslandController.hint !== "" && IslandController.hintScreen === win.modelData?.name && win.hintArmed
        z: 10
        x: Math.round(Math.max(8, Math.min(win.width - width - 8, IslandController.hintAt.x - width / 2)))
        y: Math.round(IslandController.hintAt.y + 8)
        width: hintText.implicitWidth + 20
        height: hintText.implicitHeight + 10
        radius: Math.min(height / 2, 14)
        color: Qt.alpha(Theme.background, 0.96)
        border.width: 1
        border.color: Theme.border
        opacity: showing ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(120)
            }
        }

        Label {
            id: hintText
            anchors.centerIn: parent
            text: Shortcuts.hint(IslandController.hint)
            font.pixelSize: Appearance.fontSize - 1
        }
    }

    // Right-click menu (IslandController.menu, items from services/Menus.qml): a small card under
    // the button, kept inside the screen. A choice runs and closes it.
    Rectangle {
        id: menuCard
        readonly property bool showing: IslandController.menu !== "" && IslandController.menuScreen === win.modelData?.name
        readonly property var items: showing ? Menus.items(IslandController.menu) : []
        onShowingChanged: if (!showing)
            win.menuGrabReady = false
        z: 11
        x: Math.round(Math.max(8, Math.min(win.width - width - 8, IslandController.menuAt.x - width / 2)))
        y: Math.round(Math.min(win.height - height - 8, IslandController.menuAt.y + 6))
        width: 250
        height: menuColumn.implicitHeight + 12
        radius: 16
        color: Qt.alpha(Theme.background, 0.97)
        border.width: 1
        border.color: Theme.border
        opacity: showing ? 1 : 0
        visible: opacity > 0.01
        scale: showing ? 1 : 0.96
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(110)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(160)
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: menuColumn
            x: 6
            y: 6
            width: menuCard.width - 12

            Repeater {
                model: menuCard.items

                Item {
                    id: entry
                    required property var modelData
                    readonly property bool heading: modelData.section !== undefined
                    width: menuColumn.width
                    height: heading ? 26 : 32

                    Rectangle {
                        anchors.fill: parent
                        visible: !entry.heading
                        radius: 10
                        color: entryMouse.pressed ? Theme.pressed : entryMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    Row {
                        id: entryRow
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Tick column (kept for alignment when the menu has ticks).
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !entry.heading && entry.modelData.checked !== undefined
                            width: 8
                            height: 8
                            radius: 4
                            color: entry.modelData.checked ? Theme.accent : "transparent"
                            border.width: entry.modelData.checked ? 0 : 1
                            border.color: Theme.faint
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, entry.width - 40 - (entry.modelData.detail ? 60 : 0))
                            text: entry.heading ? entry.modelData.section : entry.modelData.label
                            color: entry.heading ? Theme.dim : Theme.foreground
                            font.pixelSize: entry.heading ? Appearance.fontSize - 2 : Appearance.fontSize
                            font.weight: entry.heading ? Font.DemiBold : (entry.modelData.checked ? Font.DemiBold : Font.Normal)
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !entry.heading && (entry.modelData.detail ?? "") !== ""
                            text: entry.modelData.detail ?? ""
                            color: Theme.dim
                            font.pixelSize: Appearance.fontSize - 2
                        }
                    }

                    MouseArea {
                        id: entryMouse
                        anchors.fill: parent
                        enabled: !entry.heading
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const run = entry.modelData.action;
                            IslandController.closeMenu();
                            if (run)
                                run();
                        }
                    }
                }
            }
        }
    }

    Island {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: ySpring.value
        mode: win.displayMode
        focus: true
        Keys.onEscapePressed: IslandController.back()
        // Clock pill: left click opens the calendar, right click the expanded island. Expanded:
        // any click on empty space closes it (a click on its time opens the calendar).
        onEmptyClicked: button => {
            if (IslandState.isSurface(mode) || IslandState.isTransient(mode))
                return;
            if (mode === IslandState.clock && button === Qt.LeftButton)
                IslandController.open(IslandState.calendar);
            else
                IslandController.togglePin();
        }
    }
}
