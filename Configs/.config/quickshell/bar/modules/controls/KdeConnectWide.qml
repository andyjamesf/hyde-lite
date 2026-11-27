import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// KDE Connect filling a tab of the control centre: one card per paired device, packed at the top.
Item {
    id: root

    implicitHeight: column.implicitHeight + 24

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            icon: "devices"
            title: "KDE Connect"
            subtitle: `${KdeConnect.reachableCount} reachable`
            IconButton { icon: "refresh"; size: 30; tooltip: "Refresh"; onClicked: KdeConnect.refresh() }
            IconButton { icon: "open_in_new"; size: 30; tooltip: "Open app"; onClicked: KdeConnect.openApp() }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            columns: 2
            columnSpacing: 12
            rowSpacing: 10

            Repeater {
                model: KdeConnect.devices

                Rectangle {
                    id: deviceCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    radius: Theme.shapeLarge
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.border
                    opacity: modelData.reachable ? 1 : 0.5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5
                        StyledText {
                            Layout.fillWidth: true
                            text: String(deviceCard.modelData.name ?? "Unknown device")
                            textFormat: Text.PlainText
                            font.pixelSize: Theme.titleMedium
                            color: Theme.text
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: deviceCard.modelData.battery < 0 ? (deviceCard.modelData.reachable ? "Connected" : "Not reachable") : `Battery ${deviceCard.modelData.battery}%${deviceCard.modelData.charging ? " · charging" : ""}`
                            font.pixelSize: Theme.labelSmall
                            color: Theme.textDim
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: false
                            visible: deviceCard.modelData.reachable
                            spacing: 8
                            IconButton { icon: "notifications_active"; size: 36; tonal: true; tooltip: "Ring"; onClicked: KdeConnect.ring(deviceCard.modelData.id) }
                            IconButton { icon: "send"; size: 36; tonal: true; tooltip: "Ping"; onClicked: KdeConnect.ping(deviceCard.modelData.id) }
                            IconButton { icon: "content_paste"; size: 36; tonal: true; tooltip: "Send clipboard"; onClicked: KdeConnect.sendClipboard(deviceCard.modelData.id) }
                            IconButton { icon: "attach_file"; size: 36; tonal: true; tooltip: "Send file"; onClicked: KdeConnect.browseFile(deviceCard.modelData.id, "controlCenter") }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: KdeConnect.devices.length === 0
            Layout.fillWidth: true
            text: KdeConnect.installed ? "No paired devices yet. Open KDE Connect on your phone and connect both devices to the same network." : "KDE Connect is not installed."
            font.pixelSize: Theme.labelSmall
            color: Theme.textFaint
            wrapMode: Text.WordWrap
        }

        StyledText {
            visible: KdeConnect.lastError !== ""
            Layout.fillWidth: true
            text: `Last action failed: ${KdeConnect.lastError}`
            color: Theme.error
            font.pixelSize: Theme.labelSmall
            wrapMode: Text.WordWrap
        }

        // Takes the leftover height, so the header and the cards stay together at the top.
        Item {
            Layout.fillHeight: true
        }
    }
}
