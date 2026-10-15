pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.theme

// Small equalizer (3 bars). While playing, each bar oscillates with its own period; when stopped,
// the component shrinks to width 0 (together with the gap on its left, `leadingGap`) so the
// surrounding layout closes the hole. Animations only run while playing and visible.
// Sizes and periods: config/Pill.qml.
Item {
    id: root

    property bool playing: false
    property color color: Theme.accent
    // Space on the left that shrinks together with the bars (avoids the jump of a Row's `spacing`).
    property real leadingGap: 0
    property real barWidth: Pill.eqBarWidth
    property real barGap: Pill.eqBarGap
    property real maxHeight: Math.round(Pill.height * Pill.eqHeightFactor)

    // Periods (ms), different so the bars are not in phase.
    readonly property var periods: Pill.eqPeriods
    readonly property real fullWidth: leadingGap + periods.length * barWidth + (periods.length - 1) * barGap

    implicitWidth: playing ? fullWidth : 0
    implicitHeight: maxHeight
    opacity: playing ? 1 : 0
    visible: opacity > 0.01
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Animations.duration(240)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(200)
            easing.type: Easing.OutCubic
        }
    }

    Row {
        x: root.leadingGap
        anchors.verticalCenter: parent.verticalCenter
        height: root.maxHeight
        spacing: root.barGap

        Repeater {
            model: root.periods.length

            Rectangle {
                id: bar

                required property int index
                readonly property int period: root.periods[index]
                readonly property real low: root.maxHeight * 0.28

                anchors.bottom: parent.bottom
                width: root.barWidth
                // Varied initial height (also the static look without animations).
                height: root.maxHeight * [0.55, 0.9, 0.4][index % 3]
                radius: width / 2
                color: root.color

                SequentialAnimation on height {
                    running: root.playing && root.visible && Animations.enabled
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: root.maxHeight
                        duration: bar.period / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: bar.low
                        duration: bar.period / 2
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
