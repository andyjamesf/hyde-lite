import QtQuick
import qs.island.config
import qs.shared.icons
import qs.island.theme
import qs.shared.services

Item {
    id: root

    readonly property int pad: ControlCenter.padding
    implicitWidth: ControlCenter.width
    implicitHeight: column.implicitHeight + 10 + pad

    signal releaseFocus

    Column {
        id: column
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        spacing: 8

        CcHeader {
            width: parent.width
            title: "KDE Connect"

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                onClicked: KdeConnect.refresh()

                Glyph {
                    kind: "refresh"
                    size: 16
                    color: Theme.dim
                }
            }

            CcTextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Open app"
                onClicked: KdeConnect.openApp()
            }
        }

        Repeater {
            model: KdeConnect.devices

            Rectangle {
                id: row

                required property var modelData

                width: parent.width
                implicitHeight: 76
                radius: 14
                color: Theme.surface
                opacity: modelData.reachable ? 1 : 0.45

                Column {
                    anchors.left: parent.left
                    anchors.right: actions.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        width: parent.width
                        text: row.modelData.name
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.foreground
                    }

                    Label {
                        width: parent.width
                        text: row.modelData.battery < 0 ? (row.modelData.reachable ? "Connected" : "Not reachable") : `${row.modelData.battery}%${row.modelData.charging ? " · charging" : ""}`
                        textFormat: Text.PlainText
                        color: Theme.dim
                        font.pixelSize: Appearance.fontSize - 1
                    }
                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: row.modelData.reachable

                    CcTextButton {
                        text: "Ring"
                        onClicked: KdeConnect.ring(row.modelData.id)
                    }

                    CcTextButton {
                        text: "Ping"
                        onClicked: KdeConnect.ping(row.modelData.id)
                    }

                    CcTextButton {
                        text: "Clipboard"
                        onClicked: KdeConnect.sendClipboard(row.modelData.id)
                    }

                    CcTextButton {
                        text: "File"
                        onClicked: KdeConnect.browseFile(row.modelData.id, "island")
                    }
                }
            }
        }

        Label {
            width: parent.width
            visible: KdeConnect.reachableCount === 0
            text: KdeConnect.installed ? "No reachable devices. Open KDE Connect on your phone and connect both devices to the same network." : "KDE Connect is not installed."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        Label {
            width: parent.width
            visible: KdeConnect.lastError !== ""
            text: KdeConnect.lastError
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Theme.danger
        }
    }
}
