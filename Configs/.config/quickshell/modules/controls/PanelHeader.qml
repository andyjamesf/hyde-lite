import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Panel header: icon, title and, optionally, a switch on the right. Inside the control
// center (`backButton`), the icon is replaced by the back button.
RowLayout {
    id: root

    property string icon
    property string title
    property string subtitle
    property bool hasSwitch: false
    property bool checked: false
    property bool backButton: false
    default property alias extra: extraRow.data

    signal toggled
    signal back

    Layout.fillWidth: true
    spacing: 12

    IconButton {
        visible: root.backButton
        icon: "arrow_back"
        size: 40
        tonal: true
        onClicked: root.back()
    }

    Rectangle {
        visible: !root.backButton
        implicitWidth: 38
        implicitHeight: 38
        radius: height / 2
        color: root.hasSwitch && !root.checked ? Theme.surfaceContainerHighest : Theme.primaryContainer

        MaterialIcon {
            anchors.centerIn: parent
            icon: root.icon
            size: 20
            fill: 1
            color: root.hasSwitch && !root.checked ? Theme.textDim : Theme.onPrimaryContainer
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.titleMedium
            font.weight: Font.DemiBold
        }

        StyledText {
            visible: root.subtitle !== ""
            Layout.fillWidth: true
            text: root.subtitle
            font.pixelSize: Theme.bodySmall
            color: Theme.textDim
        }
    }

    Row {
        id: extraRow
        spacing: 4
    }

    StyledSwitch {
        visible: root.hasSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
