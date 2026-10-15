pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// Media players (native MPRIS). The chosen player is, in this order: the one the user selected
// (selectPlayer) while it exists; the one playing; the last one that played; the first in the list.
// The manual selection is dropped when another player starts playing.
// Position: MPRIS does not notify the continuous progress of the position, so whoever shows it
// calls tickPosition() every MediaConfig.tickMs while visible (there is no timer here).
Singleton {
    id: root

    // Players whose D-Bus name contains an entry of MediaConfig.ignoredPlayers are skipped (playerctld is
    // a proxy for the other players; counting it would duplicate the active one).
    readonly property var players: Mpris.players.values.filter(p => !MediaConfig.ignoredPlayers.some(i => (p.dbusName ?? "").includes(i)))
    property var _lastPlaying: null
    property var _selected: null
    readonly property var player: players.includes(_selected) ? _selected : players.find(p => p.isPlaying) ?? (players.includes(_lastPlaying) ? _lastPlaying : players[0] ?? null)

    readonly property bool active: player !== null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property bool canNext: player?.canGoNext ?? false
    readonly property bool canPrevious: player?.canGoPrevious ?? false
    readonly property string identity: player?.identity ?? ""

    // In seconds.
    readonly property real position: player?.position ?? 0
    readonly property real length: player?.length ?? 0
    readonly property bool lengthSupported: player?.lengthSupported ?? false
    readonly property bool canSeek: (player?.canSeek ?? false) && (player?.positionSupported ?? false)

    onPlayerChanged: {
        if (player?.isPlaying)
            _lastPlaying = player;
    }

    // Follows every player: whoever starts playing becomes the last one that played and, if it is not
    // the one selected by hand, cancels that selection.
    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (!modelData.isPlaying)
                    return;
                root._lastPlaying = modelData;
                if (root._selected && root._selected !== modelData)
                    root._selected = null;
            }
        }
    }

    function togglePlaying() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player?.canGoNext)
            player.next();
    }

    function previous() {
        if (player?.canGoPrevious)
            player.previous();
    }

    // fraction in 0..1 of the track length.
    function seek(fraction) {
        if (!canSeek || !lengthSupported || length <= 0)
            return;
        player.position = Math.max(0, Math.min(1, fraction)) * length;
    }

    function selectPlayer(p) {
        if (players.includes(p))
            _selected = p;
    }

    // Forces the position to be read again (Quickshell computes it from the last update).
    function tickPosition() {
        if (player)
            player.positionChanged();
    }
}
