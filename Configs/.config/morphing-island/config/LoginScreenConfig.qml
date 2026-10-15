pragma Singleton
import QtQuick
import Quickshell

// Login screen (SDDM): the theme in sddm/, a copy of the lock screen. Install it once with
// `scripts/sddm.py install` (asks for sudo); from then on the island keeps it matching itself:
// colours, font, clock format, the lock card sizes (config/LockScreenConfig.qml), the wallpaper and
// your avatar. `scripts/sddm.py test` previews it in a window; `uninstall` goes back.
Singleton {
    // Keep the login screen in sync with the island. Default true.
    readonly property bool sync: true
    // How often the wallpaper is checked for a change, in seconds (the colours update at once).
    // Default 30.
    readonly property int wallpaperCheckSeconds: 30
}
