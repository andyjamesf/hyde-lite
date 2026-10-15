pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config as Config

// File picker (HyDE's `rofilaunch.sh f`, which opened rofi's file browser): folders and files under
// the configured roots (home by default), opened with `xdg-open` (Launch.open).
// The list is read once per opening with `fd` (no hidden files, .gitignore honoured; `find` when fd
// is missing), limited by depth and entry count; searching filters that list in JS.
// Roots, depth, limits and excluded names are in config/PickersConfig.qml (`files`).
Singleton {
    id: root

    readonly property string name: "files"
    readonly property string title: "Files"
    readonly property string placeholder: "Search files…"
    readonly property string glyph: "folder"
    readonly property bool loading: proc.running && entries.length === 0
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property string home: Paths.home
    readonly property var cfg: Config.PickersConfig.files
    // Absolute roots, without trailing slashes.
    readonly property var roots: (cfg.roots ?? ["~"]).map(r => Paths.expand(r).replace(/\/+$/, "") || "/")
    readonly property int maxEntries: cfg.maxEntries ?? 5000
    readonly property int maxResults: cfg.maxResults ?? 200

    // [{ path, name, lname, dir, isDir, depth }]
    property var entries: []
    // No search: the shallowest entries first (folders before files).
    property var shallow: []

    // Big or generated folders nobody wants to browse (hidden ones are skipped anyway).
    readonly property var excludes: (cfg.excludes ?? []).map(e => String(e).replace(/'/g, ""))

    // Roots are passed as "$@" (never interpolated).
    readonly property string script: {
        const depth = Math.max(1, cfg.maxDepth ?? 6);
        const ex = excludes.map(e => `--exclude '${e}'`).join(" ");
        const prune = ["-name '.*'"].concat(excludes.map(e => `-name '${e}'`)).join(" -o ");
        return `if command -v fd >/dev/null 2>&1; then fd . "$@" --type f --type d --max-depth ${depth} --absolute-path ${ex} 2>/dev/null; ` + `else find "$@" -mindepth 1 -maxdepth ${depth} \\( ${prune} \\) -prune -o \\( -type d -printf '%p/\\n' -o -type f -print \\) 2>/dev/null; fi | head -n ${maxEntries}`;
    }

    // Root that contains `path` (the longest match), or "".
    function rootOf(path) {
        let best = "";
        for (const r of roots)
            if ((path === r || path.startsWith(r === "/" ? "/" : r + "/")) && r.length > best.length)
                best = r;
        return best;
    }

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    function tilde(p) {
        return home !== "" && p.startsWith(home) ? "~" + p.slice(home.length) : p;
    }

    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (line === "")
                continue;
            const isDir = line.endsWith("/");
            const path = isDir ? line.replace(/\/+$/, "") : line;
            const cut = path.lastIndexOf("/");
            const name = path.slice(cut + 1);
            const base = rootOf(path);
            const rel = base === "" ? path : path.slice(base === "/" ? 1 : base.length + 1);
            out.push({
                "path": path,
                "name": name,
                "lname": name.toLowerCase(),
                "lrel": rel.toLowerCase(),
                "dir": tilde(path.slice(0, cut)) || "/",
                "isDir": isDir,
                "depth": rel.split("/").length
            });
        }
        return out;
    }

    // MIME-type icon from the extension (cheap; no `file` or `xdg-mime` per entry).
    readonly property var extIcons: ({
            "png": "image-x-generic",
            "jpg": "image-x-generic",
            "jpeg": "image-x-generic",
            "gif": "image-x-generic",
            "webp": "image-x-generic",
            "svg": "image-svg+xml",
            "bmp": "image-x-generic",
            "avif": "image-x-generic",
            "mp4": "video-x-generic",
            "mkv": "video-x-generic",
            "webm": "video-x-generic",
            "mov": "video-x-generic",
            "avi": "video-x-generic",
            "mp3": "audio-x-generic",
            "flac": "audio-x-generic",
            "ogg": "audio-x-generic",
            "wav": "audio-x-generic",
            "opus": "audio-x-generic",
            "m4a": "audio-x-generic",
            "pdf": "application-pdf",
            "epub": "application-epub+zip",
            "doc": "x-office-document",
            "docx": "x-office-document",
            "odt": "x-office-document",
            "rtf": "x-office-document",
            "xls": "x-office-spreadsheet",
            "xlsx": "x-office-spreadsheet",
            "ods": "x-office-spreadsheet",
            "csv": "x-office-spreadsheet",
            "ppt": "x-office-presentation",
            "pptx": "x-office-presentation",
            "odp": "x-office-presentation",
            "zip": "package-x-generic",
            "tar": "package-x-generic",
            "gz": "package-x-generic",
            "xz": "package-x-generic",
            "zst": "package-x-generic",
            "7z": "package-x-generic",
            "rar": "package-x-generic",
            "deb": "package-x-generic",
            "rpm": "package-x-generic",
            "appimage": "application-x-executable",
            "iso": "application-x-cd-image",
            "sh": "text-x-script",
            "bash": "text-x-script",
            "zsh": "text-x-script",
            "fish": "text-x-script",
            "py": "text-x-python",
            "js": "text-x-javascript",
            "ts": "text-x-javascript",
            "qml": "text-x-qml",
            "c": "text-x-csrc",
            "h": "text-x-chdr",
            "cpp": "text-x-c++src",
            "rs": "text-rust",
            "go": "text-x-go",
            "java": "text-x-java",
            "lua": "text-x-lua",
            "html": "text-html",
            "css": "text-css",
            "json": "application-json",
            "xml": "text-xml",
            "md": "text-markdown",
            "txt": "text-plain",
            "log": "text-x-log",
            "conf": "text-x-generic",
            "toml": "text-x-generic",
            "yaml": "text-x-generic",
            "yml": "text-x-generic",
            "ttf": "font-x-generic",
            "otf": "font-x-generic",
            "desktop": "application-x-desktop"
        })

    function iconOf(e) {
        if (e.isDir)
            return "folder";
        const dot = e.lname.lastIndexOf(".");
        return (dot > 0 ? extIcons[e.lname.slice(dot + 1)] : undefined) ?? "text-x-generic";
    }

    function row(e) {
        return {
            "key": e.path,
            "title": e.name,
            "subtitle": e.dir,
            "icon": iconOf(e),
            "text": "",
            "badge": "",
            "path": e.path
        };
    }

    // Score: same name > prefix > word start > substring in the name > path > subsequence.
    function score(q, e, wordRe) {
        const n = e.lname;
        if (n === q)
            return 120;
        if (n.startsWith(q))
            return 100 - Math.min(20, n.length - q.length);
        const w = n.search(wordRe);
        if (w >= 0)
            return 85 - Math.min(15, w);
        const idx = n.indexOf(q);
        if (idx >= 0)
            return 70 - Math.min(20, idx);
        if (e.lrel.includes(q))
            return 45;
        // Subsequence in the name.
        let ti = 0, gaps = 0, last = -1;
        for (const ch of q) {
            const found = n.indexOf(ch, ti);
            if (found < 0)
                return 0;
            if (last >= 0 && found > last + 1)
                gaps++;
            last = found;
            ti = found + 1;
        }
        return Math.max(1, 30 - gaps * 6);
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        if (q === "")
            return shallow.map(row);
        const wordRe = new RegExp(`(^|[\\s\\-_.])${q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`);
        const scored = [];
        for (const e of entries) {
            const s = score(q, e, wordRe);
            if (s > 0)
                scored.push({
                    e,
                    s: s - Math.min(10, e.depth)
                });
        }
        return scored.sort((a, b) => b.s - a.s || a.e.path.length - b.e.path.length).slice(0, maxResults).map(x => row(x.e));
    }

    function activate(item) {
        if (item?.path)
            Launch.open(item.path);
    }

    Process {
        id: proc
        command: ["sh", "-c", root.script, "sh"].concat(root.roots)
        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.parse(text);
                root.entries = list;
                root.shallow = list.slice().sort((a, b) => a.depth - b.depth || (b.isDir - a.isDir) || a.lname.localeCompare(b.lname)).slice(0, root.maxResults);
            }
        }
    }
}
