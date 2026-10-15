pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Web search (HyDE's rofi.websearch.sh): one row per search engine for the typed text, the default
// engine first. Engines come from HyDE's own lists (~/.local/share/hyde/websearch.lst and
// ~/.config/hyde/websearch.lst, "icon | name | url with %s"; the second overrides the first). As in
// HyDE, "name:text" (e.g. "wiki:lisbon" or "github:quickshell") puts that engine first. Opens with
// $BROWSER when set, otherwise with `xdg-open` (through Launch.run).
Singleton {
    id: root

    readonly property string name: "web"
    readonly property string title: "Web search"
    readonly property string placeholder: "Search the web…"
    readonly property string glyph: "globe"
    readonly property bool loading: false
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property string dataHome: Paths.dataHome
    readonly property string configHome: Paths.configHome

    // Engines listed first and display names: config/Config.pickers.qml (webPreferred, webLabels).
    readonly property var preferred: Config.pickers.webPreferred
    readonly property var labels: Config.pickers.webLabels
    // Used when there is no HyDE list at all.
    readonly property string fallbackList: " | google | https://www.google.com/search?q=%s\n | duckduckgo | https://duckduckgo.com/?q=%s\n | youtube | https://www.youtube.com/results?search_query=%s\n | github | https://www.github.com/search?q=%s\n | wikipedia | https://en.wikipedia.org/w/index.php?search=%s"

    // [{ key, label, url, icon }], already in display order.
    readonly property var engines: {
        const map = {};
        const order = [];
        const texts = [shareFile.loaded ? shareFile.text() : "", userFile.loaded ? userFile.text() : ""];
        if (texts.every(t => t.trim() === ""))
            texts[0] = fallbackList;
        for (const t of texts) {
            for (const line of t.split("\n")) {
                const parts = line.split("|").map(s => s.trim());
                if (parts.length < 3 || parts[1] === "" || !parts[2].includes("%s"))
                    continue;
                const key = parts[1];
                if (map[key] === undefined)
                    order.push(key);
                map[key] = {
                    "key": key,
                    "label": labels[key] ?? key.charAt(0).toUpperCase() + key.slice(1),
                    "url": parts.slice(2).join("|"),
                    "icon": parts[0]
                };
            }
        }
        const first = preferred.filter(k => map[k] !== undefined);
        return first.concat(order.filter(k => !first.includes(k))).map(k => map[k]);
    }

    function refresh() {
        shareFile.reload();
        userFile.reload();
    }

    function host(url) {
        const m = String(url).match(/^[a-z]+:\/\/([^/?#]+)/i);
        return m ? m[1].replace(/^www\./, "") : url;
    }

    // "name:text" → { engine, text } (exact name or part of it, like HyDE's smart_input).
    function split(query) {
        const m = String(query).match(/^\s*([\w.\-]+):\s*(.*)$/);
        if (!m)
            return null;
        const want = m[1].toLowerCase();
        const e = engines.find(x => x.key.toLowerCase() === want) ?? engines.find(x => x.key.toLowerCase().includes(want) || x.label.toLowerCase().includes(want));
        return e ? {
            "engine": e,
            "text": m[2]
        } : null;
    }

    function items(query) {
        const raw = String(query ?? "");
        const smart = split(raw);
        const text = (smart ? smart.text : raw).trim();
        let list = engines;
        if (smart)
            list = [smart.engine].concat(engines.filter(e => e !== smart.engine));
        return list.map((e, i) => ({
                    "key": e.key,
                    "title": text !== "" ? `Search ${e.label} for “${text}”` : e.label,
                    "subtitle": text !== "" ? host(e.url) : `${host(e.url)} · type to search, or ${e.key}:query`,
                    "icon": "",
                    "text": e.icon,
                    "badge": i === 0 ? "default" : "",
                    "url": e.url,
                    "query": text
                }));
    }

    function activate(item) {
        if (!item?.url)
            return;
        // No text: opens the engine's home page.
        const url = item.query ? item.url.split("%s").join(encodeURIComponent(item.query)) : item.url.match(/^[a-z]+:\/\/[^/?#]+/i)?.[0] ?? "";
        if (!/^https?:\/\//i.test(url))
            return;
        const browser = Quickshell.env("BROWSER");
        Launch.run(browser ? [browser, url] : ["xdg-open", url]);
    }

    FileView {
        id: shareFile
        path: `${root.dataHome}/hyde/websearch.lst`
        printErrors: false
    }

    FileView {
        id: userFile
        path: `${root.configHome}/hyde/websearch.lst`
        printErrors: false
    }
}
