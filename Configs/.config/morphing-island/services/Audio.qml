pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// Sound: default output (sink) and input (source), via native Pipewire (no pactl/wpctl).
// The changedByUser / micChangedByUser signals drive the OSDs: they are emitted only when the volume
// or mute state of the default output (or input) changes after startup, not during the initial
// Pipewire connection nor when the default device merely switches (the values "change" then
// without anyone touching them). Only the default devices count; touching other devices emits nothing.
// For the control center: lists of outputs and inputs (plain objects, no app streams), choosing the
// default device, and the volume/mute of each one.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool ready: !!sink?.audio

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Hardware (and virtual) nodes with audio; app streams and ".monitor" sources are excluded.
    readonly property var _sinkNodes: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var _sourceNodes: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))

    readonly property var sinks: _sinkNodes.map(n => _entry(n, sink))
    readonly property var sources: _sourceNodes.map(n => _entry(n, source))

    signal changedByUser
    // Same as changedByUser, for the default input (microphone).
    signal micChangedByUser

    // False during startup and right after switching devices.
    property bool _armed: false

    function setVolume(v) {
        _setNodeVolume(sink, v);
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v) {
        _setNodeVolume(source, v);
    }

    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    function nameOf(node) {
        return node?.description || node?.nickname || node?.name || "";
    }

    function setDefaultSink(key) {
        const n = _find(_sinkNodes, key);
        if (n)
            Pipewire.preferredDefaultAudioSink = n;
    }

    function setDefaultSource(key) {
        const n = _find(_sourceNodes, key);
        if (n)
            Pipewire.preferredDefaultAudioSource = n;
    }

    function setNodeVolume(key, v) {
        _setNodeVolume(_find(_sinkNodes, key) ?? _find(_sourceNodes, key), v);
    }

    function toggleNodeMute(key) {
        const n = _find(_sinkNodes, key) ?? _find(_sourceNodes, key);
        if (n?.audio)
            n.audio.muted = !n.audio.muted;
    }

    // The fields read here (volume, muted, the default node) become dependencies of the sinks/sources
    // binding, so the lists follow the changes.
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

    function _find(list, key) {
        return list.find(n => String(n.id) === String(key)) ?? null;
    }

    // Changing the volume unmutes, like the media keys.
    function _setNodeVolume(node, v) {
        if (node?.audio) {
            node.audio.muted = false;
            node.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

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

    // Microphone volume: see OsdConfig.micMinDelta. The value of the last OSD is the reference, so a
    // gain that jitters by a percent or two never accumulates into a "change".
    property real _micShownVolume: 0
    property double _micLastEmit: 0

    function _micVolumeChange() {
        if (!_armed)
            return;
        const now = Date.now();
        if (Math.abs(micVolume - _micShownVolume) < OsdConfig.micMinDelta || now - _micLastEmit < OsdConfig.micMinIntervalMs)
            return;
        _micShownVolume = micVolume;
        _micLastEmit = now;
        micEmitTimer.restart();
    }

    // Muting is always a decision of somebody's: it always shows.
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
        objects: [root.sink, root.source].concat(root._sinkNodes, root._sourceNodes)
    }

    // Initial values arrive bit by bit; only changes after this delay count (config/OsdConfig.qml).
    Timer {
        id: armTimer
        interval: OsdConfig.audioArmDelay
        running: true
        onTriggered: {
            root._armed = true;
            root._micShownVolume = root.micVolume;
        }
    }

    // Merges volume and mute changes of the same instant into a single emission.
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
