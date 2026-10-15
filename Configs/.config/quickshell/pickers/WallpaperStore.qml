pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// HyDE wallpapers (current theme + extra folders), for the shell's picker. Folders, extensions
// and polling: config/Config.pickers.wallpapers.qml.
//
// Everything goes through HyDE's script: `hyde-shell wallpaper --global -s <file>` links
// ~/.cache/hyde/wall.set, generates the thumbnails, regenerates the wallbash palette (wall.dcol)
// and applies it with awww. Never talk to awww directly, or the system colours do not follow.
//
// Thumbnails: HyDE keeps them in ~/.cache/hyde/thumbs/<sha1 of the file>.thmb (PNG, 1000 px wide,
// no extension). They are reused when they exist; otherwise the image itself is used (the view
// loads it with sourceSize, so memory stays low). The sha1s are kept in memory per path + mtime:
// a refresh only reads new or changed files again.
//
// `current` is the target of the wall.set link (readlink -f). The links are replaced (ln -fs), so
// watching files is not always enough: it is read again on refresh(), when wall.dcol changes (when
// the notification arrives), with light polling while `active` (picker open) and faster polling
// while `busy`.
Singleton {
    id: root

    // [{ key, path, name, thumb, hash }]: key is the path; thumb is a file:// URL.
    readonly property var list: _list
    // Resolved path of the current wallpaper ("" while unknown).
    readonly property string current: _current
    // A change we requested has not been reflected in wall.set yet.
    readonly property bool busy: _pending !== ""
    // Path being applied (so the view can mark the card).
    readonly property string pending: _pending
    // The list is being (re)read.
    readonly property bool loading: _loading
    // Current HyDE theme (HYDE_THEME in staterc).
    readonly property string theme: _theme

    // Folders to search (missing ones are ignored), in grid order: Config.pickers.wallpapers.dirs with
    // {theme}, {pictures} and {hydeConfig} filled in (entries using {theme} are skipped while the theme
    // is unknown).
    property var dirs: Config.pickers.wallpapers.dirs.filter(d => _theme !== "" || !d.includes("{theme}")).map(d => Paths.expand(d.replace(/\{theme\}/g, _theme).replace(/\{pictures\}/g, Paths.picturesDir).replace(/\{hydeConfig\}/g, hydeConfig)))
    // Set to true while the picker is visible: enables polling of wall.set.
    property bool active: false

    readonly property string hydeCache: `${Paths.cacheHome}/hyde`
    readonly property string hydeConfig: `${Paths.configHome}/hyde`
    readonly property string thumbsDir: `${hydeCache}/thumbs`

    property var _list: []
    property string _current: ""
    property string _pending: ""
    property bool _loading: false
    property string _theme: ""
    // path → { mtime, hash }
    property var _hashes: ({})
    // Result of the 1st phase: [{ path, mtime }], already sorted.
    property var _files: []
    property bool _again: false

    // Reads the theme, the current wallpaper and the file list again.
    function refresh() {
        staterc.reload();
        readCurrent();
        if (lister.running || prober.running) {
            // Finish the ongoing read and repeat right after (the folders may have changed).
            _again = true;
            return;
        }
        _scan();
    }

    // Applies a wallpaper globally through HyDE. Returns false if it did nothing.
    function set(path) {
        if (!path || busy || path === current)
            return false;
        _pending = path;
        // Detached: if the shell reloads midway, HyDE still finishes the job.
        Quickshell.execDetached(["hyde-shell", "wallpaper", "--global", "-s", path]);
        busyTimeout.restart();
        return true;
    }

    function isCurrent(path) {
        return path !== "" && path === current;
    }

    function readCurrent() {
        if (!reader.running)
            reader.running = true;
    }

    // Path → file:// URL (encodes spaces, "#", "?"…).
    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function _basename(path) {
        const b = path.slice(path.lastIndexOf("/") + 1);
        const dot = b.lastIndexOf(".");
        return dot > 0 ? b.slice(0, dot) : b;
    }

    function _scan() {
        _again = false;
        _loading = true;
        lister.command = ["sh", "-c", _listScript, "sh", String(Config.pickers.wallpapers.minBytes), Config.pickers.wallpapers.extensions.map(e => `*.${e}`).join(" ")].concat(dirs);
        lister.running = true;
    }

    // 1st phase: image files of each folder ("path<TAB>mtime"), natural order per folder.
    // Arguments: minimum size in bytes, extension globs ("*.jpg *.png…"), then the folders.
    // Skips HyDE's artifacts ("wall.*") and tiny files (broken placeholders).
    readonly property string _listScript: `
min=$1; exts=$2; shift 2
set -f
pat=""
for e in $exts; do pat="$pat -o -iname $e"; done
pat=\${pat# -o }
for d; do
    [ -d "$d" ] || continue
    d=$(readlink -f -- "$d")
    find -L "$d" -maxdepth 1 -type f -size +\${min}c ! -name 'wall.*' \\( $pat \\) -printf '%p\\t%T@\\n' | sort -V
done`

    // 2nd phase: receives "path hash" pairs (hash "-" = unknown), computes the missing sha1 and tells
    // whether HyDE already has the thumbnail. Output: "hash<TAB>0|1<TAB>path".
    readonly property string _probeScript: `
t=$1; shift
while [ $# -ge 2 ]; do
    f=$1; h=$2; shift 2
    [ "$h" = - ] && h=$(sha1sum < "$f" | cut -d' ' -f1)
    if [ -s "$t/$h.thmb" ]; then e=1; else e=0; fi
    printf '%s\\t%s\\t%s\\n' "$h" "$e" "$f"
done`

    function _onListed(text) {
        const seen = new Set();
        const files = [];
        for (const line of text.split("\n")) {
            const tab = line.lastIndexOf("\t");
            if (tab <= 0)
                continue;
            const path = line.slice(0, tab);
            if (seen.has(path))
                continue;
            seen.add(path);
            files.push({
                path: path,
                mtime: line.slice(tab + 1)
            });
        }
        _files = files;
        if (files.length === 0) {
            _publish({});
            return;
        }
        const args = [];
        for (const f of files) {
            const known = _hashes[f.path];
            args.push(f.path, known && known.mtime === f.mtime ? known.hash : "-");
        }
        prober.command = ["sh", "-c", _probeScript, "sh", thumbsDir].concat(args);
        prober.running = true;
    }

    function _onProbed(text) {
        const info = {};
        for (const line of text.split("\n")) {
            const a = line.indexOf("\t");
            const b = line.indexOf("\t", a + 1);
            if (a <= 0 || b <= a)
                continue;
            info[line.slice(b + 1)] = {
                hash: line.slice(0, a),
                thumb: line.slice(a + 1, b) === "1"
            };
        }
        _publish(info);
    }

    function _publish(info) {
        const hashes = {};
        const out = [];
        for (const f of _files) {
            const i = info[f.path];
            if (i && i.hash)
                hashes[f.path] = {
                    mtime: f.mtime,
                    hash: i.hash
                };
            out.push({
                key: f.path,
                path: f.path,
                name: _basename(f.path),
                hash: i ? i.hash : "",
                thumb: fileUrl(i && i.thumb ? `${thumbsDir}/${i.hash}.thmb` : f.path)
            });
        }
        _hashes = hashes;
        _list = out;
        _loading = false;
        if (_again)
            _scan();
    }

    // The folders depend on the theme: switching themes in HyDE reads the list again.
    onDirsChanged: rescan.restart()
    on_CurrentChanged: {
        if (_pending !== "" && _current === _pending) {
            _pending = "";
            busyTimeout.stop();
        }
    }

    Component.onCompleted: {
        readCurrent();
        rescan.restart();
    }

    // Merges several changes in a row (theme + folders) into a single refresh.
    Timer {
        id: rescan
        interval: 60
        onTriggered: root.refresh()
    }

    // While the picker is open, read the current one now and then; during a change, faster.
    Timer {
        interval: root.busy ? Config.pickers.wallpapers.busyPollMs : Config.pickers.wallpapers.pollMs
        repeat: true
        running: root.busy || root.active
        onTriggered: root.readCurrent()
    }

    // HyDE may fail (invalid file, colour error): do not stay busy forever.
    Timer {
        id: busyTimeout
        interval: Config.pickers.wallpapers.busyTimeoutMs
        onTriggered: {
            root._pending = "";
            root.readCurrent();
        }
    }

    Process {
        id: reader
        command: ["readlink", "-f", "--", `${root.hydeCache}/wall.set`]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "")
                    root._current = p;
            }
        }
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: root._onListed(text)
        }
    }

    Process {
        id: prober
        stdout: StdioCollector {
            onStreamFinished: root._onProbed(text)
        }
    }

    // HyDE state: the current theme (HYDE_THEME="Name").
    FileView {
        id: staterc
        path: `${Paths.stateHome}/hyde/staterc`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^HYDE_THEME="?([^"\n]*)"?\s*$/m);
            if (m)
                root._theme = m[1];
        }
    }

    // The palette changes on every wallpaper change (it is HyDE's last step). The link is replaced,
    // so the notification does not always arrive; the other paths cover the rest.
    FileView {
        path: `${root.hydeCache}/wall.dcol`
        watchChanges: true
        printErrors: false
        blockLoading: false
        onFileChanged: {
            reload();
            root.readCurrent();
        }
        onLoaded: root.readCurrent()
    }
}
