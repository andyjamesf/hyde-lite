pragma Singleton
import QtQuick
import Quickshell

// Updates icon ("updates" in StatusPillConfig.icons): shown only while updates are waiting (pacman,
// AUR helper, flatpak), with their number. A click opens a terminal that lists them and asks before
// updating. Uses HyDE's ~/.local/lib/hyde/system.update.py; hidden when it is missing.
// (Named UpdatesConfig because services/Updates.qml is the service.)
Singleton {
    // Look for updates every this many minutes. Default 30.
    readonly property int checkMinutes: 30
    // Wait this long after startup before the first check (the network may not be up yet), in
    // seconds. Default 60.
    readonly property int firstCheckSeconds: 60
}
