import QtQuick
import qs.services

// Text field with the shell's look (used for passwords and searches).
Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder
    property string icon
    signal accepted

    function focusInput() {
        input.forceActiveFocus();
    }

    implicitWidth: 260
    implicitHeight: 40
    radius: height / 2
    color: Theme.surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.primary : Theme.outlineVariant

    MaterialIcon {
        id: iconItem
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 18
        color: Theme.textDim
    }

    TextInput {
        id: input
        anchors.left: iconItem.visible ? iconItem.right : parent.left
        anchors.leftMargin: iconItem.visible ? 8 : 16
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.onPrimary
        font.family: Config.appearance.font
        font.pixelSize: Config.appearance.fontSize
        clip: true
        onAccepted: root.accepted()

        StyledText {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.placeholder
            color: Theme.textFaint
        }
    }
}
