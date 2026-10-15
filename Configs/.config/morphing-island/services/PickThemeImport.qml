pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// HyDE gallery picker: the themes that can be downloaded (port of `hyde-shell theme.import --select`,
// HyDE's fzf gallery selector). PickHydeThemes switches between the themes already installed; this
// one installs new ones.
//
// List: the gallery database HyDE keeps in ~/.cache/hyde/gallery-database (a shallow clone of
// HyDE-Project/hyde-gallery). `theme.import --json` prints it as
// [{ THEME, LINK, OWNER, DESCRIPTION, COLORSCHEME, PREVIEW }]; with --skip-clone it reads the clone
// that is already there, so opening the picker never waits on the network. The clone is only made
// when it is missing, and refreshed by the "Update gallery" row at the end of the list.
//
// Icon: the theme's screenshot from the clone (PREVIEW). Themes already in ~/.config/hyde/themes are
// badged "Installed" — choosing one again re-downloads it, which is how HyDE updates a theme.
//
// Applying runs what patch_single_theme does in theme.import.py:
// `theme.patch.sh <name> <link> --skipcaching`, then `hyde-shell reload`. It takes a while and must
// finish even if the island restarts, so it goes through Hyde.initRun (its own unit).
Singleton {
    id: root

    readonly property string name: "themeimport"
    readonly property string title: "Download themes"
    readonly property string placeholder: "Search the HyDE gallery…"
    readonly property string glyph: "󰇚"
    readonly property bool loading: _loading && _list.length === 0
    readonly property bool grid: false
    readonly property bool keepOpen: false
    readonly property string emptyText: "No themes found in the gallery database."

    readonly property string themesDir: `${Hyde.configDir}/themes`
    readonly property string galleryDir: `${Quickshell.env("HYDE_CACHE_HOME") || Paths.cacheHome + "/hyde"}/gallery-database`

    // Key of the row that refreshes the clone (the only row that is not a theme).
    readonly property string updateKey: "@@update@@"

    // [{ key, title, subtitle, icon, link, installed }], alphabetical.
    property var _list: []
    property bool _loading: false
    property bool _again: false

    // The gallery as JSON, then the installed theme names after a marker. The clone is only fetched
    // when it is missing, so every later opening is instant and offline.
    readonly property string script: `g="$1"; d="$2"
if [ -f "$g/hyde-themes.json" ]; then
  hyde-shell theme.import --skip-clone --json 2>/dev/null
else
  hyde-shell theme.import --json 2>/dev/null
fi
echo
echo "@@INSTALLED@@"
ls -1 "$d" 2>/dev/null
true
`

    // Rereads the gallery and which themes are installed (called whenever the picker opens).
    function refresh() {
        if (reader.running) {
            // A read is already running: repeat it at the end, the clone may have changed.
            _again = true;
            return;
        }
        _loading = true;
        reader.running = true;
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const decorate = it => ({
                key: it.key,
                title: it.title,
                subtitle: it.subtitle,
                icon: it.icon,
                text: "",
                glyph: it.icon === "" ? root.glyph : "",
                badge: it.installed ? "Installed" : ""
            });
        const update = {
            key: root.updateKey,
            title: "Update gallery",
            subtitle: "Fetch the newest themes from hyde-gallery",
            icon: "",
            text: "",
            glyph: "󰑐",
            badge: ""
        };
        // No search: the gallery in alphabetical order, with the refresh row last.
        if (q === "")
            return _list.map(decorate).concat([update]);
        const scored = [];
        for (const it of _list) {
            const s = Math.max(Fuzzy.score(q, it.title), it.subtitle.toLowerCase().includes(q) ? 35 : 0);
            if (s > 0)
                scored.push({
                    s: s,
                    it: it
                });
        }
        scored.sort((a, b) => b.s - a.s);
        const out = scored.map(e => decorate(e.it));
        if (Fuzzy.score(q, update.title) > 0)
            out.push(update);
        return out;
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        if (item.key === updateKey) {
            Launch.run(["bash", "-c", 'hyde-shell theme.import --json >/dev/null 2>&1 && notify-send -a "HyDE Alert" "Gallery updated" || notify-send -a "HyDE Alert" -u critical "Could not reach the gallery"']);
            return;
        }
        const entry = _list.find(it => it.key === item.key);
        if (!entry || entry.link === "")
            return;
        Hyde.initRun('notify-send -a "HyDE Alert" -i "$iconsDir/Wallbash-Icon/hyde.png" "󰇚 Downloading $1…"; if "$LIB_DIR/hyde/theme.patch.sh" "$1" "$2" --skipcaching; then hyde-shell reload; wallpaper-library >/dev/null 2>&1; notify-send -a "HyDE Alert" -i "$iconsDir/Wallbash-Icon/hyde.png" " $1 installed"; else notify-send -a "HyDE Alert" -u critical " Could not install $1"; fi', [entry.key, entry.link]);
    }

    // "https://github.com/user" → "by user" (the gallery has no plain author name).
    function _owner(link) {
        const m = /([^/]+)\/?$/.exec(String(link ?? "").trim());
        return m ? `by ${m[1]}` : "";
    }

    function _parse(text) {
        const marker = "@@INSTALLED@@";
        const at = text.indexOf(marker);
        const installed = at >= 0 ? text.slice(at + marker.length).split("\n").map(s => s.trim()).filter(s => s !== "") : [];
        let data = null;
        try {
            data = JSON.parse((at >= 0 ? text.slice(0, at) : text).trim());
        } catch (e) {
            data = null;
        }
        if (!Array.isArray(data)) {
            // No clone yet, or git left the database half-written: keep the list we already had.
            _loading = false;
            return;
        }
        const list = [];
        for (const t of data) {
            const key = String(t.THEME ?? "").trim();
            if (key === "")
                continue;
            const preview = Array.isArray(t.PREVIEW) && t.PREVIEW.length > 0 ? String(t.PREVIEW[0]) : "";
            list.push({
                key: key,
                title: key,
                subtitle: String(t.DESCRIPTION ?? "").trim() || _owner(t.OWNER),
                icon: preview,
                link: String(t.LINK ?? "").trim(),
                installed: installed.indexOf(key) >= 0
            });
        }
        list.sort((a, b) => {
            const x = a.title.toLowerCase(), y = b.title.toLowerCase();
            return x < y ? -1 : x > y ? 1 : 0;
        });
        _list = list;
        _loading = false;
    }

    Process {
        id: reader
        command: ["sh", "-c", root.script, "sh", root.galleryDir, root.themesDir]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                root.refresh();
            }
        }
    }
}
