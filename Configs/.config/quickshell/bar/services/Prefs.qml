pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Preferences chosen at runtime (menus, IPC), stored in ~/.local/state/quickshell/…/prefs.json.
// They are kept out of config.json on purpose: that one lives in the dotfiles repository and must not be
// rewritten by the shell.
Singleton {
    id: root

    // Chosen bar layout (empty: use the "layout" from config.json).
    property alias layout: adapter.layout
    // Color source: "hyde" follows HyDE (theme or wallbash, depending on HyDE's mode);
    // "wallpaper" always uses the colors extracted from the current wallpaper.
    property alias colorSource: adapter.colorSource
    // Island background style (see BarLayout.pillStyles); empty: use the one from config.json.
    property alias pillStyle: adapter.pillStyle
    // Island background opacity chosen in the menu (negative: use the layout/config.json one).
    property alias pillOpacity: adapter.pillOpacity
    // Bar (island) height in px; 0: use the layout's.
    property alias barHeight: adapter.barHeight
    // "Do not disturb": no notification popups (except critical ones).
    property alias dnd: adapter.dnd
    // Bar AI usage expanded (true) or collapsed behind the button (false).
    property alias aiExpanded: adapter.aiExpanded

    function save() {
        file.writeAdapter();
    }

    FileView {
        id: file
        path: Quickshell.statePath("prefs.json")
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property string layout: ""
            property string colorSource: "hyde"
            property string pillStyle: ""
            property real pillOpacity: -1
            property int barHeight: 0
            property bool dnd: false
            property bool aiExpanded: false
        }
    }
}
