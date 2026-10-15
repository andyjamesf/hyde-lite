pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Installed applications (.desktop files): icons by app id, fuzzy search for the launcher,
// favorites and "frecency" (the most used and most recent rise in the list). The usage history and
// the favorites are stored in ~/.local/state/quickshell/…/launcher.json.
Singleton {
    id: root

    readonly property var applications: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var favorites: store.favorites

    function entryFor(appId) {
        return appId ? DesktopEntries.heuristicLookup(appId) : null;
    }

    function iconFor(appId) {
        const entry = entryFor(appId);
        return Quickshell.iconPath(entry?.icon || appId.toLowerCase(), "application-x-executable");
    }

    function iconOf(entry) {
        return Quickshell.iconPath(entry?.icon || "", "application-x-executable");
    }

    function nameFor(appId) {
        return entryFor(appId)?.name || appId;
    }

    function isFavorite(entry) {
        return store.favorites.includes(entry.id);
    }

    function toggleFavorite(entry) {
        store.favorites = isFavorite(entry) ? store.favorites.filter(id => id !== entry.id) : store.favorites.concat([entry.id]);
        file.writeAdapter();
    }

    // Launches through HyDE's app2unit (like HyDE's rofi): each app gets its own systemd unit.
    function launch(entry, actionId) {
        const uses = Object.assign({}, store.uses);
        const u = uses[entry.id] ?? {
            count: 0,
            last: 0
        };
        uses[entry.id] = {
            count: u.count + 1,
            last: Date.now()
        };
        store.uses = uses;
        file.writeAdapter();
        Quickshell.execDetached(["hyde-shell", "app", "--", actionId ? `${entry.id}.desktop:${actionId}` : `${entry.id}.desktop`]);
    }

    // Frecency: uses, with more weight for recent ones (one-week half-life).
    function frecency(entry) {
        const u = store.uses[entry.id];
        if (!u)
            return 0;
        const days = (Date.now() - u.last) / 86400000;
        return u.count * Math.pow(0.5, days / 7);
    }

    // Fuzzy score of `q` in `text`: prefix > word start > substring > subsequence.
    function fuzzy(q, text) {
        if (!text)
            return 0;
        const t = text.toLowerCase();
        if (t === q)
            return 120;
        if (t.startsWith(q))
            return 100 - Math.min(20, t.length - q.length);
        const word = t.search(new RegExp(`(^|[\\s\\-_.])${q.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`));
        if (word >= 0)
            return 85 - Math.min(15, word);
        const idx = t.indexOf(q);
        if (idx >= 0)
            return 70 - Math.min(20, idx);
        // Subsequence: all letters in order; loses points for every gap.
        let ti = 0, gaps = 0, last = -1;
        for (const ch of q) {
            const found = t.indexOf(ch, ti);
            if (found < 0)
                return 0;
            if (last >= 0 && found > last + 1)
                gaps++;
            last = found;
            ti = found + 1;
        }
        return Math.max(1, 50 - gaps * 8 - Math.min(10, t.length - q.length));
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "") {
            // No query: favorites, then the most used, then the rest in alphabetical order.
            const fav = applications.filter(e => isFavorite(e));
            const used = applications.filter(e => !isFavorite(e) && frecency(e) > 0).sort((a, b) => frecency(b) - frecency(a));
            const rest = applications.filter(e => !isFavorite(e) && frecency(e) === 0);
            return fav.concat(used, rest);
        }
        const scored = [];
        for (const e of applications) {
            const s = Math.max(fuzzy(q, e.name), fuzzy(q, e.genericName) * 0.75, fuzzy(q, (e.keywords ?? []).join(" ")) * 0.65, fuzzy(q, e.id) * 0.6, fuzzy(q, e.comment) * 0.4);
            if (s > 0)
                scored.push({
                    e,
                    s: s + Math.min(25, frecency(e) * 4) + (isFavorite(e) ? 10 : 0)
                });
        }
        return scored.sort((a, b) => b.s - a.s).map(x => x.e);
    }

    FileView {
        id: file
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: store
            property var uses: ({})
            property var favorites: []
        }
    }
}
