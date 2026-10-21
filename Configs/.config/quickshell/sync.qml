//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.island.services
import qs.island.theme

// One-shot login-screen sync for the bar shell: the island is not running there, so nothing would
// bring the SDDM theme up to date with the colours and wallpaper. `island login sync-once` runs this
// (ISLAND_LOCK_ENTRY=fade) once at login; it quits when scripts/sddm.py has answered.
ShellRoot {
    Binding {
        target: SddmTheme
        property: "roles"
        value: Theme.targetRoles
    }
    Binding {
        target: SddmTheme
        property: "islandOpacity"
        value: Theme.islandOpacity
    }

    Timer {
        interval: 2000
        running: SddmTheme.values !== null
        onTriggered: SddmTheme.sync()
    }

    Connections {
        target: SddmTheme
        function onLastResultChanged() {
            if (SddmTheme.lastResult !== null)
                Qt.quit();
        }
    }
    // Gives up if the theme never answers.
    Timer {
        interval: 30000
        running: true
        onTriggered: Qt.quit()
    }
}
