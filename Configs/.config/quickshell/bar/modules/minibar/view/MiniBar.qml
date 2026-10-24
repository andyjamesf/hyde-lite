import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.services
import qs.bar.modules.bar
import qs.bar.modules.minibar.model

// The minimal bar of one screen: a slimmer bar that takes the normal one's place while it is
// switched on. Everything it shows comes from model/MiniBarConfig.qml, and it hosts the same
// widgets as the normal bar, in the same Island container, so no widget exists twice. Its own
// measurements reach those widgets through services/BarLayout.qml, which applies them while this
// bar stands in for the normal one.
//
// MiniBarWindows.qml creates one of these per screen; it never exists while the bar is off.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    // WorkspacesWidget and ActiveWindowWidget read the monitor off the bar window they are in.
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool atTop: BarLayout.atTop
    readonly property int gap: BarLayout.margin
    // The strip is only drawn in the "continuous" style: "islands" lets each group draw its own
    // background (BarLayout.islands is then true) and "none" draws nothing at all.
    readonly property bool strip: MiniBarConfig.style === "continuous"

    screen: modelData
    anchors {
        top: bar.atTop
        bottom: !bar.atTop
        left: true
        right: true
    }
    implicitHeight: BarLayout.height + gap
    color: "transparent"
    // `qs ipc call bar hide` hides whichever bar is in use.
    visible: !ShellState.barHidden
    // 0: the bar floats over the windows and a window can use the whole screen
    // (MiniBarConfig.reserveSpace). Anything else and the compositor keeps the windows below it.
    exclusiveZone: MiniBarConfig.reserveSpace ? bar.implicitHeight : 0

    WlrLayershell.namespace: "quickshell:minibar"
    WlrLayershell.layer: WlrLayer.Top

    // The normal bar's inhibitor goes away with the normal bar, and an inhibitor needs a window:
    // without this one `qs ipc call idle toggle` (and the "idle" widget) would do nothing here.
    IdleInhibitor {
        window: bar
        enabled: ShellState.idleInhibited
    }

    Rectangle {
        anchors.fill: parent
        visible: bar.strip
        color: BarLayout.pillColor
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: bar.atTop ? bar.gap : 0
        anchors.bottomMargin: bar.atTop ? 0 : bar.gap
        anchors.leftMargin: bar.gap > 0 ? bar.gap : 4
        anchors.rightMargin: bar.gap > 0 ? bar.gap : 4

        Section {
            id: leftSection
            anchors.left: parent.left
            barRef: bar
            islandList: MiniBarConfig.left
        }

        // Centred, but pushed aside when the sides need the space; if it does not fit between
        // them at all it hides instead of overlapping (the same rule as the normal bar).
        Section {
            visible: parent.width - leftSection.width - rightSection.width - 2 * BarLayout.spacing >= implicitWidth
            x: Math.max(leftSection.width + BarLayout.spacing, Math.min((parent.width - width) / 2, rightSection.x - width - BarLayout.spacing))
            barRef: bar
            islandList: MiniBarConfig.center
        }

        Section {
            id: rightSection
            anchors.right: parent.right
            barRef: bar
            islandList: MiniBarConfig.right
        }
    }

    // One group of modules per entry of the list, in a row (see MiniBarConfig, section 3).
    component Section: Row {
        id: section

        property var islandList: []
        property var barRef

        height: parent.height
        spacing: BarLayout.spacing

        Repeater {
            model: section.islandList

            Island {
                required property var modelData
                widgets: modelData
                bar: section.barRef
            }
        }
    }
}
