pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config as Config

// Installed applications (.desktop files) for the island launcher: fuzzy search, favourites and
// "frecency" (the most used and most recent rise in the list). Favourites and usage history are
// kept in ${XDG_STATE_HOME:-~/.local/state}/morphing-island/launcher.json.
// Launching goes through Launch.desktop (each app in its own systemd unit, like HyDE's rofi).
// Tunables (result cap, frecency half-life, ranking weights) are in config/Launcher.qml.
Singleton {
    id: root

    readonly property var applications: DesktopEntries.applications.values.filter(e => !e.noDisplay).sort((a, b) => a.name.localeCompare(b.name))
    readonly property var favorites: store.favorites

    function keyOf(entry) {
        return entry?.id ?? "";
    }

    function iconOf(entry) {
        return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    function isFavorite(entry) {
        return !!entry && store.favorites.includes(entry.id);
    }

    function toggleFavorite(entry) {
        if (!entry)
            return;
        store.favorites = isFavorite(entry) ? store.favorites.filter(id => id !== entry.id) : store.favorites.concat([entry.id]);
        file.writeAdapter();
    }

    function launch(entry) {
        if (!entry)
            return;
        // Copy the object before changing it: the JsonAdapter only notices when the property is reassigned.
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
        Launch.desktop(entry.id, entry);
    }

    // Frecency: number of launches, each weighing less as it ages (halves every
    // Launcher.frecencyHalfLifeDays days).
    function frecency(entry) {
        const u = store.uses[entry.id];
        if (!u)
            return 0;
        const days = (Date.now() - u.last) / 86400000;
        return u.count * Math.pow(0.5, days / Math.max(0.1, Config.Launcher.frecencyHalfLifeDays));
    }

    // Fuzzy score of `q` in `text` (kept here for callers; the implementation is services/Fuzzy.qml).
    function fuzzy(q, text) {
        return Fuzzy.score(q, text);
    }

    function search(query) {
        const L = Config.Launcher;
        const max = L.appsMaxResults;
        const q = String(query ?? "").trim().toLowerCase();
        if (q === "") {
            // No search: favourites, then the most used, then the rest alphabetically.
            const fav = applications.filter(e => isFavorite(e));
            const used = applications.filter(e => !isFavorite(e) && frecency(e) > 0).sort((a, b) => frecency(b) - frecency(a));
            const rest = applications.filter(e => !isFavorite(e) && frecency(e) === 0);
            return fav.concat(used, rest).slice(0, max);
        }
        const w = L.fuzzyWeights;
        const score = Fuzzy.score;
        const scored = [];
        for (const e of applications) {
            const s = Math.max(score(q, e.name) * (w.name ?? 1), score(q, e.genericName) * (w.genericName ?? 0), score(q, (e.keywords ?? []).join(" ")) * (w.keywords ?? 0), score(q, e.id) * (w.id ?? 0), score(q, e.comment) * (w.comment ?? 0));
            if (s > 0)
                scored.push({
                    e,
                    s: s + Math.min(L.frecencyBonusMax, frecency(e) * L.frecencyBonusScale) + (isFavorite(e) ? L.favoriteBonus : 0)
                });
        }
        // Ties: alphabetical, so the list does not jump between identical searches.
        return scored.sort((a, b) => b.s - a.s || a.e.name.localeCompare(b.e.name)).slice(0, max).map(x => x.e);
    }

    FileView {
        id: file
        path: `${Paths.islandState}/launcher.json`
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
