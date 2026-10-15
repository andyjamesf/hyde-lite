pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config as Config

// Browser bookmarks picker for the island launcher (port of HyDE's rofi.bookmarks.sh +
// bookmarks.py). Sources, read by a small Python script on every opening:
//   - Firefox: ~/.mozilla/firefox/**/places.sqlite (opened with immutable=1, so a running
//     Firefox's lock does not get in the way);
//   - Chromium and derivatives: ${XDG_CONFIG_HOME}/<browser>/{Default,Profile N}/Bookmarks
//     (Brave, Brave Origin/Beta/Nightly, Chromium, Chrome, Vivaldi);
//   - HyDE's own list: ${XDG_CONFIG_HOME}/hyde/bookmarks.lst ("title | url").
// Differences from HyDE: bookmark folders are walked recursively (HyDE only reads the first level
// of the bar and "Other"), and profiles besides Default plus Brave Origin are included.
// Duplicates (same URL) are merged into one entry. Recents (PickersConfig.recents.bookmarks) are kept by
// PickerStore under the key "bookmarks".
// activate() opens the URL with Launch.open (xdg-open), like bookmarks.py without --browser.
Singleton {
    id: root

    readonly property string name: "bookmarks"
    readonly property string title: "Bookmarks"
    readonly property string placeholder: "Search bookmarks…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property int maxResults: Config.PickersConfig.maxResults.bookmarks ?? 200

    property bool _loading: false
    // [{ title, url, host, sources, low }] sorted by title (like HyDE).
    property var _all: []

    // Python script (standard library only) that prints a JSON array [{ title, url, source }].
    // Run with `python3 -c`, no helper files.
    readonly property string script: [
        'import glob, json, os, sqlite3, sys',
        'home = os.path.expanduser("~")',
        'cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config")',
        'out = []',
        'def add(title, url, source):',
        '    if url and not url.startswith(("javascript:", "place:")):',
        '        out.append({"title": title or url, "url": url, "source": source})',
        'for places in glob.glob(os.path.join(home, ".mozilla/firefox/**/places.sqlite"), recursive=True):',
        '    try:',
        '        con = sqlite3.connect("file:" + places + "?immutable=1", uri=True)',
        '        q = "SELECT b.title, p.url FROM moz_bookmarks AS b LEFT JOIN moz_places AS p ON b.fk = p.id WHERE b.type = 1 AND p.hidden = 0 AND b.title IS NOT NULL"',
        '        for t, u in con.execute(q):',
        '            add(t, u, "Firefox")',
        '        con.close()',
        '    except Exception as e:',
        '        print("firefox: %s" % e, file=sys.stderr)',
        'chromium = [("BraveSoftware/Brave-Browser", "Brave"), ("BraveSoftware/Brave-Origin-Beta", "Brave Origin"), ("BraveSoftware/Brave-Browser-Beta", "Brave Beta"), ("BraveSoftware/Brave-Browser-Nightly", "Brave Nightly"), ("chromium", "Chromium"), ("google-chrome", "Chrome"), ("vivaldi", "Vivaldi")]',
        'def walk(node, source):',
        '    if node.get("type") == "url" or "url" in node:',
        '        add(node.get("name"), node.get("url"), source)',
        '    for c in node.get("children", []):',
        '        walk(c, source)',
        'for d, label in chromium:',
        '    for f in sorted(glob.glob(os.path.join(cfg, d, "*", "Bookmarks"))):',
        '        prof = os.path.basename(os.path.dirname(f))',
        '        if prof != "Default" and not prof.startswith("Profile "):',
        '            continue',
        '        try:',
        '            with open(f) as fh:',
        '                roots = json.load(fh).get("roots", {})',
        '            for r in roots.values():',
        '                if isinstance(r, dict):',
        '                    walk(r, label)',
        '        except Exception as e:',
        '            print("%s: %s" % (f, e), file=sys.stderr)',
        'lst = os.path.join(cfg, "hyde/bookmarks.lst")',
        'if os.path.isfile(lst):',
        '    with open(lst) as fh:',
        '        for line in fh:',
        '            line = line.strip()',
        '            if "|" in line:',
        '                t, u = [x.strip() for x in line.split("|", 1)]',
        '                add(t, u, "HyDE")',
        'json.dump(out, sys.stdout)'
    ].join("\n")

    function refresh() {
        _loading = true;
        reader.running = false;
        reader.running = true;
    }

    function _host(url) {
        const m = String(url).match(/^[a-z][a-z0-9+.-]*:\/\/([^/?#]+)/i);
        return m ? m[1].replace(/^www\./, "").replace(/^[^@]*@/, "") : String(url).split(/[/?#]/)[0];
    }

    function _parse(text) {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            raw = [];
        }
        const byUrl = {};
        const list = [];
        for (const b of raw) {
            if (!b || !b.url)
                continue;
            const known = byUrl[b.url];
            if (known) {
                if (!known.sources.includes(b.source))
                    known.sources.push(b.source);
                continue;
            }
            const e = {
                title: String(b.title || b.url),
                url: String(b.url),
                host: _host(b.url),
                sources: [b.source]
            };
            e.low = `${e.title} ${e.url}`.toLowerCase();
            byUrl[e.url] = e;
            list.push(e);
        }
        _all = list.sort((a, b) => a.title.toLowerCase().localeCompare(b.title.toLowerCase()));
        _loading = false;
    }

    function _item(e) {
        return {
            key: e.url,
            title: e.title,
            subtitle: e.host,
            icon: "bookmarks",
            text: "",
            badge: e.sources.join(", ")
        };
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const recent = PickerStore.bookmarks ?? [];
        if (q === "") {
            // No search: recents first, then everything alphabetically.
            const rec = recent.map(u => _all.find(e => e.url === u)).filter(e => !!e);
            return rec.concat(_all.filter(e => !recent.includes(e.url))).slice(0, maxResults).map(_item);
        }
        const scored = [];
        for (const e of _all) {
            // Fuzzy on the title and the domain; the full URL only by substring (a subsequence in a
            // long URL would match almost anything).
            const s = Math.max(Fuzzy.score(q, e.title, "/", 40, false), Fuzzy.score(q, e.host, "/", 40, false) * 0.8, e.url.toLowerCase().includes(q) ? 30 : 0);
            if (s > 0) {
                const r = recent.indexOf(e.url);
                scored.push({
                    e,
                    s: s + (r >= 0 ? 15 - r : 0)
                });
            }
        }
        return scored.sort((a, b) => b.s - a.s || a.e.title.localeCompare(b.e.title)).slice(0, maxResults).map(x => _item(x.e));
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        PickerStore.push("bookmarks", item.key);
        Launch.open(item.key);
    }

    Process {
        id: reader
        command: ["python3", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        // No python3 or no browsers: empty list, no error.
        onExited: code => {
            if (code !== 0) {
                root._all = [];
                root._loading = false;
            }
        }
    }
}
