pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Background receiver for our localsend-cli fork (hyde-lite-publico's own
// third-party/localsend-cli, not part of this deployed tree — see its
// README for what the `receive` subcommand does and why it exists).
//
// A request from a device already paired in the interactive CLI (`P` on its
// first request) is auto-accepted; everyone else is declined unless
// `quickSave` is on. `quickSave` has no settings UI yet: change the default
// below for now, on both this and the island's copy if they ever diverge.
//
// Sending is not wired into either shell yet: for now, send a file with
// `localsend-cli send --to <alias-or-ip> <file>` from a terminal (already
// scriptable, see the fork's README). This service only covers receiving
// and the toast/history around it.
Singleton {
    id: root

    property bool quickSave: false

    readonly property string bin: `${Quickshell.env("HOME")}/.local/bin/localsend-cli`

    property bool ready: false
    property bool installError: false
    property string alias: ""
    property int port: 0

    // Most recent first, capped at `historyLimit`.
    property var history: []
    readonly property int historyLimit: 20

    function restart() {
        installError = false;
        ready = false;
        proc.running = false;
        proc.running = true;
    }

    function _pushHistory(entry) {
        history = [entry].concat(history).slice(0, historyLimit);
    }

    function _formatBytes(n) {
        if (n < 1024)
            return `${n} B`;
        const units = ["KB", "MB", "GB", "TB"];
        let value = n / 1024;
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            i++;
        }
        return `${value.toFixed(value < 10 ? 1 : 0)} ${units[i]}`;
    }

    function _notify(summary, body) {
        // Reuses whatever already answers org.freedesktop.Notifications on this
        // machine (this shell's own server, see shared/services/Notifications.qml) —
        // no separate toast plumbing needed.
        Quickshell.execDetached(["notify-send", "--app-name=LocalSend", "--icon=folder-download", summary, body]);
    }

    function _handle(line) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            console.warn("LocalSend: not a JSON line:", line);
            return;
        }
        switch (event.event) {
        case "ready":
            root.ready = true;
            root.installError = false;
            root.alias = event.alias ?? "";
            root.port = event.port ?? 0;
            break;
        case "incoming":
            if (!event.accepted) {
                root._pushHistory({
                    kind: "declined",
                    alias: event.alias ?? "",
                    fileCount: event.file_count ?? 0,
                    bytes: event.total_bytes ?? 0,
                    time: Date.now()
                });
                root._notify("LocalSend", `${event.alias}: declined (not paired)`);
            }
            break;
        case "session_done":
            root._pushHistory({
                kind: event.files_failed > 0 ? "partial" : "received",
                alias: event.alias ?? "",
                fileCount: event.files_ok ?? 0,
                failedCount: event.files_failed ?? 0,
                bytes: event.bytes ?? 0,
                cancelled: !!event.cancelled,
                time: Date.now()
            });
            if (event.cancelled)
                root._notify("LocalSend", `${event.alias}: cancelled`);
            else
                root._notify("LocalSend", `${event.alias} sent ${event.files_ok} file${event.files_ok === 1 ? "" : "s"} (${root._formatBytes(event.bytes)})`);
            break;
        case "server_stopped":
            root.ready = false;
            root._notify("LocalSend", `Stopped receiving${event.error ? ": " + event.error : ""}`);
            break;
        }
    }

    Process {
        id: proc

        // A missing binary never reaches `started` at all (QProcess reports
        // `failedToStart` instead), so this is how a real crash is told apart
        // from "not installed" — an exit code alone misses that case.
        property bool _started: false

        command: root.quickSave ? [root.bin, "receive", "--quick-save"] : [root.bin, "receive"]
        running: true
        stdout: SplitParser {
            onRead: line => root._handle(line)
        }
        onStarted: _started = true
        onExited: {
            root.ready = false;
            root.installError = !_started;
            _started = false;
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: if (!proc.running)
            proc.running = true
    }
}
