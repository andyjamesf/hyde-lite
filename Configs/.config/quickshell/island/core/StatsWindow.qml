import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.island.config
import qs.island.components
import qs.island.services
import qs.shared.services
import qs.shared.controlcenter
import qs.island.theme

// The PC statistics detached from the control center (the button on the System page): a small
// floating card above every window, so the numbers can sit over an app. Drag it by the title bar;
// the buttons make it compact (CPU, memory, GPU, temperatures), put it back in the control center
// or close it. Screen, position and size mode are remembered (services/SysStats.qml). It never
// takes the keyboard.
PanelWindow {
    id: win

    required property var modelData

    // On the screen it was detached on (or the first one, if that screen is gone).
    readonly property bool here: StatsWindowPrefs.detached && (StatsWindowPrefs.screen === modelData?.name || (!Quickshell.screens.some(s => s.name === StatsWindowPrefs.screen) && modelData === Quickshell.screens[0]))

    // Top-left corner (logical pixels); dragging moves it, the release saves it.
    property real px: StatsWindowPrefs.x >= 0 ? StatsWindowPrefs.x : modelData?.width - implicitWidth - 24
    property real py: StatsWindowPrefs.y >= 0 ? StatsWindowPrefs.y : 64

    screen: modelData
    visible: here
    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(Math.max(0, Math.min(modelData?.width - implicitWidth, px)))
        top: Math.round(Math.max(0, Math.min(modelData?.height - implicitHeight, py)))
    }
    implicitWidth: StatsWindowPrefs.compact ? 320 : 400
    // At most three quarters of the screen tall (the rest scrolls).
    implicitHeight: Math.min(card.contentHeight + 2, Math.round(modelData?.height * 0.75))
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell:stats"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: card
        // No cap of its own: `win.implicitHeight` already clamps the window to three quarters of
        // the screen and the Flickable scrolls whatever does not fit. The 900 that used to be here
        // only ever bound on a screen over 1200 logical pixels tall, where it stopped the window
        // from using the three quarters it is allowed.
        readonly property real contentHeight: bar.height + view.implicitHeight + 24
        anchors.fill: parent
        radius: 22
        color: Qt.alpha(Theme.background, Theme.islandOpacity)
        border.width: 1
        border.color: Theme.border

        // Title bar: drag handle, title and the buttons.
        Item {
            id: bar
            x: 14
            y: 6
            width: parent.width - 28
            height: 38

            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property real sx: 0
                property real sy: 0
                onPressed: event => {
                    sx = event.x;
                    sy = event.y;
                }
                // The window moves under the pointer, so each step is measured from the press point.
                onPositionChanged: event => {
                    if (!pressed)
                        return;
                    win.px = Math.max(0, Math.min(win.modelData?.width - win.implicitWidth, win.margins.left + event.x - sx));
                    win.py = Math.max(0, Math.min(win.modelData?.height - win.implicitHeight, win.margins.top + event.y - sy));
                }
                onReleased: StatsWindowPrefs.moveTo(win.px, win.py)
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F061A}"
                    font.family: Appearance.nerdFont
                    font.pixelSize: 16
                    elide: Text.ElideNone
                    color: Theme.accent
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "System"
                    font.weight: Font.DemiBold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        {
                            glyph: StatsWindowPrefs.compact ? "\u{F0616}" : "\u{F0615}",
                            run: () => StatsWindowPrefs.setCompact(!StatsWindowPrefs.compact)
                        },
                        {
                            glyph: "\u{F10AC}",
                            run: () => {
                                StatsWindowPrefs.attach();
                                IslandController.open(IslandState.system);
                            }
                        },
                        {
                            glyph: "\u{F0156}",
                            run: () => StatsWindowPrefs.attach()
                        }
                    ]
                    IconButton {
                        id: barButton
                        required property var modelData
                        size: 28
                        onClicked: modelData.run()
                        Label {
                            text: barButton.modelData.glyph
                            font.family: Appearance.nerdFont
                            font.pixelSize: 15
                            elide: Text.ElideNone
                            color: Theme.icon
                        }
                    }
                }
            }
        }

        Flickable {
            x: 14
            y: bar.y + bar.height + 4
            width: parent.width - 28
            height: parent.height - y - 12
            contentHeight: view.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            SysStatsView {
                id: view

                accent: Theme.accent
                accentContent: Theme.accentContent
                border: Theme.border
                danger: Theme.danger
                dim: Theme.dim
                faint: Theme.faint
                foreground: Theme.foreground
                hover: Theme.hover
                fontFamily: Appearance.font
                fontSize: Appearance.fontSize
                animationDuration: Animations.duration(300)
                width: parent.width
                compact: StatsWindowPrefs.compact
                sortBy: SysStats.sortBy
                onSortByChanged: SysStats.sortBy = sortBy
            }
        }

        Label {
            anchors.centerIn: parent
            visible: !SysStats.data
            text: "Reading…"
            color: Theme.dim
        }
    }
}
