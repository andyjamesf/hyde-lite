import QtQuick
import qs.components
import qs.services
import qs.modules.controls

// Output volume. Click opens the sound panel; scroll adjusts; right click mutes.
BarItem {
    readonly property var cfg: Config.widgets.audio

    shown: Audio.ready
    icon: Audio.icon
    iconFill: Audio.muted ? 0 : 1
    iconColor: Audio.muted ? Theme.textFaint : Theme.text
    text: cfg.showPercent && !Audio.muted ? `${Math.round(Audio.volume * 100)}%` : ""
    tooltip: `${Audio.nameOf(Audio.sink)}\n${Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"}`

    popoutName: "audio"
    popout: Component {
        AudioPanel {}
    }
    onRightClicked: Audio.toggleMute()
    onScrolled: direction => Audio.changeVolume(direction * cfg.step / 100)
}
