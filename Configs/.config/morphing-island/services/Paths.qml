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
    // $XDG_STATE_HOME, default ~/.local/state (the island keeps its files in <stateHome>/morphing-island).
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`
    // $XDG_CACHE_HOME, default ~/.cache.
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`
    // $XDG_DATA_HOME, default ~/.local/share.
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
    // $XDG_RUNTIME_DIR, default /tmp (only used for sockets/temporary files).
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // $XDG_PICTURES_DIR, default ~/Pictures.
    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`

    // The island's own state directory (prefs.json, launcher.json, pickers.json…).
    readonly property string islandState: `${stateHome}/morphing-island`
    // Things the user wrote, as opposed to state the shell keeps about itself: the notepad lives
    // here so a cleared state directory does not take the notes with it.
    readonly property string islandData: `${dataHome}/morphing-island`

    // Expands a leading "~" to $HOME ("~/.face" → "/home/me/.face"); other paths are returned as is.
    function expand(path) {
        const p = String(path ?? "");
        return p === "~" || p.startsWith("~/") ? home + p.slice(1) : p;
    }
}
