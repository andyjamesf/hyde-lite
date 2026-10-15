pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The notepad's one page, kept in <XDG_DATA_HOME>/morphing-island/notes.md.
//
// Plain text and a plain file on purpose: it stays readable, greppable and editable by anything
// else, and the file is watched, so editing it in an editor shows up here without a reload.
//
// Saving is debounced (NotepadConfig.saveDebounceMs) rather than on every keystroke, and flush()
// writes immediately for the moments that cannot wait -- closing the page, or logging out.
Singleton {
    id: root

    readonly property string path: `${Paths.islandData}/notes.md`
    // What the page holds. Write through set(), which is what schedules the save.
    property string text: ""
    // Typed but not yet on disk. The page shows this as a dot next to its title.
    property bool dirty: false
    // The file has been read at least once: until then the page must not save over it with "".
    property bool loaded: false

    function set(value) {
        const v = String(value ?? "");
        if (v === root.text)
            return;
        root.text = v;
        if (!root.loaded)
            return;
        root.dirty = true;
        saveTimer.restart();
    }

    // Writes now instead of after the debounce.
    function flush() {
        if (saveTimer.running) {
            saveTimer.stop();
            root.write();
        }
    }

    function write() {
        if (!root.loaded)
            return;
        file.setText(root.text);
        root.dirty = false;
    }

    // The data directory is the shell's own and may not exist yet. 700: notes are personal.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'mkdir -p -m 700 -- "$1"', "sh", Paths.islandData])

    Timer {
        id: saveTimer
        interval: Math.max(0, NotepadConfig.saveDebounceMs)
        onTriggered: root.write()
    }

    FileView {
        id: file

        path: root.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            // Our own write comes back through the watch: only take it when it really differs, or
            // the cursor would jump to the end on every save.
            if (t !== root.text)
                root.text = t;
            root.loaded = true;
            root.dirty = false;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.text = "";
                root.loaded = true;
            }
        }
    }
}
