pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Volume, microphone and brightness OSD. Reacts to changes in the services (Pipewire and the
// backlight uevent), so it shows up wherever the change comes from: HyDE keys, the bar, apps.
// Exceptions (hypridle lowers the brightness to 1% after 60 s and restores it on return):
//  - changes while the user is idle, or right after coming back;
//  - brightness changes from or to ≤ 2% (the dimming level), wherever they come from.
Singleton {
    id: root

    property string kind: ""      // "volume" | "mic" | "brightness"
    property bool visible: false
    // The OSD window only exists while it is needed (visible or fading out).
    readonly property bool needed: visible || fadeOut.running
    // During startup and when switching devices the values "change" without anyone touching them.
    property bool armed: false
    property int lastBrightness: -1

    readonly property real value: kind === "brightness" ? Brightness.percent / 100 : kind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume) : (Audio.muted ? 0 : Audio.volume)
    readonly property string icon: kind === "brightness" ? Brightness.icon : kind === "mic" ? Audio.micIcon : Audio.icon
    readonly property bool muted: kind === "volume" ? Audio.muted : kind === "mic" ? Audio.micMuted : false

    function show(k) {
        if (!armed || !Config.widgets.osd.enabled || idle.isIdle)
            return;
        // hypridle restores the brightness the moment you come back: that change doesn't count.
        if (k === "brightness" && resumeGrace.running)
            return;
        kind = k;
        visible = true;
        hideTimer.restart();
    }

    function disarmBriefly() {
        armed = false;
        arm.restart();
    }

    // Idle for 20 s: well before hypridle's dimming (60 s). Ignores the inhibitors
    // (caffeine, videos): with those active hypridle doesn't touch the brightness either.
    IdleMonitor {
        id: idle
        timeout: 20
        respectInhibitors: false
        onIsIdleChanged: {
            console.debug("osd: idle =", isIdle);
            if (!isIdle)
                resumeGrace.restart();
        }
    }

    Timer {
        id: resumeGrace
        interval: 800
    }

    Timer {
        id: hideTimer
        interval: Config.widgets.osd.timeout
        onTriggered: {
            root.visible = false;
            fadeOut.restart();
        }
    }

    Timer {
        id: fadeOut
        interval: 400
    }

    Timer {
        id: arm
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            root.show("volume");
        }
        function onMutedChanged() {
            root.show("volume");
        }
        function onMicMutedChanged() {
            root.show("mic");
        }
        function onSinkChanged() {
            root.disarmBriefly();
        }
        function onSourceChanged() {
            root.disarmBriefly();
        }
    }

    Connections {
        target: Brightness
        function onPercentChanged() {
            const previous = root.lastBrightness;
            root.lastBrightness = Brightness.percent;
            if (previous >= 0 && (previous <= 2 || Brightness.percent <= 2)) {
                console.debug("osd: brightness", previous, "→", Brightness.percent, "ignored (dimming)");
                return;
            }
            root.show("brightness");
        }
    }
}
