import QtQuick
import QtQuick.Layouts
import qs.bar.services
import qs.shared.controlcenter
import qs.shared.services

// System: the PC's statistics — load per core, memory, temperatures, storage, network and the
// processes using the most of each. The view is shared with the island
// (shared/controlcenter/SysStatsView.qml), which is where these numbers were until now; the
// colours and the text style are this shell's, passed in, because the two name their palettes
// differently.
ColumnLayout {
    id: root
    // In the control center: the header gets the back button.
    property bool backButton: false
    signal back

    width: 320
    spacing: 8

    // The script behind the numbers only runs while something is showing them.
    Component.onCompleted: SysStats.pageShown = true
    Component.onDestruction: SysStats.pageShown = false

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        icon: "monitoring"
        title: "System"
        subtitle: SysStats.data ? `${Math.round((SysStats.data.cpu?.total ?? 0) * 100)}% CPU` : "Reading…"
    }

    SysStatsView {
        Layout.fillWidth: true

        accent: Theme.primary
        accentContent: Theme.onPrimary
        border: Theme.border
        danger: Theme.error
        dim: Theme.textDim
        faint: Theme.textFaint
        foreground: Theme.text
        hover: Theme.hover
        fontFamily: Config.appearance.font
        fontSize: Theme.bodyMedium
        animationDuration: Anim.normal

        width: parent.width
        sortBy: SysStats.sortBy
        onSortByChanged: SysStats.sortBy = sortBy
    }
}
