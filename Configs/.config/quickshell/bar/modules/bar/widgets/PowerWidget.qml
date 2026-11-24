import qs.bar.components
import qs.bar.services

// Session: click opens the shell's power menu, right click the quick menu.
BarItem {
    icon: "power_settings_new"
    iconColor: hovered ? Theme.error : Theme.text
    tooltip: "Session (right click: quick menu)"
    menu: HydeActions.power

    onClicked: ShellState.togglePowerMenu()
}
