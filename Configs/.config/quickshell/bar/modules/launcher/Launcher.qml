import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.components
import qs.bar.services

// The launcher as a window of its own: a card centred on the screen that holds a LauncherView (the
// content, shared with the control centre's tabs). Opened by `launcher` IPC and the launcher keys
// when the control centre's tabs are switched off (config.json: controlCenter.tabs).
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property bool open: ShellState.launcherOpen && (ShellState.launcherScreen === "" || ShellState.launcherScreen === modelData.name)

    screen: modelData
    visible: true
    implicitWidth: 480
    implicitHeight: 560
    exclusiveZone: 0
    color: "transparent"
    mask: Region {
        item: win.open ? card : null
    }

    WlrLayershell.namespace: "quickshell:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The grab only starts once the window is already open on screen (with exclusive keyboard focus,
    // activating it in the same instant made Hyprland cancel it at once, closing the launcher).
    property bool grabReady: false

    onOpenChanged: grabReady = false

    Timer {
        running: win.open && !win.grabReady
        interval: 60
        onTriggered: win.grabReady = true
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open && win.grabReady
        onCleared: ShellState.launcherOpen = false
    }

    Rectangle {
        id: card

        width: parent.width
        height: Math.min(parent.height, view.implicitHeight)
        radius: Theme.shapeXL
        color: Theme.alpha(Theme.surfaceContainer, Theme.panelOpacity)
        border.width: 1
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        // Visible right when opening (opacity is still 0): without this the window's input region
        // was empty at that instant and Hyprland cancelled the focus grab, closing the launcher.
        visible: win.open || opacity > 0

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
        Behavior on scale {
            NumberAnim {
                duration: Anim.fast
                easing.bezierCurve: Anim.emphasized
            }
        }

        LauncherView {
            id: view
            anchors.fill: parent
            open: win.open
            onCloseRequested: ShellState.launcherOpen = false
        }
    }
}
