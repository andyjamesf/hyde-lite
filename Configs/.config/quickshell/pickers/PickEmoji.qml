pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Emoji picker for the launcher (port of HyDE's emoji-picker.sh).
// Data: ${HYDE_DATA_HOME:-~/.local/share/hyde}/emoji.db, one emoji per line as
// "<emoji> <name and keywords separated by spaces>" (HyDE does not separate the name from the
// keywords, so the title is the whole description).
// The file is only read and parsed on the first opening; afterwards it stays in memory.
// Recents (Config.pickers.recents.emoji) are kept by PickerStore under the key "emoji".
//
// NOTE: activate() copies the emoji and pastes it into the focused window with Ctrl+V
// (Launch.pasteText) ON PURPOSE — it is exactly what HyDE does (paste_string in globalcontrol.sh)
// and the whole point of this picker, not a testing shortcut.
Singleton {
    id: root

    readonly property string name: "emoji"
    readonly property string title: "Emoji"
    readonly property string placeholder: "Search emoji…"
    readonly property string glyph: ""
    readonly property bool loading: _loading
    readonly property bool grid: true
    readonly property bool keepOpen: false

    readonly property int maxResults: Config.pickers.maxResults.emoji ?? 300
    readonly property string dataHome: Quickshell.env("HYDE_DATA_HOME") || `${Paths.dataHome}/hyde`

    property bool _loading: false
    property bool _requested: false
    // [{ ch, desc, low, code }] in file order (already grouped by category).
    property var _all: []
    property var _byChar: ({})

    function refresh() {
        if (_requested)
            return;
        _requested = true;
        _loading = true;
        db.path = `${dataHome}/emoji.db`;
    }

    function _parse(text) {
        const list = [];
        const map = {};
        for (const line of String(text).split("\n")) {
            const sp = line.indexOf(" ");
            if (sp <= 0)
                continue;
            const ch = line.slice(0, sp);
            const desc = line.slice(sp + 1).trim();
            if (map[ch])
                continue;
            const e = {
                ch,
                desc,
                // Padded with spaces, so whole words can be tested with a plain indexOf.
                low: ` ${desc.toLowerCase()} `,
                code: _codepoints(ch)
            };
            map[ch] = e;
            list.push(e);
        }
        _byChar = map;
        _all = list;
        _loading = false;
    }

    // "U+2764 U+FE0F": walks code points (the JS engine iterates UTF-16 units).
    function _codepoints(s) {
        const out = [];
        for (let i = 0; i < s.length; i++) {
            const c = s.codePointAt(i);
            out.push("U+" + c.toString(16).toUpperCase());
            if (c > 0xffff)
                i++;
        }
        return out.join(" ");
    }

    function _item(e) {
        return {
            key: e.ch,
            title: e.desc,
            subtitle: e.code,
            icon: "",
            text: e.ch,
            badge: ""
        };
    }

    // Score of one term in a description: whole word > word start > substring.
    // `t` = { term, word }; `low` is padded with spaces, so a whole word is " term "
    // (no regular expressions: this runs over thousands of entries per keystroke).
    function _termScore(t, low) {
        const idx = low.indexOf(t.term);
        if (idx < 0)
            return 0;
        const w = low.indexOf(t.word);
        if (w >= 0)
            return 100 - Math.min(30, w / 2);
        if (low[idx - 1] === " ")
            return 80 - Math.min(30, idx / 2);
        return 50 - Math.min(20, idx / 2);
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        if (q === "") {
            // No search: recents first, then the rest in file order.
            const recent = (PickerStore.emoji ?? []).filter(ch => _byChar[ch]).map(ch => _byChar[ch]);
            const seen = {};
            for (const e of recent)
                seen[e.ch] = true;
            return recent.concat(_all.filter(e => !seen[e.ch]).slice(0, maxResults)).slice(0, maxResults).map(_item);
        }
        const terms = q.split(/\s+/).map(term => ({
                    term,
                    word: ` ${term} `
                }));
        const recent = PickerStore.emoji ?? [];
        const scored = [];
        // Local copies: calling a QML method or reading an object property for each of thousands
        // of entries is several times slower than a local JS function.
        const all = _all;
        const score = _termScore;
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
                // Small bonus for recents and for short descriptions ("purer" names).
                const r = recent.indexOf(e.ch);
                scored.push({
                    e,
                    s: s + (r >= 0 ? 20 - r / 2 : 0) - Math.min(10, e.low.length / 10)
                });
            }
        }
        return scored.sort((a, b) => b.s - a.s).slice(0, maxResults).map(x => _item(x.e));
    }

    function activate(item) {
        if (!item || !item.text)
            return;
        PickerStore.push("emoji", item.text);
        Launch.pasteText(item.text);
    }

    FileView {
        id: db
        path: ""
        printErrors: false
        onLoaded: root._parse(text())
        onLoadFailed: {
            // No emoji.db (HyDE not installed): empty list, no error.
            root._all = [];
            root._byChar = {};
            root._loading = false;
        }
    }
}
