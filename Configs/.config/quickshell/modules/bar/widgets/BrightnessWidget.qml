import QtQuick
import qs.components
import qs.services
import qs.modules.controls

BarItem {
    readonly property var cfg: Config.widgets.brightness

    shown: Brightness.available
    icon: Brightness.icon
    iconFill: 1
    text: cfg.showPercent ? `${Brightness.percent}%` : ""
    tooltip: `Brightness: ${Brightness.percent}%`

    onScrolled: direction => Brightness.change(direction * cfg.step)
    popoutName: "brightness"
    popout: Component {
        BrightnessPanel {}
    }
}
