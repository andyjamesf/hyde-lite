pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared.services

// Quick notes: plain Markdown files in a folder of the Obsidian vault, so they sync with it and open
// on every machine. One note is open at a time (`path`, `text`); `notes` lists them all, newest first.
//
// The title of a note is its first line, which is also its file name (what Obsidian shows as the
// note's name). A new note starts out named after the time and only becomes a file once something is
// typed; on save (Ctrl+S, closing the window, opening another note) the file is renamed after the
// first line, whenever that has changed. A name already taken gets " 2", " 3"… after it.
//
// Saving as you type is debounced; flush() writes at once for the moments that cannot wait.
Singleton {
    id: root

    readonly property string dir: `${Paths.home}/Documents/obsidian-notes/08_Notas_Rapidas`
    readonly property string listerScript: Qt.resolvedUrl("../scripts/list_notes.py").toString().replace("file://", "")

    // The open note. Write through set(), which is what schedules the save.
    property string path: ""
    property string text: ""
    property bool dirty: false
    // The open note has been read (or is new): until then nothing may be saved over it.
    property bool loaded: false
    // The open note exists on disk.
    property bool onDisk: false
    // Every note, newest first: {path, name, mtime, title, preview, search}.
    property var notes: []

    readonly property string title: {
        const line = text.split("\n").map(l => l.replace(/^\s*#{1,6}\s*/, "").trim()).find(l => l !== "");
        return line ?? "New note";
    }

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss");
    }

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

    function flush() {
        if (saveTimer.running) {
            saveTimer.stop();
            root.write();
        }
    }

    function write() {
        if (!root.loaded)
            return;
        // A new note stays out of the vault until it has something in it.
        if (root.text.trim() === "" && !root.onDisk) {
            root.dirty = false;
            return;
        }
        file.setText(root.text);
        root.onDisk = true;
        root.dirty = false;
        listTimer.restart();
    }

    // Writes now and names the file after the first line.
    function save() {
        root.flush();
        if (!root.onDisk || root.title === "New note")
            return;
        // What Obsidian does not allow in a name, and what would break a link.
        const name = root.title.replace(/[\\/:*?"<>|#^\[\]]/g, " ").replace(/\s+/g, " ").trim().replace(/^\.+/, "").slice(0, 60).trim();
        const current = root.path.slice(root.path.lastIndexOf("/") + 1, -3);
        // "name 2" is already this note's name once "name" was taken.
        if (name === "" || current === name || (current.startsWith(name + " ") && /^\d+$/.test(current.slice(name.length + 1))))
            return;
        rename.from = root.path;
        rename.to = `${root.dir}/${name}.md`;
        rename.running = true;
    }

    function newNote() {
        root.save();
        root.loaded = false;
        root.text = "";
        root.onDisk = false;
        root.dirty = false;
        root.path = `${root.dir}/${root.stamp()}.md`;
        root.loaded = true;
    }

    function openNote(p) {
        if (p === root.path)
            return;
        root.save();
        root.loaded = false;
        root.onDisk = true;
        root.dirty = false;
        root.path = p;
    }

    // The note to continue when the window opens: the one in front, or the newest, or a new one.
    function resume() {
        if (root.path !== "")
            return;
        if (root.notes.length > 0)
            root.openNote(root.notes[0].path);
        else
            root.newNote();
    }

    function refresh() {
        lister.running = true;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dir]);
        root.refresh();
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: root.write()
    }

    // The list is rebuilt a moment after the last write, not after each one.
    Timer {
        id: listTimer
        interval: 800
        onTriggered: root.refresh()
    }

    // Moves the note to its new name, or to the first free "name 2", "name 3"… if that one is taken;
    // prints where it ended up.
    Process {
        id: rename

        property string from
        property string to

        command: ["sh", "-c", 'to=$2; base=${2%.md}; n=2; while [ -e "$to" ]; do to="$base $n.md"; n=$((n+1)); done; mv -- "$1" "$to" && printf %s "$to"', "sh", from, to]
        stdout: StdioCollector {
            onStreamFinished: {
                // The page may have moved on to another note meanwhile.
                if (text !== "" && root.path === rename.from)
                    root.path = text;
                root.refresh();
            }
        }
    }

    Process {
        id: lister

        command: ["python3", "-I", root.listerScript, root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.notes = JSON.parse(text);
                } catch (e) {
                    console.warn("notes: could not read the list:", e);
                }
                // First start: nothing is open yet.
                root.resume();
            }
        }
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
            // Our own write comes back through the watch, possibly after more has been typed: only
            // take it when it differs and nothing typed is waiting to be saved, or the reload
            // would put the older text back over it.
            if (t !== root.text && !root.dirty)
                root.text = t;
            root.loaded = true;
            root.onDisk = true;
            root.dirty = false;
        }
        onLoadFailed: error => {
            // A note that is not a file yet (new), or that was moved: keep what is on the page.
            if (error === FileViewError.FileNotFound) {
                root.loaded = true;
                root.onDisk = false;
            }
        }
    }
}
