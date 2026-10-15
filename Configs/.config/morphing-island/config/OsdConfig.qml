pragma Singleton
import QtQuick
import Quickshell

// On-screen displays (volume, microphone, brightness) shown in the island when a value changes.
// (Named OsdConfig because components/Osd.qml is the OSD view.)
Singleton {
    // How long an OSD stays visible after the last change (the countdown pauses while hovered).
    // Milliseconds, 500–10000, default 1500.
    readonly property int timeout: 1500
    // Width of the OSD in pixels. Default 300.
    readonly property int width: 300
    // Extra height over Pill.height, in pixels. Default 8.
    readonly property int extraHeight: 8
    // Thickness of the level bar in pixels. Default 6.
    readonly property int barThickness: 6
    // Show an OSD for microphone changes (mute toggle, input volume). Default true.
    readonly property bool showMic: true

    // Audio: Pipewire reports its initial values bit by bit after startup (or a device switch);
    // changes during this delay do not show the OSD. Milliseconds, default 1500.
    readonly property int audioArmDelay: 1500
    // Brightness: hypridle dims the screen to ~1% when idle and restores it on return. Changes from
    // or to at most this percentage never show the OSD. Percent, 0–10, default 2.
    readonly property int dimmingThreshold: 2
    // Step of Brightness.up()/down() in percent. Default 5.
    readonly property int brightnessStep: 5

    // Microphone: an app with automatic gain control (a browser in a call, a recorder) nudges the input
    // volume by tiny steps all the time. Such changes do not show the OSD: only one of at least this
    // much (0–1, default 0.02), and not more often than this (milliseconds, default 300).
    readonly property real micMinDelta: 0.02
    readonly property int micMinIntervalMs: 300

    // Storm guard (core/IslandController.qml): a person changes the volume, the microphone or the
    // brightness in short bursts (key repeat is about 25 a second, but the value reaches its limit in
    // a second or two). If one of those OSDs is requested again and again with no pause of
    // `stormGapMs` for `stormAfterMs`, something is changing the value on its own: that OSD is then
    // ignored until the requests stop, and one warning naming it goes to the log. Notifications and
    // screenshots are never affected. Milliseconds, defaults 1500 and 20000.
    readonly property int stormGapMs: 1500
    readonly property int stormAfterMs: 20000
}
