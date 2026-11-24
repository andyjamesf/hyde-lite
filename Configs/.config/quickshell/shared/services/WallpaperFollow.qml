pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the colours on the wallpaper that is on the screen. Every colour of the shells, kitty, GTK...
// comes from the palette of ~/.cache/hyde/wall.set (the link `hyde-shell wallpaper` replaces; its hooks
// then run matugen). When a wallpaper is changed some other way (awww called by hand, a change that
// failed half-way, a shell restarted in the middle of one) the screen shows one picture and the palette
// belongs to another. This notices that and runs HyDE's own command for the picture on the screen, so
// the whole chain (palette, thumbnails, templates) runs as it does for any change.
//
// No polling: it listens for the link being replaced (gio monitor on ~/.cache/hyde) and looks once,
// a few seconds after the last event, when the change has settled (a normal change updates the link
// first and awww a moment later). It also looks once when the shell starts.
Singleton {
    id: root

    readonly property string link: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/hyde/wall.set`
    property real lastFix: 0
    readonly property string dir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/hyde`

    // One check after the last change of the link (and once at startup).
    Timer {
        id: settle
        interval: 4000
        running: true
        onTriggered: if (!probe.running)
            probe.running = true
    }

    // Events of the cache folder; only the ones about wall.set count (the link is replaced by renaming
    // a temporary one onto it).
    Process {
        command: ["gio", "monitor", "-d", root.dir]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("/wall.set"))
                    settle.restart();
            }
        }
    }

    Process {
        id: probe
        // Line 1: the target of the link; the rest: what awww shows on each output.
        command: ["sh", "-c", `readlink -f -- "$1"; awww query 2>/dev/null | sed -n 's/.*image: //p'`, "sh", root.link]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l !== "");
                const linked = lines[0] ?? "";
                const shown = lines.slice(1);
                // At most once a minute: if the fix itself does not take, it must not repeat forever.
                if (linked !== "" && shown.length > 0 && !shown.includes(linked) && Date.now() - root.lastFix > 60000) {
                    root.lastFix = Date.now();
                    Quickshell.execDetached(["hyde-shell", "wallpaper", "--global", "-s", shown[0]]);
                }
            }
        }
    }
}
