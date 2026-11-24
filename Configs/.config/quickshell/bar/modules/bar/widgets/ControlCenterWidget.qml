import qs.bar.components
import qs.bar.services

// Opens the control center.
BarItem {
    icon: "tune"
    iconFill: ShellState.controlCenterOpen ? 1 : 0
    iconColor: Theme.text
    active: ShellState.controlCenterOpen
    tooltip: "Control center"

    onClicked: ShellState.toggleControlCenter("")
}
