import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.components
import qs.bar.services
import qs.bar.modules.bar
import qs.bar.modules.minibar.model
import qs.shared.services

// The minimal bar of one screen: a slimmer bar that takes the normal one's place while it is
// switched on. Everything it shows comes from model/MiniBarConfig.qml, and it hosts the same
// widgets as the normal bar, in the same group container (the `Island` QML type, which has nothing to do with the Morphing Island shell), so no widget exists twice. Its own
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
    // Space between the screen edge and the modules (MiniBarConfig.edgeGap), whatever the style.
    // -1 = just `gap`, which is 0 outside the "floating" style.
    readonly property int vgap: MiniBarConfig.edgeGap >= 0 ? MiniBarConfig.edgeGap : gap
    // The strip is only drawn in the "continuous" style: "floating" lets each group draw its own
    // background (BarLayout.islands, the code's name for floating groups, is then true) and "none" draws nothing at all.
    readonly property bool strip: MiniBarConfig.style === "continuous"

    // Auto-hide (MiniBarConfig.autoHide): the bar slides off the screen edge and leaves `peek` px
    // of itself behind. Only what the mask covers takes the pointer, so while it is hidden the
    // clicks belong to the window underneath, and moving the pointer onto that strip brings the
    // bar back. With auto-hide off it is simply always revealed.
    readonly property bool autoHide: MiniBarConfig.autoHide
    readonly property int peek: Math.max(1, MiniBarConfig.peek)
    property bool revealed: !autoHide

    screen: modelData
    anchors {
        top: bar.atTop
        bottom: !bar.atTop
        left: true
        right: true
    }
    implicitHeight: BarLayout.height + vgap
    color: "transparent"
    // `qs ipc call bar hide` hides whichever bar is in use.
    visible: !ShellState.barHidden
    // 0: the bar floats over the windows and one of them can use the whole screen
    // (MiniBarConfig.reserveSpace). A bar that hides itself never reserves space: the strip it
    // leaves behind is not worth a gap at the edge of every window.
    exclusiveZone: MiniBarConfig.reserveSpace && !bar.autoHide ? bar.implicitHeight : 0
    // What takes the pointer: the whole bar, or only the strip while it is hidden. Clicks outside
    // the mask go to the window underneath, which is what makes hiding worth anything.
    mask: Region {
        item: bar.autoHide && !bar.revealed ? edge : content
    }

    WlrLayershell.namespace: "quickshell:minibar"
    WlrLayershell.layer: WlrLayer.Top

    // The normal bar's inhibitor goes away with the normal bar, and an inhibitor needs a window:
    // without this one `qs ipc call idle toggle` (and the "idle" widget) would do nothing here.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.active
    }

    // Reveals the bar while the pointer is anywhere on it. A handler rather than a MouseArea: it
    // reports the pointer in parallel with the widgets' own mouse areas instead of competing with
    // them for it, so hovering a module does not read as "the pointer left the bar".
    HoverHandler {
        id: hover
        enabled: bar.autoHide
    }

    readonly property bool pointerOn: hover.hovered

    onPointerOnChanged: {
        if (pointerOn) {
            hideDelay.stop();
            revealed = true;
        } else if (autoHide) {
            hideDelay.restart();
        }
    }

    // Switching auto-hide off in the settings must bring the bar back at once.
    onAutoHideChanged: revealed = !autoHide

    Timer {
        id: hideDelay
        interval: Math.max(0, MiniBarConfig.hideDelay)
        // A panel of this bar being open (the calendar, the volume panel) means the owner is still
        // using it, pointer or no pointer: wait instead of sliding out from under them.
        onTriggered: {
            if (ShellState.popoutOwner !== null || ShellState.requestedMenu !== "")
                restart();
            else
                bar.revealed = false;
        }
    }

    // Everything that is drawn, so hiding is one movement of one item.
    Item {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        y: bar.revealed ? 0 : (bar.atTop ? -(height - bar.peek) : height - bar.peek)

        Behavior on y {
            NumberAnim {
                duration: Anim.normal
                easing.bezierCurve: Anim.emphasized
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: bar.strip
            color: BarLayout.pillColor
        }

        Item {
            anchors.fill: parent
            anchors.topMargin: bar.atTop ? bar.vgap : 0
            anchors.bottomMargin: bar.atTop ? 0 : bar.vgap
            anchors.leftMargin: MiniBarConfig.edgePadding >= 0 ? MiniBarConfig.edgePadding : bar.gap > 0 ? bar.gap : 4
            anchors.rightMargin: MiniBarConfig.edgePadding >= 0 ? MiniBarConfig.edgePadding : bar.gap > 0 ? bar.gap : 4

            // "none" draws no background, so the text sits on the wallpaper, whose colour is not known
            // (BarLayout.readable assumes the theme surface). A soft shadow in that surface colour keeps
            // it readable on a light wallpaper as well as a dark one.
            layer.enabled: MiniBarConfig.style === "none"
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.surface
                shadowOpacity: 1
                shadowBlur: 0.12
                shadowScale: 1.0
                shadowVerticalOffset: 1
            }

            Section {
                id: leftSection
                anchors.left: parent.left
                barRef: bar
                islandList: MiniBarState.layout.left ?? []
            }

            // Centred, but pushed aside when the sides need the space; if it does not fit between
            // them at all it hides instead of overlapping (the same rule as the normal bar).
            Section {
                visible: parent.width - leftSection.width - rightSection.width - 2 * BarLayout.spacing >= implicitWidth
                x: Math.max(leftSection.width + BarLayout.spacing, Math.min((parent.width - width) / 2, rightSection.x - width - BarLayout.spacing))
                barRef: bar
                islandList: MiniBarState.layout.center ?? []
            }

            Section {
                id: rightSection
                anchors.right: parent.right
                barRef: bar
                islandList: MiniBarState.layout.right ?? []
            }
        }
    }

    // The strip left on the screen edge while the bar is hidden: it draws nothing and exists to be
    // the mask, which is what the pointer can reach to bring the bar back.
    Item {
        id: edge

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: bar.atTop ? parent.top : undefined
        anchors.bottom: bar.atTop ? undefined : parent.bottom
        height: bar.peek
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
