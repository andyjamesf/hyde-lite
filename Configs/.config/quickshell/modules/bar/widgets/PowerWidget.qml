import qs.components
import qs.services

// Session: click opens the shell's power menu, right click the quick menu.
BarItem {
    icon: "power_settings_new"
    iconColor: Theme.error
    tooltip: "Session (right click: quick menu)"
    menu: HydeActions.power

    onClicked: ShellState.togglePowerMenu()
}
