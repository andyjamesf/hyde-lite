import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// Output volume. Click opens the sound panel; scroll adjusts; right click mutes.
BarItem {
    id: root

    readonly property var cfg: Config.widgets.audio

    shown: Audio.ready
    icon: Audio.icon
    iconFill: Audio.muted ? 0 : 1
    iconColor: Audio.muted ? Theme.textFaint : Theme.text
    // With autoPercent the number only shows for a moment after the volume changes.
    property bool recent: false
    text: cfg.showPercent && !Audio.muted && (!cfg.autoPercent || recent) ? `${Math.round(Audio.volume * 100)}%` : ""
    Connections {
        target: Audio
        function onVolumeChanged() {
            recentTimer.restart();
            root.recent = true;
        }
    }
    Timer {
        id: recentTimer
        interval: 2500
        onTriggered: root.recent = false
    }
    tooltip: `${Audio.nameOf(Audio.sink)}\n${Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"}`

    popoutName: "audio"
    popout: Component {
        AudioPanel {}
    }
    onRightClicked: Audio.toggleMute()
    onScrolled: direction => Audio.changeVolume(direction * cfg.step / 100)
}
