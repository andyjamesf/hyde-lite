import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

ColumnLayout {
    width: 340
    spacing: 8
    PanelHeader {
        icon: "devices"
        title: "KDE Connect"
        subtitle: `${KdeConnect.reachableCount} reachable`
        IconButton { icon: "refresh"; size: 30; onClicked: KdeConnect.refresh() }
        IconButton { icon: "open_in_new"; size: 30; onClicked: KdeConnect.openApp() }
    }
    Repeater {
        model: KdeConnect.devices
        Item {
            id: device
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 64
            opacity: modelData.reachable ? 1 : 0.45
            Column {
                anchors.left: parent.left
                anchors.right: actions.left
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: device.modelData.name
                    textFormat: Text.PlainText
                    color: Theme.text
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: device.modelData.battery < 0 ? (device.modelData.reachable ? "Connected" : "Not reachable") : `${device.modelData.battery}%${device.modelData.charging ? " · charging" : ""}`
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.pixelSize: Theme.labelSmall
                }
            }
            RowLayout {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: device.modelData.reachable
                IconButton { icon: "notifications_active"; size: 28; tooltip: "Ring"; onClicked: KdeConnect.ring(device.modelData.id) }
                IconButton { icon: "send"; size: 28; tooltip: "Ping"; onClicked: KdeConnect.ping(device.modelData.id) }
                IconButton { icon: "content_paste"; size: 28; tooltip: "Send clipboard"; onClicked: KdeConnect.sendClipboard(device.modelData.id) }
                IconButton { icon: "attach_file"; size: 28; tooltip: "Send file"; onClicked: KdeConnect.browseFile(device.modelData.id, "bar") }
            }
        }
    }
    StyledText {
        visible: KdeConnect.reachableCount === 0
        Layout.fillWidth: true
        text: KdeConnect.installed ? "No reachable devices. Open KDE Connect on your phone and connect both devices to the same network." : "KDE Connect is not installed."
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
        wrapMode: Text.WordWrap
    }
    StyledText { visible: KdeConnect.lastError !== ""; text: KdeConnect.lastError; color: Theme.error; font.pixelSize: Theme.labelSmall; wrapMode: Text.WordWrap }
}
