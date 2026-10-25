import qs.bar.components
import qs.bar.services
import qs.shared.services

// Notifications. At this stage they still come from swaync (phase 3: own server).
// Click opens the panel, right click toggles "Do not disturb".
BarItem {
    shown: Notifications.available
    icon: Notifications.dnd ? "notifications_off" : Notifications.count > 0 ? "notifications_unread" : "notifications"
    iconFill: Notifications.count > 0 ? 1 : 0
    iconColor: Notifications.dnd ? Theme.textFaint : Notifications.count > 0 ? Theme.primary : Theme.text
    text: Notifications.count > 0 ? String(Notifications.count) : ""
    tooltip: (Notifications.dnd ? "Do not disturb on\n" : "") + (Notifications.count > 0 ? `${Notifications.count} notifications` : "No notifications")

    onClicked: ShellState.toggleControlCenter("notifications")
    onRightClicked: Notifications.toggleDnd()
}
