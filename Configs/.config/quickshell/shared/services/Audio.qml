pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Sound: the default output (sink) and input (source), the device lists and the per-app streams,
// through native Pipewire (no pactl or wpctl). Shared by every UI of this configuration.
//
// The union of the two services this replaces, which had grown apart further than any other pair:
// the bar had the per-app streams, the Material icons and raw node lists; the island had the
// entries with their own volume and mute, choosing a device by key, and the changedByUser /
// micChangedByUser signals that drive the OSDs. Both shells wanted all of it.
//
// About the signals: they fire only when the volume or the mute of the *default* device changes
// after startup, not while Pipewire is still connecting and not when the default device merely
// switches (the values "change" then without anyone touching anything). Each shell used to arm and
// disarm that by itself — the island here, the bar in its own OSD service — and now it happens in
// one place. The microphone also gets a jitter filter: a gain that wobbles by a percent or two
// never adds up to a "change" (micMinDelta, micMinIntervalMs).
//
// The three tuning values are properties, not constants: a shared service has no settings file, so
// the shell that has one binds them (the island from config/OsdConfig.qml).
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: !!sink?.audio

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // The hardware (and virtual) nodes. App streams and ".monitor" sources are left out.
    readonly property var sinkNodes: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sourceNodes: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))

    // The same devices as entries: name, whether it is the default one, and its own volume and
    // mute, so a list can show and change a device without reaching into the node itself. Reading
    // those fields here is what makes the lists follow the changes.
    readonly property var sinks: sinkNodes.map(n => _entry(n, sink))
    readonly property var sources: sourceNodes.map(n => _entry(n, source))

    // Apps playing sound (output streams).
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.properties["media.class"] === "Stream/Output/Audio")

    // Material Symbols names, for the shells that draw with them.
    readonly property string icon: iconFor(volume, muted)
    readonly property string micIcon: micMuted ? "mic_off" : "mic"

    // The owner changed the default output (or input), as opposed to it changing by itself.
    signal changedByUser
    signal micChangedByUser

    // How long after startup (or a device switch) changes start counting as the owner's.
    property int armDelay: 1500
    // The microphone gain has to move at least this much, and no more often than this, to count.
    property real micMinDelta: 0.02
    property int micMinIntervalMs: 300

    function iconFor(v: real, m: bool): string {
        return m ? "volume_off" : v < 0.01 ? "volume_mute" : v < 0.5 ? "volume_down" : "volume_up";
    }

    function nameOf(node): string {
        return node?.description || node?.nickname || node?.name || "";
    }

    function setVolume(v: real): void {
        _setNodeVolume(sink, v);
    }

    function changeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v: real): void {
        _setNodeVolume(source, v);
    }

    function toggleMicMute(): void {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // These four take whatever the caller has: a node, an entry from sinks/sources, or an entry's
    // key. The two shells each had their own convention and both keep working.
    function setDefaultSink(which): void {
        const n = _resolve(which);
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }

    function setDefaultSource(which): void {
        const n = _resolve(which);
        if (n)
            Pipewire.preferredDefaultAudioSource = n;
    }

    function setNodeVolume(which, v: real): void {
        _setNodeVolume(_resolve(which), v);
    }

    function toggleNodeMute(which): void {
        const n = _resolve(which);
        if (n?.audio)
            n.audio.muted = !n.audio.muted;
    }

    function appNameOf(stream): string {
        const p = stream?.properties ?? {};
        return p["application.name"] || p["media.name"] || nameOf(stream);
    }

    function appIconOf(stream): string {
        const p = stream?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || "";
    }

    function _entry(n, defaultNode) {
        return {
            key: String(n.id),
            name: nameOf(n),
            node: n,
            isDefault: n === defaultNode,
            volume: n.audio?.volume ?? 0,
            muted: n.audio?.muted ?? false
        };
    }

    function _resolve(which) {
        if (!which)
            return null;
        if (which.audio !== undefined)   // already a node
            return which;
        if (which.node)                  // an entry from sinks/sources
            return which.node;
        const key = String(which);       // a key
        return sinkNodes.find(n => String(n.id) === key) ?? sourceNodes.find(n => String(n.id) === key) ?? null;
    }

    // Changing the volume unmutes, the way the media keys do.
    function _setNodeVolume(node, v) {
        if (node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    // False during startup and right after a device switch.
    property bool _armed: false
    property real _micShownVolume: 0
    property double _micLastEmit: 0

    function _disarmBriefly() {
        _armed = false;
        emitTimer.stop();
        micEmitTimer.stop();
        armTimer.restart();
    }

    function _userChange() {
        if (_armed)
            emitTimer.restart();
    }

    function _micVolumeChange() {
        if (!_armed)
            return;
        const now = Date.now();
        if (Math.abs(micVolume - _micShownVolume) < micMinDelta || now - _micLastEmit < micMinIntervalMs)
            return;
        _micShownVolume = micVolume;
        _micLastEmit = now;
        micEmitTimer.restart();
    }

    // Muting is always somebody's decision: it always shows.
    function _micMuteChange() {
        if (_armed)
            micEmitTimer.restart();
    }

    onSinkChanged: _disarmBriefly()
    onSourceChanged: _disarmBriefly()
    onReadyChanged: _disarmBriefly()
    onVolumeChanged: _userChange()
    onMutedChanged: _userChange()
    onMicVolumeChanged: _micVolumeChange()
    onMicMutedChanged: _micMuteChange()

    // Without this the nodes do not keep their audio properties (volume, mute) up to date.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinkNodes, root.sourceNodes, root.streams)
    }

    // The initial values arrive bit by bit; only changes after this delay count.
    Timer {
        id: armTimer
        interval: root.armDelay
        running: true
        onTriggered: {
            root._armed = true;
            root._micShownVolume = root.micVolume;
        }
    }

    // Merges a volume and a mute change of the same instant into one emission.
    Timer {
        id: emitTimer
        interval: 30
        onTriggered: root.changedByUser()
    }

    Timer {
        id: micEmitTimer
        interval: 30
        onTriggered: root.micChangedByUser()
    }
}
