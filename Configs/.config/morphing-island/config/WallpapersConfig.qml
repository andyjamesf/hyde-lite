pragma Singleton
import QtQuick
import Quickshell

// Wallpaper picker (wallpapers are applied through HyDE: `hyde-shell wallpaper`). (Named
// WallpapersConfig because services/Wallpapers.qml is the service.)
Singleton {
    // Folders listed in the picker, in grid order; missing ones are ignored. Placeholders:
    // {hydeConfig} = ~/.config/hyde, {theme} = current HyDE theme (entries with it are skipped while
    // unknown), {pictures} = $XDG_PICTURES_DIR or ~/Pictures; "~/" is expanded.
    readonly property var dirs: ["{pictures}/Wallpapers", "{pictures}/Wallpapers/{theme}"]
    // File extensions shown (case-insensitive). Default ["jpg", "jpeg", "png", "gif", "webp"].
    readonly property var extensions: ["jpg", "jpeg", "png", "gif", "webp"]
    // Files at or below this size are skipped (broken placeholders). Bytes, default 4096.
    readonly property int minBytes: 4096
    // While the picker is open, the current wallpaper is re-read this often. Milliseconds,
    // default 2000.
    readonly property int pollMs: 2000
    // …and this often while a change is being applied. Milliseconds, default 400.
    readonly property int busyPollMs: 400
    // Give up waiting for HyDE to apply a wallpaper after this long. Milliseconds, default 45000.
    readonly property int busyTimeoutMs: 45000
}
