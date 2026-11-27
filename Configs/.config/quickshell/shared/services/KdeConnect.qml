pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Paired KDE Connect devices, updated from D-Bus signals by the shared helper.
Singleton {
    id: root
    property bool installed: false
    property var devices: []
    readonly property int reachableCount: devices.filter(d => d.reachable).length
    property string lastError: ""
    property string _actionStderr: ""
    property string pickSource: ""
    property string pickedPath: ""
    signal filePicked(string path)
    property var _actionQueue: []

    function _notify(message) {
        Quickshell.execDetached(["notify-send", "--app-name=KDE Connect", "KDE Connect", message]);
    }

    function _action(args) {
        lastError = "";
        _actionQueue = _actionQueue.concat([args]);
        _startNextAction();
    }
    function _startNextAction() {
        if (actionProc.running || _actionQueue.length === 0)
            return;
        _actionStderr = "";
        actionProc.command = _actionQueue[0];
        actionProc.running = true;
    }
    function ring(id) { _action(["kdeconnect-cli", "-d", String(id), "--ring"]); }
    function ping(id) { _action(["kdeconnect-cli", "-d", String(id), "--ping"]); }
    function sendClipboard(id) { _action(["kdeconnect-cli", "-d", String(id), "--send-clipboard"]); }
    function shareFile(id, path) { _action(["kdeconnect-cli", "-d", String(id), "--share", String(path)]); }
    function refresh() { _action(["kdeconnect-cli", "--refresh"]); }
    function openApp() { Quickshell.execDetached(["kdeconnect-app"]); }
    function browseFile(id, source) {
        if (filePicker.running)
            return;
        pickSource = source ?? "";
        pickedPath = "";
        _pickedDevice = String(id);
        filePicker.running = true;
    }
    function _handle(line) {
        try {
            const state = JSON.parse(line);
            installed = !!state.installed;
            devices = state.devices ?? [];
        } catch (e) { console.warn("KDE Connect: invalid helper output", line); }
    }

    Process {
        id: helper
        command: ["python3", "-I", Quickshell.shellPath("shared/scripts/kdeconnect_state.py")]
        running: true
        stdout: SplitParser { onRead: line => root._handle(line) }
        onExited: code => {
            if (code !== 0) {
                restartTimer.interval = Math.min(restartTimer.interval * 2, 30000);
                restartTimer.start();
            }
        }
    }
    Timer { id: restartTimer; interval: 1000; onTriggered: if (!helper.running) helper.running = true }
    Process {
        id: actionProc
        stderr: SplitParser { onRead: line => { if (line.trim() !== "") root._actionStderr = line.trim(); } }
        onExited: code => {
            if (code !== 0) {
                root.lastError = root._actionStderr || `Command failed (exit ${code})`;
                root._notify(root.lastError);
            }
            root._actionQueue = root._actionQueue.slice(1);
            root._startNextAction();
        }
    }
    Process {
        id: filePicker
        command: ["python3", Quickshell.shellPath("shared/scripts/pick_file.py"), "Choose a file to send", "", `${Quickshell.env("HOME")}`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "") {
                    root.pickedPath = path;
                    root.filePicked(path);
                    root.shareFile(root._pickedDevice, path);
                }
            }
        }
        onExited: {
            if (root.pickedPath === "")
                root.filePicked("");
        }
    }
    property string _pickedDevice: ""
}
