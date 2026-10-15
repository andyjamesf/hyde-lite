import qs.components
import qs.services

// Notifications. At this stage they still come from swaync (phase 3: own server).
// Click opens the panel, right click toggles "Do not disturb".
BarItem {
    shown: Notifs.available
    icon: Notifs.dnd ? "notifications_off" : Notifs.count > 0 ? "notifications_unread" : "notifications"
    iconFill: Notifs.count > 0 ? 1 : 0
    iconColor: Notifs.dnd ? Theme.textFaint : Notifs.count > 0 ? Theme.primary : Theme.text
    text: Notifs.count > 0 ? String(Notifs.count) : ""
    tooltip: (Notifs.dnd ? "Do not disturb on\n" : "") + (Notifs.count > 0 ? `${Notifs.count} notifications` : "No notifications")

    onClicked: Notifs.togglePanel()
    onRightClicked: Notifs.toggleDnd()
}
