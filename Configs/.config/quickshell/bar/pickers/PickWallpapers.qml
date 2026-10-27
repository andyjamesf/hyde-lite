pragma Singleton
import QtQuick
import Quickshell
import qs.bar.services
import qs.shared.services

// Wallpaper picker: the current theme's wallpapers (plus the extra folders in
// "pickers.wallpapers.dirs"), as a grid of thumbnails. Choosing one applies it globally through HyDE
// (`hyde-shell wallpaper --global -s`), which also regenerates the wallbash colours. The list and the
// thumbnails come from Wallpapers.
Singleton {
    id: root

    readonly property string name: "wallpapers"
    readonly property string title: "Wallpapers"
    readonly property string placeholder: "Search wallpapers…"
    readonly property string glyph: "wallpaper"
    readonly property bool loading: Wallpapers.loading && Wallpapers.list.length === 0
    readonly property bool grid: true
    // Wide tiles (16:10) instead of the square ones used for emoji and glyphs.
    readonly property size tile: Qt.size(144, 90)
    readonly property bool keepOpen: false
    readonly property string emptyText: "No wallpapers in this theme"
    // Lets the "Random" tile render its glyph as a Material icon instead of plain text (every other
    // tile has a thumbnail, so this only ever applies to that one).
    readonly property string textFont: Config.appearance.iconFont

    // Sentinel key for the synthetic tile; never a real wallpaper path.
    readonly property string _randomKey: "__random__"

    function refresh() {
        Wallpapers.refresh();
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const cur = Wallpapers.current;
        const list = q === "" ? Wallpapers.list : Wallpapers.list.filter(w => w.name.toLowerCase().includes(q));
        const rows = list.map(w => ({
                    "key": w.path,
                    "title": w.name,
                    "subtitle": w.path.replace(Paths.home, "~"),
                    "icon": w.thumb,
                    "text": "",
                    "glyph": "",
                    "badge": w.path === cur ? "Current" : ""
                }));
        // Always first, unaffected by the search: picks one at random from the full list below.
        if (Wallpapers.list.length === 0)
            return rows;
        return [{
                "key": _randomKey,
                "title": "Random",
                "subtitle": "Pick a random wallpaper",
                "icon": "",
                "text": "",
                "glyph": "shuffle",
                "badge": ""
            }].concat(rows);
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        if (item.key === _randomKey) {
            const list = Wallpapers.list;
            if (list.length === 0)
                return;
            const others = list.filter(w => w.path !== Wallpapers.current);
            const pool = others.length > 0 ? others : list;
            Wallpapers.set(pool[Math.floor(Math.random() * pool.length)].path);
            return;
        }
        Wallpapers.set(item.key);
    }
}
