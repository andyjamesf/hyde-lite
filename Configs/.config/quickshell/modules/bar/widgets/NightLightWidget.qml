import qs.components
import qs.services

// Night light (HyDE's hyprsunset). Click toggles it, scroll adjusts the temperature,
// right click opens the presets.
BarItem {
    icon: "nightlight"
    iconFill: NightLight.active ? 1 : 0
    iconColor: NightLight.active ? Theme.warning : Theme.text
    active: NightLight.active
    tooltip: NightLight.tooltip
    menu: HydeActions.hyprsunset

    onClicked: NightLight.toggle()
    onScrolled: direction => NightLight.run(`${direction > 0 ? "-i" : "-d"} ''`)
    onHoveredChanged: if (hovered)
        NightLight.refresh()
    onMenuOpenChanged: if (!menuOpen)
        NightLight.refresh()
}
