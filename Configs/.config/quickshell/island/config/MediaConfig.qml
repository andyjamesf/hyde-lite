pragma Singleton
import QtQuick
import Quickshell

// The media card (control center → media) and player selection. (Named MediaConfig because
// services/Media.qml is the player service.)
Singleton {
    // Album art size in pixels. Default 84.
    readonly property int artSize: 84
    // Corner radius of the card in pixels. Default 22.
    readonly property int cardRadius: 22
    // Inner padding of the card in pixels. Default 16.
    readonly property int padding: 16
    // How often the position/progress is refreshed while the card is visible. Milliseconds,
    // default 1000.
    readonly property int tickMs: 1000
    // MPRIS players whose D-Bus name contains one of these strings are ignored (playerctld is a
    // proxy that would duplicate the active player). Default ["playerctld"].
    readonly property var ignoredPlayers: ["playerctld"]
}
