pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// HyDE theme picker (port of `hyde-shell theme.select`, HyDE's rofi theme selector).
//
// List: like get_themes in globalcontrol.sh, every folder in ~/.config/hyde/themes, ordered by the
// number in its .sort file (0 when missing) and then by name. Current: HYDE_THEME in
// ~/.local/state/hyde/staterc (overridden by ~/.local/state/hyde/config when it exists).
// Subtitle: the theme's colour scheme ($COLOR_SCHEME in hypr.theme, else dcol_mode in theme.dcol)
// and GTK theme. Icon: HyDE's square thumbnail of the theme's current wallpaper
// (${HYDE_CACHE_HOME:-~/.cache/hyde}/thumbs/<sha1 of the wallpaper>.sqre, the same file the rofi
// selector shows), when it exists.
//
// Applying runs exactly what theme.select.sh does after a choice:
// `"$LIB_DIR/hyde/theme.switch.sh" -s "<name>"` (also reachable as `hyde-shell theme.switch -s`)
// followed by the same notification. theme.switch.sh ignores unknown names (keeps the theme).
Singleton {
    id: root

    readonly property string name: "themes"
    readonly property string title: "HyDE themes"
    readonly property string placeholder: "Search themes…"
    readonly property string glyph: "󰏘"
    readonly property bool loading: _loading && _list.length === 0
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property string themesDir: `${Hyde.configDir}/themes`
    readonly property string thumbDir: `${Quickshell.env("HYDE_CACHE_HOME") || Paths.cacheHome + "/hyde"}/thumbs`

    // [{ key, title, subtitle, icon, sort }] in HyDE's order.
    property var _list: []
    property string _currentKey: ""
    property bool _loading: false
    property bool _again: false

    // One pass over the theme folders (the paths are "$1"… never interpolated): name, .sort,
    // colour scheme, dcol_mode, GTK theme and the wallpaper's sha1 when its thumbnail exists
    // (~5 ms per theme), then the state files after a marker.
    readonly property string script: "d=\"$1\"; td=\"$2\"; shift 2\nfind -H \"$d\" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r t; do\n  s=$(head -n 1 \"$t/.sort\" 2>/dev/null)\n  cs=$(sed -n 's/^\\$COLOR_SCHEME[[:space:]]*=[[:space:]]*//p' \"$t/hypr.theme\" 2>/dev/null | head -n 1)\n  dm=$(sed -n 's/^dcol_mode=[\"'\"'\"']*\\([a-z]*\\).*/\\1/p' \"$t/theme.dcol\" 2>/dev/null | head -n 1)\n  gtk=$(sed -n 's/^\\$GTK_THEME[[:space:]]*=[[:space:]]*//p' \"$t/hypr.theme\" 2>/dev/null | head -n 1)\n  w=$(readlink -f \"$t/wall.set\" 2>/dev/null); h=\"\"\n  [ -f \"$w\" ] && h=$(sha1sum \"$w\" | cut -d \" \" -f 1)\n  [ -n \"$h\" ] && [ ! -f \"$td/$h.sqre\" ] && h=\"\"\n  printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"${t##*/}\" \"${s:-0}\" \"$cs\" \"$dm\" \"$gtk\" \"$h\"\ndone\necho \"@@CURRENT@@\"; cat \"$@\" 2>/dev/null; true\n"

    // Rereads the themes and the current one (called whenever the picker opens).
    function refresh() {
        if (reader.running) {
            // A read is already running: repeat it at the end, the files may have changed.
            _again = true;
            return;
        }
        _loading = true;
        reader.running = true;
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const cur = _currentKey;
        const decorate = it => ({
                key: it.key,
                title: it.title,
                subtitle: it.subtitle,
                icon: it.icon,
                text: "",
                glyph: it.icon === "" ? root.glyph : "",
                badge: it.key === cur ? "Current" : ""
            });
        // No search: the current theme first, the rest in HyDE's order.
        if (q === "")
            return Fuzzy.currentFirst(_list, cur).map(decorate);
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
        return scored.map(e => decorate(e.it));
    }

    function activate(item) {
        if (!item || !item.key || !_list.some(it => it.key === item.key))
            return;
        // Optimistic: the next refresh() confirms it.
        _currentKey = item.key;
        // theme.switch.sh takes a few seconds and must finish even if the island restarts:
        // Hyde.initRun goes through Launch.run (its own unit, outside the island's cgroup).
        Hyde.initRun('"$LIB_DIR/hyde/theme.switch.sh" -s "$1"; notify-send -a "HyDE Alert" -i "$iconsDir/Wallbash-Icon/hyde.png" " $1"', [item.key]);
    }

    function _scheme(colorScheme, dcolMode) {
        const cs = String(colorScheme).trim().toLowerCase();
        const mode = cs.includes("dark") ? "dark" : cs.includes("light") ? "light" : String(dcolMode).trim().toLowerCase();
        return mode === "" ? "" : mode.charAt(0).toUpperCase() + mode.slice(1);
    }

    function _parse(text) {
        const marker = "@@CURRENT@@";
        const at = text.indexOf(marker);
        const listing = at >= 0 ? text.slice(0, at) : text;
        const list = [];
        for (const line of listing.split("\n")) {
            const f = line.split("\t");
            if (f.length < 6 || f[0] === "")
                continue;
            const thumb = f[5] !== "" ? `${thumbDir}/${f[5]}.sqre` : "";
            list.push({
                key: f[0],
                title: f[0],
                subtitle: [_scheme(f[2], f[3]), f[4].trim()].filter(s => s !== "").join(" · "),
                icon: thumb,
                sort: parseInt(f[1]) || 0
            });
        }
        // Same order as get_themes: `sort -n -k 1 -k 2` on "sort|name".
        list.sort((a, b) => a.sort - b.sort || (a.title < b.title ? -1 : a.title > b.title ? 1 : 0));
        _list = list;
        _currentKey = at >= 0 ? Hyde.confValue(text.slice(at + marker.length), "HYDE_THEME", "") : "";
        _loading = false;
    }

    Process {
        id: reader
        command: ["sh", "-c", root.script, "sh", root.themesDir, root.thumbDir].concat(Hyde.stateFiles)
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
