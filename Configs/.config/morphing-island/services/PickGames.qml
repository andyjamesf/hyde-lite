pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config as Config

// Games picker for the island launcher (port of HyDE's gamelauncher.sh, "catalog" backend, which
// merges Steam and Lutris). A small Python script (standard library only) runs on every opening and
// prints [{ launcher, id, name, art }]:
//   - Steam: libraries in ~/.local/share/Steam, ~/.steam/steam and flatpak
//     (~/.var/app/com.valvesoftware.Steam/…), plus those in libraryfolders.vdf; reads the
//     appmanifest_*.acf files and skips Proton/Steam Runtime/Steamworks (same filter as steam.py);
//     cover from appcache/librarycache (vertical capsule > hero > header) or from HyDE's cache
//     (~/.cache/hyde/gamelauncher/steam_<id>.jpg). Covers are never downloaded (HyDE only does
//     that with --fetch-icons).
//   - Lutris: pga.db (native or flatpak), installed games only; cover in lutris/coverart/<slug>.
// Heroic is not supported by HyDE's script, so it is not here either.
// activate() uses the same command as HyDE: `xdg-open steam://rungameid/<id>` or
// `xdg-open lutris:rungame/<slug>` (through Launch.open).
Singleton {
    id: root

    readonly property string name: "games"
    readonly property string title: "Games"
    readonly property string placeholder: "Search games…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property int maxResults: Config.PickersConfig.maxResults.games ?? 200

    property bool _loading: false
    // [{ launcher, id, name, art, low }] in alphabetical order.
    property var _all: []

    readonly property string script: [
        "import glob, json, os, re, sqlite3, sys",
        "home = os.path.expanduser(\"~\")",
        "data = os.environ.get(\"XDG_DATA_HOME\") or os.path.join(home, \".local/share\")",
        "cache = os.environ.get(\"XDG_CACHE_HOME\") or os.path.join(home, \".cache\")",
        "out = []",
        "bases = [os.path.join(data, \"Steam\"), os.path.join(home, \".local/share/Steam\"), os.path.join(home, \".var/app/com.valvesoftware.Steam/.local/share/Steam\"), os.path.join(home, \".steam/steam\")]",
        "roots = []",
        "for b in bases:",
        "    if os.path.isdir(b):",
        "        roots.append(b)",
        "        vdf = os.path.join(b, \"steamapps/libraryfolders.vdf\")",
        "        try:",
        "            with open(vdf, errors=\"ignore\") as fh:",
        "                for m in re.finditer(r'\"path\"\\s*\"([^\"]+)\"', fh.read()):",
        "                    roots.append(os.path.expanduser(m.group(1).replace(\"\\\\\\\\\", \"\\\\\")))",
        "        except OSError:",
        "            pass",
        "seen = set()",
        "libs = []",
        "caches = []",
        "for r in roots:",
        "    real = os.path.realpath(r)",
        "    if real in seen or not os.path.isdir(os.path.join(real, \"steamapps\")):",
        "        continue",
        "    seen.add(real)",
        "    libs.append(os.path.join(real, \"steamapps\"))",
        "    lc = os.path.join(real, \"appcache/librarycache\")",
        "    if os.path.isdir(lc):",
        "        caches.append(lc)",
        "def art(appid):",
        "    dirs = [os.path.join(lc, appid) for lc in caches if os.path.isdir(os.path.join(lc, appid))]",
        "    subs = [s for d in dirs for s in sorted(glob.glob(os.path.join(d, \"*\", \"\")))]",
        "    for names, where in (((\"library_600x900.jpg\", \"library_capsule.jpg\"), dirs), ((\"library_capsule.jpg\", \"library_600x900.jpg\"), subs), ((\"library_hero.jpg\",), dirs + subs), ((\"header.jpg\",), dirs + subs)):",
        "        for d in where:",
        "            for n in names:",
        "                p = os.path.join(d, n)",
        "                if os.path.isfile(p):",
        "                    return p",
        "    p = os.path.join(cache, \"hyde/gamelauncher\", \"steam_%s.jpg\" % appid)",
        "    return p if os.path.isfile(p) else \"\"",
        "skip = re.compile(r\"(?i)\\b(proton|steam runtime|steamworks|steam client|steam)\\b\")",
        "ids = set()",
        "for lib in libs:",
        "    for acf in glob.glob(os.path.join(lib, \"appmanifest_*.acf\")):",
        "        try:",
        "            with open(acf, errors=\"ignore\") as fh:",
        "                txt = fh.read()",
        "        except OSError:",
        "            continue",
        "        mi = re.search(r'\"appid\"\\s*\"(\\d+)\"', txt)",
        "        mn = re.search(r'\"name\"\\s*\"([^\"]+)\"', txt)",
        "        if not mi or not mn or skip.search(mn.group(1)) or mi.group(1) in ids:",
        "            continue",
        "        ids.add(mi.group(1))",
        "        out.append({\"launcher\": \"steam\", \"id\": mi.group(1), \"name\": mn.group(1), \"art\": art(mi.group(1))})",
        "ldirs = [os.path.join(data, \"lutris\"), os.path.join(home, \".local/share/lutris\"), os.path.join(home, \".var/app/net.lutris.Lutris/data/lutris\")]",
        "dbs = [p for d in ldirs for p in (os.path.join(d, \"pga.db\"), os.path.join(d, \"lutris.db\"), os.path.join(d, \"db.sqlite\")) if os.path.isfile(p)]",
        "dbs.sort(key=os.path.getmtime, reverse=True)",
        "if dbs:",
        "    try:",
        "        con = sqlite3.connect(\"file:\" + dbs[0] + \"?mode=ro\", uri=True)",
        "        cols = [c[1] for c in con.execute(\"PRAGMA table_info(games)\")]",
        "        q = \"SELECT name, slug FROM games\" + (\" WHERE installed = 1\" if \"installed\" in cols else \"\")",
        "        for name, slug in con.execute(q):",
        "            if not name or not slug:",
        "                continue",
        "            cover = \"\"",
        "            for d in ldirs + [os.path.join(cache, \"lutris\")]:",
        "                for ext in (\"jpg\", \"png\"):",
        "                    p = os.path.join(d, \"coverart\", slug + \".\" + ext)",
        "                    if not cover and os.path.isfile(p):",
        "                        cover = p",
        "            out.append({\"launcher\": \"lutris\", \"id\": slug, \"name\": name, \"art\": cover})",
        "        con.close()",
        "    except Exception as e:",
        "        print(\"lutris: %s\" % e, file=sys.stderr)",
        "json.dump(out, sys.stdout)"
    ].join("\n")

    function refresh() {
        _loading = true;
        reader.running = false;
        reader.running = true;
    }

    function _parse(text) {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            raw = [];
        }
        _all = raw.filter(g => g && g.id && g.name).map(g => ({
                    launcher: String(g.launcher),
                    id: String(g.id),
                    name: String(g.name),
                    art: g.art ? String(g.art) : "",
                    low: String(g.name).toLowerCase()
                })).sort((a, b) => a.low.localeCompare(b.low));
        _loading = false;
    }

    function _item(g) {
        const launcher = g.launcher === "lutris" ? "Lutris" : "Steam";
        return {
            key: `${g.launcher}:${g.id}`,
            title: g.name,
            subtitle: launcher,
            // Cached cover when there is one; otherwise the launcher's icon.
            icon: g.art ? `file://${encodeURI(g.art)}` : g.launcher,
            text: "",
            badge: ""
        };
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        if (q === "")
            return _all.slice(0, maxResults).map(_item);
        const scored = [];
        for (const g of _all) {
            const s = Math.max(Fuzzy.score(q, g.low, ":", 40, false), Fuzzy.score(q, g.launcher, ":", 40, false) * 0.3);
            if (s > 0)
                scored.push({
                    g,
                    s
                });
        }
        return scored.sort((a, b) => b.s - a.s || a.g.low.localeCompare(b.g.low)).slice(0, maxResults).map(x => _item(x.g));
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        const sep = item.key.indexOf(":");
        const launcher = item.key.slice(0, sep);
        const id = item.key.slice(sep + 1);
        if (launcher === "steam")
            Launch.open(`steam://rungameid/${id}`);
        else if (launcher === "lutris")
            Launch.open(`lutris:rungame/${id}`);
    }

    Process {
        id: reader
        command: ["python3", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        // No python3, Steam or Lutris: empty list, no error.
        onExited: code => {
            if (code !== 0) {
                root._all = [];
                root._loading = false;
            }
        }
    }
}
