pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config
import qs.shared.services

// Waiting updates (config/UpdatesConfig.qml), from HyDE's system.update.py: `status` counts them
// per package manager, `up` opens a terminal that lists them and asks before updating (checked again
// when it closes).
//
// Also hyde-lite itself (the Settings screen's "hyde-lite" row): `hyde-lite update --check` says whether the
// checkout has something new, and the button opens a terminal that runs `hyde-lite update --restart`, which asks for
// the sudo password there (the installer's package step needs it; the polkit agent only answers polkit).
Singleton {
    id: root

    readonly property string home: Paths.home
    readonly property string script: `${home}/.local/lib/hyde/system.update.py`
    // [{ name, count }] per package manager; total in `count`.
    property var managers: []
    readonly property int count: managers.reduce((n, m) => n + m.count, 0)
    readonly property bool checking: check.running
    // The terminal with the update is open.
    readonly property bool updating: update.running

    // "pacman 110 · yay 4 · flatpak 3"
    readonly property string summary: managers.filter(m => m.count > 0).map(m => `${m.name} ${m.count}`).join(" · ")

    function refresh() {
        if (!check.running)
            check.running = true;
    }

    function open() {
        if (!update.running)
            update.running = true;
    }

    // hyde-lite: "unknown" until the first check, then "current", "available", "unfinished" (the checkout is current
    // but the last install did not finish) or "failed".
    property string hydeLiteState: "unknown"
    // One short line for the Settings row.
    property string hydeLiteSummary: "Not checked yet"
    readonly property bool hydeLiteChecking: hydeLiteCheck.running
    readonly property string hydeLiteCommand: `${home}/.local/bin/hyde-lite`

    // `out` is what `hyde-lite update --check` printed (both streams) followed by a line "::<exit code>".
    function parseHydeLite(out) {
        const lines = String(out).split("\n").map(l => l.trim()).filter(l => l !== "");
        const last = lines.length > 0 ? lines[lines.length - 1] : "";
        const code = /^::\d+$/.test(last) ? parseInt(last.slice(2)) : -1;
        const body = /^::\d+$/.test(last) ? lines.slice(0, -1) : lines;
        if (code !== 0)
            return {
                state: "failed",
                summary: (body.length > 0 ? body[body.length - 1] : "hyde-lite update --check failed").replace(/^hyde-lite: /, "")
            };
        const news = body.find(l => /^\d+ new commit\(s\)/.test(l));
        if (news) {
            const n = parseInt(news);
            return {
                state: "available",
                summary: n === 1 ? "1 new commit" : `${n} new commits`
            };
        }
        if (body.some(l => l.indexOf("last install did not finish") >= 0))
            return {
                state: "unfinished",
                summary: "The last install did not finish"
            };
        const current = body.find(l => l.indexOf("up to date") >= 0);
        if (current)
            return {
                state: "current",
                summary: current.replace(/^hyde-lite is up to date/, "Up to date")
            };
        return {
            state: "unknown",
            summary: body.length > 0 ? body[body.length - 1] : "No answer"
        };
    }

    function refreshHydeLite() {
        if (!hydeLiteCheck.running)
            hydeLiteCheck.running = true;
    }

    // In a terminal of its own, in its own unit like everything Launch.run starts (the update ends by restarting the
    // shell, which would take a terminal in the shell's cgroup with it); without hyde-shell, as is.
    function updateHydeLite() {
        Quickshell.execDetached(["sh", "-c", 'if command -v hyde-shell >/dev/null; then exec hyde-shell app -- "$@"; else exec "$@"; fi', "sh", "xdg-terminal-exec", "bash", "-c", '"$1" update --restart; echo; read -r -p "Press Enter to close " _', "bash", hydeLiteCommand]);
    }

    Timer {
        interval: UpdatesConfig.firstCheckSeconds * 1000
        running: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: UpdatesConfig.checkMinutes * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    // `status` also writes $XDG_RUNTIME_DIR/hyde/update_info.json, which the numbers come from.
    Process {
        id: check
        command: ["sh", "-c", 'test -f "$1" && python3 "$1" status >/dev/null && cat "${XDG_RUNTIME_DIR:-/tmp}/hyde/update_info.json"', "sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.managers = JSON.parse(text).managers ?? [];
                } catch (e) {
                    root.managers = [];
                }
            }
        }
    }

    Process {
        id: update
        command: ["python3", root.script, "up"]
        onExited: root.refresh()
    }

    Process {
        id: hydeLiteCheck
        command: ["sh", "-c", '[ -x "$1" ] || { echo "hyde-lite: the hyde-lite command is not installed (run ./install.sh)"; echo "::127"; exit 0; }; timeout 30 "$1" update --check 2>&1; echo "::$?"', "sh", root.hydeLiteCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parseHydeLite(text);
                root.hydeLiteState = r.state;
                root.hydeLiteSummary = r.summary;
            }
        }
    }
}
