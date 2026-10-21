pragma Singleton
import QtQuick
import Quickshell

// Wallpaper picker: the current theme's wallpapers (plus the extra folders in
// "pickers.wallpapers.dirs"), as a grid of thumbnails. Choosing one applies it globally through HyDE
// (`hyde-shell wallpaper --global -s`), which also regenerates the wallbash colours. The list and the
// thumbnails come from WallpaperStore.
Singleton {
    id: root

    readonly property string name: "wallpapers"
    readonly property string title: "Wallpapers"
    readonly property string placeholder: "Search wallpapers…"
    readonly property string glyph: "wallpaper"
    readonly property bool loading: WallpaperStore.loading && WallpaperStore.list.length === 0
    readonly property bool grid: true
    // Wide tiles (16:10) instead of the square ones used for emoji and glyphs.
    readonly property size tile: Qt.size(144, 90)
    readonly property bool keepOpen: false
    readonly property string emptyText: "No wallpapers in this theme"

    function refresh() {
        WallpaperStore.refresh();
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const cur = WallpaperStore.current;
        const list = q === "" ? WallpaperStore.list : WallpaperStore.list.filter(w => w.name.toLowerCase().includes(q));
        return list.map(w => ({
                    "key": w.path,
                    "title": w.name,
                    "subtitle": w.path.replace(Paths.home, "~"),
                    "icon": w.thumb,
                    "text": "",
                    "glyph": "",
                    "badge": w.path === cur ? "Current" : ""
                }));
    }

    function activate(item) {
        if (item && item.key)
            WallpaperStore.set(item.key);
    }
}
