pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Background receiver for our localsend-cli fork (hyde-lite-publico's own
// third-party/localsend-cli, not part of this deployed tree — see its
// README for what the `receive` subcommand does and why it exists, and the
// exact shape of every event and decision below).
//
// A request from a device already paired (`P` in the interactive CLI, or
// `accept_and_pair` here) is auto-accepted; with quickSave on, so is
// everyone else. Otherwise a request waits in `pending` until `answer()` is
// called, or 60s pass and the fork declines it on its own (an `aborted` or
// `timeout` event then drops it from `pending` here too). `quickSave` has
// no settings UI yet: change the default below for now, on both this and
// the island's copy if they ever diverge.
Singleton {
    id: root

    property bool quickSave: false

    readonly property string bin: `${Quickshell.env("HOME")}/.local/bin/localsend-cli`

    property bool ready: false
    property bool installError: false
    property string alias: ""
    property int port: 0

    // Requests waiting for `answer()`, oldest first: { sessionId, alias,
    // verified, paired, fileCount, totalBytes, since }.
    property var pending: []

    // Confirmed devices from the fork's own discovery, replaced wholesale on
    // every update (not a diff): { alias, host, port, fingerprint, paired }.
    property var devices: []

    // Most recent first, capped at `historyLimit`.
    property var history: []
    readonly property int historyLimit: 20

    property bool sendBusy: false
    // "" when idle or the last send succeeded.
    property string lastSendError: ""

    // The device currently picked to send to (an alias from `devices`), kept
    // here rather than in the panel: referencing an outer `id: root` from
    // inside a `ListRow` delegate is not reliably resolved by qmllint across
    // the component boundary, unlike a qualified singleton property.
    property string selectedTarget: ""

    // A file chosen with `browseFile()`, waiting to be read into a path field
    // and cleared. Property, not a signal: opening the portal's own window
    // clears this shell's HyprlandFocusGrab (the bar popout and the control
    // centre both use one), which closes whatever panel called browseFile()
    // before the user has picked anything — same as SysInfo.chooseAvatar(),
    // whose callers close their own panel on purpose first. A signal would
    // have nothing left listening by the time it fires; a property survives
    // for the panel to read when it (or a fresh instance of it) reopens.
    property string pickedPath: ""

    function browseFile() {
        if (!filePicker.running)
            filePicker.running = true;
    }

    function restart() {
        installError = false;
        ready = false;
        proc.running = false;
        proc.running = true;
    }

    // decision: "accept" | "accept_and_pair" | "decline".
    function answer(sessionId, decision) {
        if (!proc.running)
            return;
        proc.write(JSON.stringify({
            session_id: sessionId,
            decision: decision
        }) + "\n");
        root.pending = root.pending.filter(r => r.sessionId !== sessionId);
    }

    // `paths`: local file paths (no "file://" prefix). `target`: a device's
    // alias or host, e.g. one of `devices`' entries.
    function sendFiles(target, paths) {
        if (root.sendBusy || !target || !paths || paths.length === 0)
            return;
        root.sendBusy = true;
        root.lastSendError = "";
        sendProc.command = [root.bin, "send", "--to", target].concat(paths);
        sendProc.running = true;
    }

    function _pushHistory(entry) {
        history = [entry].concat(history).slice(0, historyLimit);
    }

    // Public: the panel also uses this for a pending request's size.
    function formatBytes(n) {
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

    // Removes a pending request and returns it (or undefined if it was
    // already gone), so a caller can still use its alias/file count/bytes
    // after it drops out of `pending`.
    function _takePending(sessionId) {
        const found = root.pending.find(r => r.sessionId === sessionId);
        root.pending = root.pending.filter(r => r.sessionId !== sessionId);
        return found;
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
            if (event.decision === "pending") {
                root.pending = root.pending.concat([
                    {
                        sessionId: event.session_id,
                        alias: event.alias ?? "",
                        verified: !!event.verified,
                        paired: !!event.paired,
                        fileCount: event.file_count ?? 0,
                        totalBytes: event.total_bytes ?? 0,
                        since: Date.now()
                    }
                ]);
                root._notify("LocalSend", `${event.alias} wants to send ${event.file_count} file${event.file_count === 1 ? "" : "s"} — open LocalSend to decide`);
            } else if (event.decision === "declined") {
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
        case "aborted": {
            const request = root._takePending(event.session_id);
            if (request)
                root._pushHistory({
                    kind: "declined",
                    alias: request.alias,
                    fileCount: request.fileCount,
                    bytes: request.totalBytes,
                    time: Date.now()
                });
            break;
        }
        case "timeout": {
            const request = root._takePending(event.session_id);
            root._pushHistory({
                kind: "declined",
                alias: request?.alias ?? "",
                fileCount: request?.fileCount ?? 0,
                bytes: request?.totalBytes ?? 0,
                time: Date.now()
            });
            root._notify("LocalSend", `${request?.alias ?? "A request"} timed out and was declined`);
            break;
        }
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
                root._notify("LocalSend", `${event.alias} sent ${event.files_ok} file${event.files_ok === 1 ? "" : "s"} (${root.formatBytes(event.bytes)})`);
            break;
        case "devices":
            root.devices = (event.devices ?? []).map(d => ({
                        alias: d.alias ?? "",
                        host: d.host ?? "",
                        port: d.port ?? 0,
                        fingerprint: d.fingerprint ?? "",
                        paired: !!d.paired
                    }));
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
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root._handle(line)
        }
        onStarted: _started = true
        onExited: {
            root.ready = false;
            root.installError = !_started;
            _started = false;
            root.pending = [];
            root.devices = [];
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: if (!proc.running)
            proc.running = true
    }

    // One-shot `send`; `sendFiles()` sets its command before starting it.
    // Concurrent sends are not queued: `sendBusy` blocks a second one until
    // this finishes, which is enough for "drop one file, pick a device".
    Process {
        id: sendProc
        onExited: code => {
            root.sendBusy = false;
            if (code === 0) {
                root.lastSendError = "";
            } else {
                // Not reading stderr here: a StdioCollector's `text` is only
                // reliable inside its own `onStreamFinished`, and ordering
                // against this `onExited` is not something to rely on.
                root.lastSendError = `send exited with code ${code}`;
                root._notify("LocalSend", "Send failed");
            }
        }
    }

    // Same script and portal call as SysInfo.chooseAvatar(): no filter (any
    // file), starting in the home directory. Exits 1 on cancel, in which
    // case stdout is empty and nothing is emitted.
    Process {
        id: filePicker
        command: ["python3", Quickshell.shellPath("shared/scripts/pick_file.py"), "Choose a file to send", "", `${Quickshell.env("HOME")}`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "") {
                    root.pickedPath = path;
                    root._notify("LocalSend", `Ready to send: ${path.split("/").pop()}`);
                }
            }
        }
    }
}
