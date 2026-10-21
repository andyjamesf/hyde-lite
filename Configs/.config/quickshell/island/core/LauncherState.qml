pragma Singleton
import QtQuick
import Quickshell

// Shared launcher state: the search text (the view and IPC both write it) and a summary of what is
// on screen, so IPC tests can run without a keyboard.
Singleton {
    id: root

    // Search text, including the mode prefix ("=" calculator, ":" clipboard, "?" keys; see
    // config/Launcher.qml).
    property string query: ""
    // "<mode> <result count> <selected title>", written by the open view (read by IPC
    // `island-debug launcherState` / `island-debug launcherState`); "closed" otherwise.
    property string status: "closed"
    // Active picker (a provider name from services/Pickers.qml); "" = normal launcher.
    // Written BEFORE the launcher opens (IPC `pick`) and cleared on its own when the launcher
    // closes, so a normal opening always starts without a picker.
    property string provider: ""

    Connections {
        target: IslandController
        function onModeChanged() {
            if (IslandController.mode !== IslandState.launcher)
                root.provider = "";
        }
    }
}
