pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sound: default output and input, device list and per-app volume
// (native Pipewire, no pactl/wpctl).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: !!sink?.audio

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))
    // Apps playing sound (output streams).
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.properties["media.class"] === "Stream/Output/Audio")

    readonly property string icon: iconFor(volume, muted)
    readonly property string micIcon: micMuted ? "mic_off" : "mic"

    function iconFor(v, m) {
        return m ? "volume_off" : v < 0.01 ? "volume_mute" : v < 0.5 ? "volume_down" : "volume_up";
    }

    function setVolume(v) {
        setNodeVolume(sink, v);
    }

    function changeVolume(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        setNodeVolume(source, v);
    }

    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function setNodeVolume(node, v) {
        if (node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function nameOf(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

    function appNameOf(stream) {
        const p = stream?.properties ?? {};
        return p["application.name"] || p["media.name"] || nameOf(stream);
    }

    function appIconOf(stream) {
        const p = stream?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || "";
    }

    // Without this the nodes don't keep their audio properties up to date.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks, root.sources, root.streams)
    }
}
