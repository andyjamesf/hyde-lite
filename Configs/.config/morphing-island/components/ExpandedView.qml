import QtQuick
import qs.config
import qs.core
import qs.services
import qs.theme

// Expanded mode (hover or pin): workspaces and media on the left, time and date in the middle,
// status on the right. Both side zones have the same width so the centre is truly centred.
// Sizes: config/Expanded.qml; workspaces: config/WorkspacesConfig.qml.
Item {
    id: root

    // The workspace indicator (the pill next to the clock slides in here when the island expands).
    readonly property bool showWorkspaces: WorkspacesConfig.enabled && WorkspacesConfig.inExpanded
    // The workspaces, plus the gap before the media controls when something is playing.
    readonly property int workspacesWidth: showWorkspaces ? workspaces.implicitWidth + (media.implicitWidth > 0 ? Expanded.gutter : 0) : 0
    // Width of each side zone, the outer margin included: Expanded.sideMinWidth, or more if the
    // natural content of either does not fit (e.g. with a large pill height the media buttons get
    // bigger). The side content never reaches into the gutter next to the time.
    readonly property int side: Expanded.margin + Math.ceil(Math.max(Expanded.sideMinWidth, workspacesWidth + media.implicitWidth, status.implicitWidth))

    implicitWidth: 2 * side + center.implicitWidth + 2 * Expanded.gutter
    implicitHeight: Pill.height + Expanded.extraHeight

    // Left: workspaces, then media
    WorkspacesView {
        id: workspaces
        visible: root.showWorkspaces
        anchors.left: parent.left
        anchors.leftMargin: Expanded.margin
        anchors.verticalCenter: parent.verticalCenter
    }

    MediaZone {
        id: media
        anchors.left: parent.left
        anchors.leftMargin: Expanded.margin + root.workspacesWidth
        anchors.verticalCenter: parent.verticalCenter
        zoneWidth: root.side - Expanded.margin - root.workspacesWidth
    }

    Column {
        id: center
        anchors.centerIn: parent
        spacing: 0

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.time
            font.pixelSize: Appearance.fontSize + 3
            font.weight: Font.DemiBold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.date
            font.pixelSize: Appearance.fontSize - 2
            color: Theme.dim
        }
    }

    // The time and date open the calendar.
    MouseArea {
        anchors.fill: center
        cursorShape: Qt.PointingHandCursor
        onClicked: IslandController.open(IslandState.calendar)
    }

    // Right: status
    StatusZone {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: Expanded.margin
        anchors.verticalCenter: parent.verticalCenter
        zoneWidth: root.side - Expanded.margin
        // With the status pill on, it slides in here: show what it showed, so nothing disappears.
        icons: StatusPillConfig.enabled ? StatusPillConfig.icons : Expanded.statusIcons
        batteryPercent: !StatusPillConfig.enabled || StatusPillConfig.batteryPercent
        batteryTime: StatusPillConfig.enabled && StatusPillConfig.batteryTime
        alwaysShowBell: StatusPillConfig.alwaysShowBell
        // Shortcut buttons in the space the left side leaves free on this side.
        extras: Expanded.extraButtons
    }
}
