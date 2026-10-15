import QtQuick
import qs.config
import qs.core
import qs.icons
import qs.theme

// Header of the control center subviews: a "‹" button (back to the main page), the title and, on
// the right, whatever controls the page puts there (default children: switch, scan button…).
Item {
    id: root

    property string title: ""
    default property alias trailing: trailingRow.data

    implicitHeight: 44

    IconButton {
        id: backButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: 34
        onClicked: IslandController.back()

        Glyph {
            kind: "back"
            size: 18
            color: Theme.icon
        }
    }

    Label {
        anchors.left: backButton.right
        anchors.leftMargin: 6
        anchors.right: trailingRow.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        font.pixelSize: Appearance.fontSize + 3
        font.weight: Font.DemiBold
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
}
