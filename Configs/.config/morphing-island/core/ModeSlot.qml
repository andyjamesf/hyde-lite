import QtQuick
import qs.config

// Content of one mode inside the island. It only exists while it is the current mode or is fading
// out; it enters with a fade + a slight scale and leaves the same way, while the island changes
// shape underneath. Timing: config/Animations.qml (fadeIn, fadeOut, scaleFrom, scaleDuration).
Loader {
    id: slot

    required property string mode
    property bool current: false

    active: current || opacity > 0.01
    opacity: current ? 1 : 0
    scale: current ? 1 : Animations.scaleFrom
    visible: opacity > 0.01
    anchors.centerIn: parent

    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(slot.current ? Animations.fadeIn : Animations.fadeOut)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Animations.duration(Animations.scaleDuration)
            easing.type: Easing.OutCubic
        }
    }
}
