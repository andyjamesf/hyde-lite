import qs.bar.components
import qs.bar.services
import qs.shared.services

// Idle inhibitor ("caffeine"): keeps the screen from turning off and the system from suspending.
BarItem {
    icon: "coffee"
    iconFill: Caffeine.active ? 1 : 0
    iconColor: Caffeine.active ? Theme.primary : Theme.text
    active: Caffeine.active
    tooltip: Caffeine.active ? "Caffeine on: the system stays awake" : "Caffeine off"

    onClicked: Caffeine.toggle()
}
