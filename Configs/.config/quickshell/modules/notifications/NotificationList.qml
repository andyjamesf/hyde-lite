import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.modules.controls

// Notification history (control center). With `limit` it only shows the most recent ones.
ColumnLayout {
    id: root
    // In the control center: the header gets the back button.
    property bool backButton: false
    signal back

    property int limit: 0
    property bool showHeader: true
    property bool compact: false
    readonly property var items: limit > 0 ? Notifs.list.slice(0, limit) : Notifs.list

    spacing: Theme.space2

    PanelHeader {
        backButton: root.backButton
        onBack: root.back()
        visible: root.showHeader
        icon: Notifs.dnd ? "notifications_off" : "notifications"
        title: "Notifications"
        subtitle: Notifs.count === 0 ? "None" : Notifs.count === 1 ? "1 notification" : `${Notifs.count} notifications`

        IconButton {
            icon: "do_not_disturb_on"
            size: 32
            checked: Notifs.dnd
            onClicked: Notifs.toggleDnd()
        }

        IconButton {
            visible: Notifs.count > 0
            icon: "clear_all"
            size: 32
            onClicked: Notifs.clear()
        }
    }

    StyledText {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        padding: 16
        text: Notifs.dnd ? "Do not disturb is on" : "All caught up"
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
