pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared.services

// Nerd Font glyph picker for the launcher (port of HyDE's glyph-picker.sh).
// Data: ${HYDE_DATA_HOME:-~/.local/share/hyde}/glyph.db, one glyph per line as
// "<glyph>\t<family>-<name>" (e.g. "<glyph>\tcod-account"), ~10 800 entries.
// The file is only read and parsed on the first opening; afterwards it stays in memory.
// Recents (PickerSettings.recents.glyph) are kept by PickerStore under the key "glyph".
// The view draws `text` with the `textFont` family (the glyphs live in the Private Use Area).
//
// NOTE: activate() copies the glyph and pastes it into the focused window with Ctrl+V
// (Launch.pasteText) ON PURPOSE — it is exactly what HyDE does (paste_string in globalcontrol.sh)
// and the whole point of this picker, not a testing shortcut.
Singleton {
    id: root

    readonly property string name: "glyph"
    readonly property string title: "Glyphs"
    readonly property string placeholder: "Search Nerd Font glyphs…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: true
    readonly property bool keepOpen: false
    readonly property string textFont: PickerSettings.glyphFont

    readonly property int maxResults: PickerSettings.maxResults.glyph ?? 300
    readonly property string dataHome: Quickshell.env("HYDE_DATA_HOME") || `${Paths.dataHome}/hyde`

    // Name prefix in glyph.db → readable name of the Nerd Fonts icon set.
    readonly property var families: ({
            cod: "Codicons",
            custom: "Custom",
            dev: "Devicons",
            extra: "Extra",
            fa: "Font Awesome",
            fae: "Font Awesome Extension",
            iec: "IEC Power Symbols",
            indent: "Indentation",
            indentation: "Indentation",
            linux: "Font Logos",
            md: "Material Design",
            oct: "Octicons",
            pl: "Powerline",
            ple: "Powerline Extra",
            pom: "Pomicons",
            seti: "Seti UI",
            weather: "Weather Icons"
        })

    property bool _loading: false
    property bool _requested: false
    // [{ ch, id, fam, low }] in file order.
    property var _all: []
    property var _byId: ({})

    function refresh() {
        // Read once and kept; but when that read left nothing (it was cut short, or the file was not
        // there yet), opening the picker again reads it again instead of showing an empty grid for good.
        if (_requested && (_loading || _all.length > 0))
            return;
        _requested = true;
        _loading = true;
        const path = `${dataHome}/glyph.db`;
        if (db.path === path)
            db.reload();
        else
            db.path = path;
    }

    function _parse(text) {
        const list = [];
        const map = {};
        for (const line of String(text).split("\n")) {
            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;
            const ch = line.slice(0, tab);
            const id = line.slice(tab + 1).trim();
            if (!id || map[id])
                continue;
            const dash = id.indexOf("-");
            const prefix = dash > 0 ? id.slice(0, dash) : id;
            const e = {
                ch,
                id,
                fam: families[prefix] ?? prefix,
                // Searches "cod account" and "codicons": hyphens and underscores count as spaces.
                low: ` ${id.replace(/[-_]/g, " ")} ${(families[prefix] ?? "")} `.toLowerCase()
            };
            map[id] = e;
            list.push(e);
        }
        _byId = map;
        _all = list;
        _loading = false;
    }

    function _item(e) {
        return {
            key: e.id,
            title: e.id,
            subtitle: e.fam,
            icon: "",
            text: e.ch,
            badge: ""
        };
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase().replace(/[-_]/g, " ");
        const recent = PickerStore.glyph ?? [];
        if (q === "") {
            // No search: recents first, then the rest in file order.
            const rec = recent.filter(id => _byId[id]).map(id => _byId[id]);
            const seen = {};
            for (const e of rec)
                seen[e.id] = true;
            return rec.concat(_all.slice(0, maxResults).filter(e => !seen[e.id])).slice(0, maxResults).map(_item);
        }
        const terms = q.split(/\s+/).map(term => ({
                    term,
                    word: ` ${term} `
                }));
        const scored = [];
        // Local copies: calling a QML method or reading an object property for each of thousands
        // of entries is several times slower than a local JS function.
        const all = _all;
        const score = Fuzzy.termScore;
        for (const e of all) {
            let s = 0;
            for (const t of terms) {
                const ts = score(t, e.low);
                if (ts === 0) {
                    s = 0;
                    break;
                }
                s += ts;
            }
            if (s > 0) {
                const r = recent.indexOf(e.id);
                scored.push({
                    e,
                    s: s + (r >= 0 ? 20 - r / 2 : 0) - Math.min(10, e.low.length / 8)
                });
            }
        }
        return scored.sort((a, b) => b.s - a.s).slice(0, maxResults).map(x => _item(x.e));
    }

    function activate(item) {
        if (!item || !item.text)
            return;
        PickerStore.push("glyph", item.key);
        Launch.pasteText(item.text);
    }

    FileView {
        id: db
        path: ""
        printErrors: false
        onLoaded: root._parse(text())
        onLoadFailed: {
            // No glyph.db (HyDE not installed): empty list, no error.
            root._all = [];
            root._byId = {};
            root._loading = false;
        }
    }
}
