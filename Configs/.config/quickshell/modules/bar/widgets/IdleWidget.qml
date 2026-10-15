import qs.components
import qs.services

// Idle inhibitor ("caffeine"): keeps the screen from turning off and the system from suspending.
BarItem {
    icon: "coffee"
    iconFill: ShellState.idleInhibited ? 1 : 0
    iconColor: ShellState.idleInhibited ? Theme.primary : Theme.text
    active: ShellState.idleInhibited
    tooltip: ShellState.idleInhibited ? "Caffeine on: the system stays awake" : "Caffeine off"

    onClicked: ShellState.idleInhibited = !ShellState.idleInhibited
}
