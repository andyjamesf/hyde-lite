pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Motion. `enabled` and `speed` can be changed in the Settings screen (Prefs keys
// "animations.enabled" and "animations.speed"); the values here are the defaults.
Singleton {
    id: root

    // Master switch: false makes every spring jump and every duration 0. Default true.
    readonly property bool enabled: Prefs.get("animations.enabled", true)
    // Global speed multiplier: 2 = twice as fast, 0.5 = half speed. Range 0.5–2, default 1.
    readonly property real speed: Prefs.get("animations.speed", 1)

    // Critically damped spring used for the island's size/position (core/Spring.qml): angular
    // frequency ω in rad/s, already multiplied by `speed`. Higher = snappier; never overshoots.
    // Base 22 (range ~10–40).
    readonly property real springOmega: 22 * speed
    // Spring stops when closer than this to its target (in the animated value's units, usually px).
    // Default 0.1.
    readonly property real springEpsilon: 0.1

    // Content cross-fade when the island changes mode: fade-in / fade-out. Milliseconds (before
    // `speed`), defaults 180 / 110.
    readonly property int fadeIn: 180
    readonly property int fadeOut: 110
    // Incoming content grows from this scale to 1. 0.8–1, default 0.94.
    readonly property real scaleFrom: 0.94
    // Duration of that scale-in. Milliseconds (before `speed`), default 220.
    readonly property int scaleDuration: 220

    // A duration adjusted to the settings: ms / speed, or 0 when animations are disabled.
    function duration(ms) {
        return enabled ? Math.round(ms / Math.max(0.1, speed)) : 0;
    }
}
