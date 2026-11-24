import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.components
import qs.bar.services

// Quick notes as a window of its own: a card in the middle of the screen that holds a NotesView (the
// page, shared with the control centre's Notes tab). Used when the tabs are switched off
// (config.json: controlCenter.tabs).
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property bool open: ShellState.notesOpen && (ShellState.notesScreen === "" || ShellState.notesScreen === modelData.name)

    screen: modelData
    visible: true
    implicitWidth: 700
    implicitHeight: 480
    exclusiveZone: 0
    color: "transparent"
    mask: Region {
        item: win.open ? card : null
    }

    WlrLayershell.namespace: "quickshell:notes"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive: a popup under the bar cannot take the keyboard, and the page has to accept typing
    // straight away.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The grab only starts once the window is already open on screen (see PowerMenu).
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
        onCleared: view.close()
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.shapeXL
        color: Theme.alpha(Theme.surfaceContainer, 0.97)
        border.width: 1
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        visible: win.open || opacity > 0

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
        Behavior on scale {
            NumberAnim {
                easing.bezierCurve: Anim.emphasized
            }
        }

        NotesView {
            id: view
            anchors.fill: parent
            open: win.open
            onCloseRequested: ShellState.notesOpen = false
        }
    }
}
