pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media players (native MPRIS). The "active" player is the one playing; if none is,
// the last one that played; if there is no history, the first in the list.
Singleton {
    id: root

    // playerctld is a proxy for the other players; showing it would duplicate the active player.
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer lastPlaying: null
    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? (players.includes(lastPlaying) ? lastPlaying : players[0] ?? null)

    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""

    onActiveChanged: if (active?.isPlaying)
        lastPlaying = active

    Connections {
        target: root.active
        function onIsPlayingChanged() {
            if (root.active?.isPlaying)
                root.lastPlaying = root.active;
        }
    }

    function togglePlaying() {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next() {
        if (active?.canGoNext)
            active.next();
    }

    function previous() {
        if (active?.canGoPrevious)
            active.previous();
    }
}
