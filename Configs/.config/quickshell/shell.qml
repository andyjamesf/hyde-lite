//@ pragma UseQApplication
// Quickshell entry point: one configuration, two UIs. `qs` starts this file; it loads the island's
// UI (island/) when ~/.local/state/morphing-island/active exists and the bar's (bar/) when it does
// not. `island on|off` writes that file and starts the process again (~/.local/bin/island), so only
// one UI is ever compiled or instantiated.
import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell finds `qs.<dir>` modules by following the imports that start at this file, and a file
// loaded by URL is not followed: without these two lines `import qs.island.services` inside
// island/Shell.qml is "not installed". Importing a module only registers it, so the UI that is not
// loaded costs nothing. The aliases keep the two `Shell` types apart.
// qmllint disable unused-imports
import qs.island as Island
import qs.bar as Bar
// qmllint enable unused-imports

ShellRoot {
    id: root

    // "island" or "bar", known once the file has been looked at; the Loader waits for it, because a
    // Loader that started with the wrong UI would create that UI's singletons (they outlive it).
    property string ui: ""

    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/morphing-island/active`
        blockLoading: true
        printErrors: false
        onLoaded: root.ui = "island"
        onLoadFailed: root.ui = "bar"
    }

    Loader {
        active: root.ui !== ""
        source: root.ui !== "" ? `${root.ui}/Shell.qml` : ""
    }
}
