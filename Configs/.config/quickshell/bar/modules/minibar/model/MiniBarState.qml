pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether the minimal bar is switched on, and what follows from that.
//
// It keeps its own file rather than a field in services/Prefs.qml so that this module owns its
// state: the services layer does not have to know the module exists, and the dependency only ever
// points one way (services/BarLayout.qml reads this; nothing here reads back into services, which
// a QML module cycle would not resolve).
Singleton {
    id: root

    // Switched on by the owner, over IPC or the key. Remembered across a reload and a login.
    property alias switchedOn: adapter.switchedOn

    // On and allowed to be: MiniBarConfig.enabled vetoes it without losing the stored choice.
    readonly property bool active: MiniBarConfig.enabled && switchedOn
    // On *and* standing in for the normal bar, which is the only case where the minimal bar's own
    // measurements are applied (MiniBarConfig.hideMainBar explains why).
    readonly property bool replacesMainBar: active && MiniBarConfig.hideMainBar

    function save() {
        file.writeAdapter();
    }

    FileView {
        id: file
        path: Quickshell.statePath("minibar.json")
        printErrors: false
        // No file yet is the normal case on a first run: write the defaults.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool switchedOn: false
        }
    }
}
