pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.core

// Wi-Fi and Bluetooth requests (config/AgentsConfig.qml). scripts/agents.py is NetworkManager's
// secret agent and BlueZ's pairing agent; each request it prints opens the island's "agent" mode
// (components/AgentView.qml) and the answer goes back on its stdin. Requests queue up; leaving the
// surface (Esc, click outside) refuses the one on show. See the script for the request types.
Singleton {
    id: root

    // Requests waiting, oldest first: { type, id, name, retry, enterprise, code, entered, service }.
    property var queue: []
    readonly property var request: queue.length > 0 ? queue[0] : null
    // Last problem registering the agents ("" = fine).
    property string error: ""

    // Answers the request on show: ok with the secret (password, PIN, passkey) or refused.
    function answer(ok, secret) {
        const r = request;
        if (!r)
            return;
        if (r.type !== "display")
            proc.write(JSON.stringify({
                id: r.id,
                ok: ok,
                secret: secret ?? ""
            }) + "\n");
        _drop(r.id);
    }

    function cancel() {
        answer(false, "");
    }

    function _drop(id) {
        queue = queue.filter(r => r.id !== id);
        if (queue.length > 0)
            _show();
        else
            _closeSurface();
    }

    function _receive(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.type === "ready") {
            error = "";
        } else if (m.type === "error") {
            error = m.text;
            console.warn(`agents: ${m.text}`);
        } else if (m.type === "cancel") {
            _drop(m.id);
        } else if (queue.some(r => r.id === m.id)) {
            // The same request again (a passkey being typed on the device): update it.
            queue = queue.map(r => r.id === m.id ? m : r);
        } else {
            queue = queue.concat([m]);
            _show();
        }
    }

    property bool _closingSelf: false

    function _show() {
        // Not over the lock screen, and not over a polkit prompt (shown when that one closes).
        if (!request || Lock.locked || IslandController.mode === IslandState.auth)
            return;
        if (IslandController.mode !== IslandState.agent)
            IslandController.open(IslandState.agent);
    }

    function _closeSurface() {
        if (IslandController.mode !== IslandState.agent)
            return;
        _closingSelf = true;
        IslandController.close();
        _closingSelf = false;
    }

    // Leaving the surface without answering (Esc, click outside, another surface) refuses the request;
    // a polkit prompt only puts it on hold. When the island goes back to rest, a waiting one shows.
    property string _lastMode: ""
    Connections {
        target: IslandController
        function onModeChanged() {
            const m = IslandController.mode;
            const was = root._lastMode;
            root._lastMode = m;
            if (m === IslandState.agent) {
                if (!root.request)
                    Qt.callLater(root._closeSurface);
            } else if (was === IslandState.agent) {
                if (!root._closingSelf && root.request && m !== IslandState.auth)
                    root.cancel();
            } else if (m === "" && root.request) {
                Qt.callLater(root._show);
            }
        }
    }

    Connections {
        target: Lock
        function onLockedChanged() {
            if (!Lock.locked)
                root._show();
        }
    }

    Process {
        id: proc
        command: ["python3", Quickshell.shellPath("scripts/agents.py")]
        running: AgentsConfig.enabled
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root._receive(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn(`agents: ${line}`)
        }
        onExited: {
            // The requests on show can no longer be answered.
            root.queue = [];
            root._closeSurface();
            if (AgentsConfig.enabled)
                restart.start();
        }
    }

    Timer {
        id: restart
        interval: 3000
        onTriggered: proc.running = true
    }
}
