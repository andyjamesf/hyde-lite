pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Waiting updates (config/UpdatesConfig.qml), from HyDE's system.update.py: `status` counts them
// per package manager, `up` opens a terminal that lists them and asks before updating (checked again
// when it closes).
Singleton {
    id: root

    readonly property string script: `${Paths.home}/.local/lib/hyde/system.update.py`
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
}
