pragma Singleton
import QtQuick
import Quickshell

// XDG base directories (https://specifications.freedesktop.org/basedir-spec/), with the standard
// fallbacks when the variables are unset. Paths never end with a slash. Use these instead of reading
// the environment in each file.
Singleton {
    // $HOME.
    readonly property string home: Quickshell.env("HOME") || ""
    // $XDG_CONFIG_HOME, default ~/.config.
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`
    // $XDG_STATE_HOME, default ~/.local/state (Quickshell keeps this shell's files in its own state folder).
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    // $XDG_CACHE_HOME, default ~/.cache.
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`
    // $XDG_DATA_HOME, default ~/.local/share.
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
    // $XDG_RUNTIME_DIR, default /tmp (only used for sockets/temporary files).
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // $XDG_PICTURES_DIR, default ~/Pictures.
    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    // This shell's own state directory (pickers.json…): Quickshell's per-shell state folder.
    readonly property string shellState: Quickshell.statePath("").replace(/\/$/, "")

    // Expands a leading "~" to $HOME ("~/.face" → "/home/me/.face"); other paths are returned as is.
    function expand(path) {
        const p = String(path ?? "");
        return p === "~" || p.startsWith("~/") ? home + p.slice(1) : p;
    }
}
