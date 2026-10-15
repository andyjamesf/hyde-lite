import QtQuick
import Quickshell.Widgets
import qs.services

// Clickable list row: icon (Material or image), title, subtitle and trailing content.
Item {
    id: root

    property string icon
    property string image
    property real iconFill: 0
    property string title
    property string subtitle
    property bool highlighted: false
    property bool busy: false
    default property alias trailing: trailingRow.data

    signal clicked

    implicitWidth: 300
    implicitHeight: subtitle !== "" ? 56 : 44

    Rectangle {
        anchors.fill: parent
        radius: Theme.shapeMedium
        color: root.highlighted ? Theme.primaryContainer : "transparent"
    }

    StateLayer {
        anchors.fill: parent
        radius: Theme.shapeMedium
        onClicked: root.clicked()
    }

    Item {
        id: lead
        width: 28
        height: 28
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            visible: root.image === ""
            anchors.centerIn: parent
            icon: root.icon
            fill: root.iconFill
            size: 20
            color: root.highlighted ? Theme.onPrimaryContainer : Theme.text
        }

        IconImage {
            visible: root.image !== ""
            anchors.centerIn: parent
            implicitSize: 22
            source: root.image
        }

        // Spinning ring while the action is in progress (connecting, pairing…).
        Rectangle {
            visible: root.busy
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            opacity: 0.8

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.primary
                x: parent.width / 2 - 4
                y: -3
            }

            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }
    }

    Column {
        anchors.left: lead.right
        anchors.leftMargin: 10
        anchors.right: trailingRow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            color: root.highlighted ? Theme.onPrimaryContainer : Theme.text
            font.weight: root.highlighted ? Font.DemiBold : Font.Normal
        }

        StyledText {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            font.pixelSize: Theme.bodySmall
            color: root.highlighted ? Theme.alpha(Theme.onPrimaryContainer, 0.8) : Theme.textDim
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
    }
}
