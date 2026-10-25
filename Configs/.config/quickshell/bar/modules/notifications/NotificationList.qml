import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// Notification history (control center). With `limit` it only shows the most recent ones.
ColumnLayout {
    id: root
    // In the control center: the header gets the back button.
    property bool backButton: false
    signal back

    property int limit: 0
    property bool showHeader: true
    property bool compact: false
    readonly property var items: limit > 0 ? Notifications.list.slice(0, limit) : Notifications.list

    spacing: Theme.space2

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        visible: root.showHeader
        icon: Notifications.dnd ? "notifications_off" : "notifications"
        title: "Notifications"
        subtitle: Notifications.count === 0 ? "None" : Notifications.count === 1 ? "1 notification" : `${Notifications.count} notifications`

        IconButton {
            icon: "do_not_disturb_on"
            size: 32
            checked: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }

        IconButton {
            visible: Notifications.count > 0
            icon: "clear_all"
            size: 32
            onClicked: Notifications.clear()
        }
    }

    StyledText {
        visible: Notifications.count === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        padding: 16
        text: Notifications.dnd ? "Do not disturb is on" : "All caught up"
        color: Theme.textFaint
    }

    Repeater {
        model: root.items

        NotificationCard {
            required property var modelData
            Layout.fillWidth: true
            notification: modelData
            compact: root.compact
        }
    }
}
