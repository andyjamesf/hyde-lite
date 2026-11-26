import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// LocalSend: the background receiver's status, pending requests waiting for
// a decision, a device picker and a file browser to send, and recent
// activity. No drag-and-drop: unreliable from an outside app onto a
// layer-shell popup on Hyprland/wlroots (see shared/services/LocalSend.qml).
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
        visible: LocalSend.pending.length > 0
        text: "Waiting for a decision"
    }

    Repeater {
        model: LocalSend.pending

        ListRow {
            id: pendingRow
            required property var modelData
            Layout.fillWidth: true
            icon: "help"
            title: modelData.alias || "Unknown device"
            subtitle: `${modelData.fileCount} file${modelData.fileCount === 1 ? "" : "s"} · ${LocalSend.formatBytes(modelData.totalBytes)}${modelData.verified ? "" : " · unverified"}`

            IconButton {
                icon: "close"
                size: 28
                color: Theme.textDim
                onClicked: LocalSend.answer(pendingRow.modelData.sessionId, "decline")
            }
            IconButton {
                visible: pendingRow.modelData.verified
                icon: "person_add"
                size: 28
                color: Theme.textDim
                onClicked: LocalSend.answer(pendingRow.modelData.sessionId, "accept_and_pair")
            }
            IconButton {
                icon: "check"
                size: 28
                color: Theme.primary
                onClicked: LocalSend.answer(pendingRow.modelData.sessionId, "accept")
            }
        }
    }

    SectionLabel {
        text: "Send a file"
    }

    StyledText {
        visible: LocalSend.devices.length === 0
        Layout.fillWidth: true
        text: "No devices found yet on the network."
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: LocalSend.devices

        ListRow {
            required property var modelData
            Layout.fillWidth: true
            icon: modelData.paired ? "verified" : "devices"
            title: modelData.alias || modelData.host
            subtitle: modelData.host
            highlighted: LocalSend.selectedTarget === modelData.alias
            onClicked: LocalSend.selectedTarget = LocalSend.selectedTarget === modelData.alias ? "" : modelData.alias
        }
    }

    StyledText {
        visible: LocalSend.selectedTarget !== ""
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: LocalSend.sendBusy ? "Sending…" : `Sending to ${LocalSend.selectedTarget}`
        font.pixelSize: Theme.labelSmall
        color: Theme.textDim
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8

        IconButton {
            icon: "folder_open"
            size: 36
            tonal: true
            tooltip: "Browse…"
            onClicked: LocalSend.browseFile("bar")
        }

        StyledTextField {
            id: pathField
            Layout.fillWidth: true
            placeholder: "Or type a path…"
            // Opening the picker's window clears the popout's focus grab,
            // which closes this whole panel before a file is even chosen; a
            // path picked earlier is read once here, in whichever instance
            // of this panel happens to open next (see LocalSend.pickedPath).
            Component.onCompleted: {
                if (LocalSend.pickedPath !== "") {
                    text = LocalSend.pickedPath;
                    LocalSend.pickedPath = "";
                }
            }
            onAccepted: sendButton.clicked()
        }

        IconButton {
            id: sendButton
            icon: "send"
            size: 36
            tonal: true
            enabled: LocalSend.selectedTarget !== "" && pathField.text !== "" && !LocalSend.sendBusy
            onClicked: {
                LocalSend.sendFiles(LocalSend.selectedTarget, [pathField.text]);
                pathField.text = "";
            }
        }
    }

    StyledText {
        visible: LocalSend.lastSendError !== ""
        Layout.fillWidth: true
        text: `Last send failed: ${LocalSend.lastSendError}`
        font.pixelSize: Theme.labelSmall
        color: Theme.error
        wrapMode: Text.WordWrap
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
}
