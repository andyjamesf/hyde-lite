pragma ComponentBehavior: Bound
import QtQuick
import qs.island.config
import qs.shared.icons
import qs.island.theme
import qs.shared.services

// LocalSend subview (shared/services/LocalSend.qml): requests waiting for an answer, the nearby devices
// (click one to pick it), a path to send to it (typed, or from the system's file picker) and the recent
// activity. The picker's window closes the island; Shell.qml opens this page again with the picked file.
Item {
    id: root

    readonly property int pad: ControlCenter.padding
    readonly property int rowHeight: ControlCenter.listRowHeight
    readonly property int maxRows: ControlCenter.maxListRows
    readonly property int historyRows: 4
    readonly property bool canSend: LocalSend.selectedTarget !== "" && pathField.text.trim() !== "" && !LocalSend.sendBusy

    // The path field released the focus: back to the island (so Esc reaches it).
    signal releaseFocus

    implicitWidth: ControlCenter.width
    implicitHeight: column.implicitHeight + 10 + pad

    // The picked file (see LocalSend.pickedPath).
    function showPicked() {
        if (LocalSend.pickedPath !== "" || LocalSend.sendBusy)
            pathField.text = LocalSend.pickedPath;
    }

    function send() {
        if (!canSend)
            return;
        LocalSend.sendFiles(LocalSend.selectedTarget, [pathField.text.trim()]);
        pathField.text = "";
        releaseFocus();
    }

    function plural(n) {
        return `${n} file${n === 1 ? "" : "s"}`;
    }

    function historyText(entry) {
        if (entry.kind === "declined")
            return `Declined ${plural(entry.fileCount)}`;
        if (entry.cancelled)
            return "Cancelled";
        if (entry.kind === "partial")
            return `${entry.fileCount} received, ${entry.failedCount} failed`;
        return `${plural(entry.fileCount)} received`;
    }

    Component.onCompleted: showPicked()

    Connections {
        target: LocalSend
        function onPickedPathChanged() {
            root.showPicked();
        }
    }

    component SectionText: Label {
        leftPadding: 6
        textFormat: Text.PlainText
        color: Theme.dim
        font.pixelSize: Appearance.fontSize - 1
    }

    Column {
        id: column
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        spacing: 8

        CcHeader {
            width: parent.width
            title: "LocalSend"

            // Restarts the receiver (also the way to try again once localsend-cli is installed).
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                onClicked: LocalSend.restart()

                Glyph {
                    kind: "refresh"
                    size: 16
                    color: Theme.dim
                }
            }
        }

        SectionText {
            width: parent.width
            wrapMode: Text.WordWrap
            text: LocalSend.installError ? "localsend-cli not found in ~/.local/bin" : LocalSend.ready ? `Receiving as "${LocalSend.alias}" on port ${LocalSend.port}` : "Starting…"
            color: LocalSend.installError ? Theme.danger : Theme.dim
        }

        // Requests waiting for an answer; the receiver declines them after 60 s.
        Repeater {
            model: LocalSend.pending

            Rectangle {
                id: request

                required property var modelData

                width: column.width
                implicitHeight: requestColumn.implicitHeight + 16
                radius: 16
                color: Theme.surface

                Column {
                    id: requestColumn
                    x: 12
                    y: 8
                    width: parent.width - 24
                    spacing: 4

                    Label {
                        width: parent.width
                        text: request.modelData.alias || "Unknown device"
                        textFormat: Text.PlainText
                        font.weight: Font.DemiBold
                    }
                    Label {
                        width: parent.width
                        text: `${root.plural(request.modelData.fileCount)} · ${LocalSend.formatBytes(request.modelData.totalBytes)}${request.modelData.verified ? "" : " · unverified"}`
                        color: Theme.dim
                        font.pixelSize: Appearance.fontSize - 1
                    }
                    Row {
                        spacing: 8

                        CcTextButton {
                            primary: true
                            text: "Accept"
                            onClicked: LocalSend.answer(request.modelData.sessionId, "accept")
                        }
                        CcTextButton {
                            text: "Accept and pair"
                            onClicked: LocalSend.answer(request.modelData.sessionId, "accept_and_pair")
                        }
                        CcTextButton {
                            text: "Decline"
                            onClicked: LocalSend.answer(request.modelData.sessionId, "decline")
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            height: 44
            visible: LocalSend.ready && LocalSend.devices.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "No devices found yet"
            color: Theme.faint
        }

        ListView {
            id: deviceList
            width: parent.width
            height: Math.min(contentHeight, root.maxRows * root.rowHeight)
            visible: LocalSend.devices.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: LocalSend.devices

            delegate: Item {
                id: device

                required property var modelData
                readonly property bool picked: LocalSend.selectedTarget === modelData.alias

                width: deviceList.width
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 16
                    color: deviceMouse.pressed ? Theme.pressed : deviceMouse.containsMouse ? Theme.hover : "transparent"
                }

                MouseArea {
                    id: deviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LocalSend.selectedTarget = device.picked ? "" : device.modelData.alias
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: device.modelData.alias || "Unknown device"
                        textFormat: Text.PlainText
                        font.weight: device.picked ? Font.DemiBold : Font.Normal
                        color: device.picked ? Theme.accent : Theme.foreground
                    }
                    Label {
                        width: parent.width
                        text: [device.picked ? "Selected" : "", device.modelData.paired ? "Paired" : "", device.modelData.host].filter(s => s !== "").join("  ·  ")
                        textFormat: Text.PlainText
                        color: Theme.dim
                        font.pixelSize: Math.max(Appearance.fontSize - 2, Appearance.minFontSize)
                    }
                }
            }
        }

        SectionText {
            width: parent.width
            visible: LocalSend.ready || LocalSend.sendBusy
            text: LocalSend.sendBusy ? "Sending…" : LocalSend.selectedTarget !== "" ? `Send to ${LocalSend.selectedTarget}` : "Pick a device to send to"
        }

        Row {
            width: parent.width
            visible: LocalSend.ready || LocalSend.sendBusy
            spacing: 8

            CcTextButton {
                id: browseButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Browse…"
                onClicked: LocalSend.browseFile("island")
            }

            Field {
                id: pathField
                width: parent.width - browseButton.width - sendButton.width - 2 * parent.spacing
                placeholder: "Or type a path…"
                onAccepted: root.send()
                input.Keys.onEscapePressed: root.releaseFocus()
            }

            CcTextButton {
                id: sendButton
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                enabled: root.canSend
                text: "Send"
                onClicked: root.send()
            }
        }

        SectionText {
            width: parent.width
            visible: LocalSend.lastSendError !== ""
            wrapMode: Text.WordWrap
            text: `Last send failed: ${LocalSend.lastSendError}`
            color: Theme.danger
        }

        SectionText {
            width: parent.width
            visible: LocalSend.history.length > 0
            text: "Recent activity"
        }

        Repeater {
            model: LocalSend.history.slice(0, root.historyRows)

            Label {
                required property var modelData

                width: column.width
                leftPadding: 12
                text: `${modelData.alias || "Unknown device"}  ·  ${root.historyText(modelData)}`
                textFormat: Text.PlainText
                font.pixelSize: Appearance.fontSize - 1
            }
        }
    }
}
