import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.services

// Compact power menu: a centered card with the session actions. The actions that close everything
// (log out, reboot, shut down) require a second click/Enter to confirm.
// Keyboard: ←/→ select · Enter run · Esc close · shortcuts: B (lock) S (suspend)
// H (hibernate) L (log out) R (reboot) D (shut down).
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property bool open: ShellState.powerMenuOpen && (ShellState.powerMenuScreen === "" || ShellState.powerMenuScreen === modelData.name)
    readonly property var actions: [
        {
            icon: "lock",
            label: "Lock",
            key: Qt.Key_B,
            cmd: "loginctl lock-session",
            confirm: false
        },
        {
            icon: "bedtime",
            label: "Suspend",
            key: Qt.Key_S,
            cmd: "systemctl suspend",
            confirm: false
        },
        {
            icon: "downloading",
            label: "Hibernate",
            key: Qt.Key_H,
            cmd: "systemctl hibernate",
            confirm: false
        },
        {
            icon: "logout",
            label: "Log out",
            key: Qt.Key_L,
            cmd: "hyprctl dispatch 'hl.dsp.exit()'",
            confirm: true
        },
        {
            icon: "restart_alt",
            label: "Restart",
            key: Qt.Key_R,
            cmd: "systemctl reboot",
            confirm: true
        },
        {
            icon: "power_settings_new",
            label: "Shut down",
            key: Qt.Key_D,
            cmd: "systemctl poweroff",
            confirm: true
        }
    ]
    property int current: 0
    // The selection only follows the mouse when it moves (not when the menu opens under the cursor).
    property point lastMouse: Qt.point(-1, -1)
    property real openedAt: 0
    // Action awaiting confirmation (index), or -1.
    property int armed: -1

    screen: modelData
    visible: true
    implicitWidth: row.implicitWidth + 40
    implicitHeight: 170
    exclusiveZone: 0
    color: "transparent"
    mask: Region {
        item: win.open ? card : null
    }

    WlrLayershell.namespace: "quickshell:powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The grab only starts once the window is already open: with exclusive keyboard focus,
    // activating it in the same instant made Hyprland cancel it at once (and the menu closed).
    property bool grabReady: false

    // Only created when it opens (saves memory): the setup runs on creation and on reopening.
    function init() {
        grabReady = false;
        if (open) {
            current = 0;
            armed = -1;
            lastMouse = Qt.point(-1, -1);
            openedAt = Date.now();
            focusTimer.restart();
        }
    }

    Component.onCompleted: init()
    onOpenChanged: init()

    Timer {
        running: win.open && !win.grabReady
        interval: 60
        onTriggered: win.grabReady = true
    }

    function close() {
        ShellState.powerMenuOpen = false;
    }

    function trigger(i) {
        const a = actions[i];
        current = i;
        if (a.confirm && armed !== i) {
            armed = i;
            disarm.restart();
            return;
        }
        close();
        Utils.run(a.cmd);
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: card.forceActiveFocus()
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: win.armed = -1
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open && win.grabReady
        onCleared: win.close()
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.shapeXL
        color: Theme.alpha(Theme.surfaceContainer, 0.96)
        border.width: 1
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        // Visible right when opening, so the input region isn't empty when the focus grab starts.
        visible: win.open || opacity > 0
        focus: win.open

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

        Keys.onEscapePressed: win.close()
        Keys.onLeftPressed: {
            win.current = (win.current + win.actions.length - 1) % win.actions.length;
            win.armed = -1;
        }
        Keys.onRightPressed: {
            win.current = (win.current + 1) % win.actions.length;
            win.armed = -1;
        }
        Keys.onReturnPressed: win.trigger(win.current)
        Keys.onEnterPressed: win.trigger(win.current)
        Keys.onPressed: event => {
            const i = win.actions.findIndex(a => a.key === event.key);
            if (i >= 0) {
                win.trigger(i);
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            RowLayout {
                id: row
                spacing: 10

                Repeater {
                    model: win.actions

                    ColumnLayout {
                        id: btn

                        required property var modelData
                        required property int index
                        readonly property bool selected: index === win.current
                        readonly property bool isArmed: index === win.armed
                        readonly property bool danger: modelData.confirm

                        spacing: 6

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 72
                            implicitHeight: 72
                            radius: btn.selected ? 24 : 36
                            color: btn.isArmed ? Theme.error : btn.selected ? Theme.primary : Theme.surfaceContainerHigh

                            Behavior on radius {
                                NumberAnim {
                                    easing.bezierCurve: Anim.expressive
                                }
                            }
                            Behavior on color {
                                ColorAnim {}
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: btn.modelData.icon
                                size: 30
                                fill: btn.selected ? 1 : 0
                                color: btn.isArmed ? Theme.readable(Theme.surface, Theme.error, 4.5) : btn.selected ? Theme.onPrimary : btn.danger ? Theme.error : Theme.text
                            }

                            StateLayer {
                                anchors.fill: parent
                                radius: parent.radius
                                onPositionChanged: mouse => {
                                    const g = mapToGlobal(mouse.x, mouse.y);
                                    // Ignores the fake events from the enter animation (still cursor).
                                    if (Date.now() - win.openedAt < 300) {
                                        win.lastMouse = g;
                                        return;
                                    }
                                    const moved = win.lastMouse.x >= 0 && (Math.abs(g.x - win.lastMouse.x) > 3 || Math.abs(g.y - win.lastMouse.y) > 3);
                                    if (moved)
                                        win.current = btn.index;
                                    if (moved || win.lastMouse.x < 0)
                                        win.lastMouse = g;
                                }
                                onClicked: win.trigger(btn.index)
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.isArmed ? "Confirmar?" : btn.modelData.label
                            font.pixelSize: Theme.labelLarge
                            font.weight: btn.selected ? Font.DemiBold : Font.Normal
                            color: btn.isArmed ? Theme.error : btn.selected ? Theme.text : Theme.textDim
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: win.armed >= 0 ? "Press again to confirm" : "← → choose · Enter · Esc"
                font.pixelSize: Theme.labelMedium
                color: win.armed >= 0 ? Theme.error : Theme.textFaint
            }
        }
    }
}
