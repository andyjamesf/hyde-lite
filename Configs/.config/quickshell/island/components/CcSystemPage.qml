import QtQuick
import Quickshell
import qs.island.config
import qs.island.core
import qs.island.services
import qs.shared.services
import qs.shared.controlcenter
import qs.island.theme

// System page of the control center ("system" mode; the chip button in the header): the PC's
// statistics (components/SysStatsView.qml), refreshed every 2 seconds while on screen. The button
// on the right detaches them into a floating window over the apps (core/StatsWindow.qml).
Item {
    id: root

    property bool shown: false
    onShownChanged: SysStats.pageShown = shown
    Component.onDestruction: SysStats.pageShown = false

    readonly property int pad: ControlCenter.padding

    implicitWidth: ControlCenter.width
    implicitHeight: header.y + header.height + 6 + Math.min(view.implicitHeight, 620) + pad

    CcHeader {
        id: header
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        title: "System"

        // Detach: a floating window you can put over any app; the control center closes.
        IconButton {
            id: detachButton
            size: 32
            onClicked: {
                StatsWindowPrefs.detach(QsWindow.window?.screen?.name ?? "");
                IslandController.close();
            }
            onHoveredChanged: {
                if (hovered) {
                    IslandController.hintScreen = QsWindow.window?.screen?.name ?? "";
                    IslandController.hintAt = detachButton.mapToItem(null, detachButton.width / 2, detachButton.height);
                    IslandController.hint = "detachstats";
                } else if (IslandController.hint === "detachstats") {
                    IslandController.hint = "";
                }
            }

            Label {
                text: "\u{F03CC}"
                font.family: Appearance.nerdFont
                font.pixelSize: 17
                elide: Text.ElideNone
                color: Theme.icon
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: !SysStats.data
        text: "Reading…"
        color: Theme.dim
    }

    Flickable {
        x: root.pad
        y: header.y + header.height + 6
        width: root.width - 2 * root.pad
        height: Math.min(view.implicitHeight, 620)
        contentHeight: view.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        visible: !!SysStats.data

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
            sortBy: SysStats.sortBy
            onSortByChanged: SysStats.sortBy = sortBy
        }
    }
}
