import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// LocalSend filling a tab of the control centre: pending requests and
// sending on the left, recent activity on the right — the same kind of
// split CalendarWide does (month/agenda), sized to the tab's own width
// instead of the bar popout's fixed 320 (LocalSendPanel, still used there,
// unaffected by this file).
Item {
    id: root

    implicitHeight: Math.max(leftColumn.implicitHeight, rightColumn.implicitHeight)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 24

        ColumnLayout {
            id: leftColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 8

            PanelHeader {
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

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                implicitHeight: 64
                radius: Theme.shapeMedium
                color: fileDropArea.containsDrag ? Theme.primaryContainer : Theme.surfaceContainerHighest
                border.width: 1
                border.color: fileDropArea.containsDrag ? Theme.primary : Theme.outlineVariant

                StyledText {
                    anchors.centerIn: parent
                    text: LocalSend.selectedTarget === "" ? "Pick a device above, then drop a file here" : LocalSend.sendBusy ? "Sending…" : `Drop a file here to send to ${LocalSend.selectedTarget}`
                    font.pixelSize: Theme.labelSmall
                    color: Theme.textDim
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width - 16
                    wrapMode: Text.WordWrap
                }

                // Real file drag-and-drop from a file manager onto a layer-shell
                // popup is NOT verified in this environment (no display
                // control here) — it may need the compositor's own
                // DnD-over-layer-surface support. The pasted-path field below
                // always works as a fallback.
                DropArea {
                    id: fileDropArea
                    anchors.fill: parent
                    onDropped: event => {
                        if (LocalSend.selectedTarget === "" || !event.hasUrls)
                            return;
                        const paths = event.urls.map(u => String(u).replace(/^file:\/\//, "")).filter(p => p !== "");
                        LocalSend.sendFiles(LocalSend.selectedTarget, paths);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                StyledTextField {
                    id: pathField
                    Layout.fillWidth: true
                    placeholder: "Or paste a file path…"
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
        }

        ColumnLayout {
            id: rightColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 8

            SectionLabel {
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
                visible: LocalSend.history.length === 0
                Layout.fillWidth: true
                text: "No activity yet."
                font.pixelSize: Theme.labelSmall
                color: Theme.textFaint
            }
        }
    }
}
