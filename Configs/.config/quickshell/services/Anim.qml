pragma Singleton
import QtQuick
import Quickshell

// Animation durations and curves used across the shell (inspired by Material 3 "expressive").
// Always use these, so motion is consistent; config.json can scale or disable them.
Singleton {
    readonly property real scale: Config.appearance.animationScale

    readonly property int fast: 150 * scale
    readonly property int normal: 250 * scale
    readonly property int slow: 400 * scale
    readonly property int spatial: 500 * scale
    // Entrances slightly slower than exits: what arrives decelerates, what leaves accelerates.
    readonly property int enter: 300 * scale
    readonly property int exit: 200 * scale

    // Curves in BezierSpline format (control points + end point).
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property var standardDecel: [0, 0, 0, 1, 1, 1]
    readonly property var standardAccel: [0.3, 0, 1, 1, 1, 1]
    readonly property var emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
    // With a slight overshoot: for spatial movement (indicators, panels coming in).
    readonly property var expressive: [0.38, 1.21, 0.22, 1, 1, 1]
}
