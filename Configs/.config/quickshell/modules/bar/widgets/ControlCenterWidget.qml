import qs.components
import qs.services

// Opens the control center.
BarItem {
    icon: "tune"
    iconFill: ShellState.controlCenterOpen ? 1 : 0
    iconColor: Theme.primary
    active: ShellState.controlCenterOpen
    tooltip: "Control center"

    onClicked: ShellState.toggleControlCenter("")
}
