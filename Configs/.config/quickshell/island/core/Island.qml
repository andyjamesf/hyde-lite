import QtQuick
import qs.island.config
import qs.island.components

// The single surface. Width, height and radius follow the natural size of the current mode's
// content through critical springs (core/IslandSurface.qml); the content cross-fades inside the
// same clip, so it always looks like the same piece transforming itself.
IslandSurface {
    id: island

    required property string mode
    readonly property bool hovered: hover.hovered

    // A click on empty space (the contents' buttons keep their own clicks): Qt.LeftButton or
    // Qt.RightButton.
    signal emptyClicked(int button)

    // Content of the current mode (the target of the shape).
    readonly property Item content: slots.find(s => s.current)?.item ?? null
    readonly property var slots: [weatherSlot, notepadSlot, overviewSlot, clockSlot, expandedSlot, volumeSlot, micSlot, brightnessSlot, notificationSlot, screenshotSlot, launcherSlot, controlSlot, themeSlot, wallpaperSlot, powerSlot, settingsSlot, authSlot, calendarSlot, agentSlot, aiSlot]
    // Modes that share the control center's content (the pages slide inside it).
    readonly property var controlModes: [IslandState.controlCenter].concat(IslandState.subviews)

    targetWidth: Math.max(Pill.minWidth, content?.implicitWidth ?? 0)
    targetHeight: Math.max(Pill.height, content?.implicitHeight ?? 0)
    // Pill while low; on large surfaces, generous but not circular corners.
    maxRadius: content?.islandRadius ?? 26

    // When leaving a surface with text input (the field had the focus), the focus returns to the
    // island so Esc keeps reaching the window's Keys.onEscapePressed.
    onModeChanged: {
        if (!IslandState.keyboardModes.includes(mode))
            forceActiveFocus();
    }

    HoverHandler {
        id: hover
    }

    // Click on empty space (the contents' buttons sit on top and keep their own clicks).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => island.emptyClicked(mouse.button)
    }

    ModeSlot {
        id: weatherSlot
        mode: IslandState.weather
        current: island.mode === mode
        sourceComponent: WeatherView {}
    }
    ModeSlot {
        id: notepadSlot
        mode: IslandState.notepad
        current: island.mode === mode
        sourceComponent: NotepadView {}
    }
    ModeSlot {
        id: overviewSlot
        mode: IslandState.overview
        current: island.mode === mode
        sourceComponent: OverviewView {}
    }
    ModeSlot {
        id: clockSlot
        mode: IslandState.clock
        current: island.mode === mode
        sourceComponent: ClockView {}
    }
    ModeSlot {
        id: expandedSlot
        mode: IslandState.expanded
        current: island.mode === mode
        sourceComponent: ExpandedView {}
    }
    ModeSlot {
        id: volumeSlot
        mode: IslandState.volume
        current: island.mode === mode
        sourceComponent: Osd {
            kind: "volume"
        }
    }
    ModeSlot {
        id: micSlot
        mode: IslandState.mic
        current: island.mode === mode
        sourceComponent: Osd {
            kind: "mic"
        }
    }
    ModeSlot {
        id: brightnessSlot
        mode: IslandState.brightness
        current: island.mode === mode
        sourceComponent: Osd {
            kind: "brightness"
        }
    }
    ModeSlot {
        id: notificationSlot
        mode: IslandState.notification
        current: island.mode === mode
        // Reads the notification from IslandController.payload.
        sourceComponent: NotificationView {}
    }
    ModeSlot {
        id: screenshotSlot
        mode: IslandState.screenshot
        current: island.mode === mode
        // Reads the capture from services/Screenshot.qml.
        sourceComponent: ScreenshotView {}
    }
    ModeSlot {
        id: launcherSlot
        mode: IslandState.launcher
        current: island.mode === mode
        // The Loader is a focus scope: with focus, the search field inside gets the keyboard.
        focus: current
        // Pinned to the top (not the centre): while the island grows, the search stays in place and
        // the list is revealed below it.
        anchors.centerIn: undefined
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: LauncherView {
            open: launcherSlot.current
        }
    }

    ModeSlot {
        id: controlSlot
        mode: IslandState.controlCenter
        // One content for the main page and the subviews: switching between them does not
        // cross-fade, the pages slide inside the view.
        current: island.controlModes.includes(island.mode)
        // Pinned to the top: while growing, the header stays in place and the rest is revealed below.
        anchors.centerIn: undefined
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: ControlCenterView {
            page: island.mode
            open: controlSlot.current
            // The password field released the focus: back to the island (so Esc reaches it).
            onReleaseFocus: island.forceActiveFocus()
        }
    }

    ModeSlot {
        id: themeSlot
        mode: IslandState.theme
        current: island.mode === mode
        // The Loader is a focus scope: with focus, the picker inside gets the arrow keys.
        focus: current
        // Pinned to the top: while growing, the header stays in place and the grid is revealed below.
        anchors.centerIn: undefined
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: ThemePickerView {
            open: themeSlot.current
        }
    }
    ModeSlot {
        id: wallpaperSlot
        mode: IslandState.wallpaper
        current: island.mode === mode
        focus: current
        anchors.centerIn: undefined
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: WallpaperPickerView {
            open: wallpaperSlot.current
        }
    }
    ModeSlot {
        id: powerSlot
        mode: IslandState.power
        current: island.mode === mode
        focus: current
        sourceComponent: PowerView {
            open: powerSlot.current
        }
    }
    ModeSlot {
        id: settingsSlot
        mode: IslandState.settings
        current: island.mode === mode
        focus: current
        anchors.centerIn: undefined
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        sourceComponent: SettingsView {
            open: settingsSlot.current
        }
    }
    ModeSlot {
        id: calendarSlot
        mode: IslandState.calendar
        current: island.mode === mode
        focus: current
        sourceComponent: CalendarView {
            open: calendarSlot.current
        }
    }
    ModeSlot {
        id: authSlot
        mode: IslandState.auth
        current: island.mode === mode
        focus: current
        sourceComponent: AuthView {
            open: authSlot.current
        }
    }
    ModeSlot {
        id: agentSlot
        mode: IslandState.agent
        current: island.mode === mode
        focus: current
        sourceComponent: AgentView {
            open: agentSlot.current
        }
    }
    ModeSlot {
        id: aiSlot
        mode: IslandState.ai
        current: island.mode === mode
        sourceComponent: AiUsageView {
            open: aiSlot.current
        }
    }
}
