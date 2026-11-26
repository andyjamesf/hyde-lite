import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// LocalSend: the background receiver's status and recent activity. Sending has no UI yet
// (see shared/services/LocalSend.qml); the hint at the bottom says the command for it.
ColumnLayout {
    id: root
    property bool backButton: false
    signal back

    width: 320
    spacing: 8

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        icon: "send_to_mobile"
        title: "LocalSend"
        subtitle: LocalSend.installError ? "Not installed" : LocalSend.ready ? `"${LocalSend.alias}" · port ${LocalSend.port}` : "Starting…"
    }

    ListRow {
        visible: LocalSend.installError
        Layout.fillWidth: true
        icon: "error"
        title: "localsend-cli not found"
        subtitle: "Expected at ~/.local/bin/localsend-cli"
        onClicked: LocalSend.restart()
    }

    SectionLabel {
        visible: LocalSend.history.length > 0
        text: "Recent activity"
    }

    Repeater {
        model: LocalSend.history

        ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: modelData.kind === "declined" ? "block" : modelData.kind === "partial" ? "warning" : modelData.cancelled ? "cancel" : "download_done"
            title: modelData.alias || "Unknown device"
            subtitle: modelData.kind === "declined" ? `Declined ${modelData.fileCount} file${modelData.fileCount === 1 ? "" : "s"} (not paired)` : modelData.cancelled ? "Cancelled" : modelData.kind === "partial" ? `${modelData.fileCount} received, ${modelData.failedCount} failed` : `${modelData.fileCount} file${modelData.fileCount === 1 ? "" : "s"} received`
            highlighted: modelData.kind === "received"
        }
    }

    StyledText {
        visible: LocalSend.history.length === 0 && !LocalSend.installError
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        text: "No activity yet."
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
    }

    SectionLabel {
        text: "Send a file"
    }

    StyledText {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        text: "localsend-cli send --to <device> <file>\n(no send UI yet — run this from a terminal)"
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
        wrapMode: Text.WordWrap
    }
}
