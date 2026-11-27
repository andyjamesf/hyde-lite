pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Runs one isolated qalc calculation at a time. Expressions are passed as an argv item after --.
Singleton {
    id: root

    property bool installed: false
    property bool busy: false
    property int _serial: 0
    property int _activeSerial: 0
    property string _expression: ""
    property bool _superseding: false
    property bool _timedOut: false
    signal answered(string expr, bool ok, string text)

    function prepare(expr) {
        const text = String(expr ?? "").trim();
        const forbidden = "command|save|store|set|mode|exrates|load|export|plot|quit|exit|clear|delete|history|help|info|keep|assume|base|exact|approximate|expand|find|list|function|variable|rpn|stack|copy|move|pop|rotate|swap";
        if (text === "" || /^\//.test(text) || /(?:^|[^a-z_])(command|save|store|set|mode|exrates|load|export|plot|quit|exit|clear|delete|history|help|info|keep|assume|base|exact|approximate|expand|factor|find|list|function|variable|rpn|stack|copy|move|pop|rotate|swap)(?:$|\s)/i.test(text)
                || new RegExp(`(?:^|[^a-z_])(?:${forbidden})(?:\\s*\\(|\\s+|$)`, "i").test(text))
            return "";
        // A decimal comma is accepted only when it separates digits; semicolon remains qalc's argument separator.
        return text.replace(/(\d),(\d)/g, "$1.$2");
    }

    function argsFor(expr, angle) {
        const clean = prepare(expr);
        if (clean === "")
            return [];
        return ["qalc", "-defaults", "-t", "-m", "3000", "-s", `angle unit ${angle === "rad" ? "radians" : "degrees"}`, "--", clean];
    }

    function parse(code, stdout, stderr) {
        const text = String(stdout ?? "").trim();
        const err = String(stderr ?? "").trim();
        const diagnostic = text.replace(/\u001b\[[0-9;]*m/g, "");
        if (code !== 0 || text === "" || err !== "" || /\b(error|warning|unknown function|unknown variable|not found)\b/i.test(diagnostic))
            return { ok: false, text: err || text || "Calculation failed" };
        return { ok: true, text };
    }

    function evaluate(expr, angle) {
        const clean = prepare(expr);
        if (clean === "") {
            answered(expr, false, "Unsupported or unsafe expression");
            return;
        }
        const serial = ++_serial;
        _expression = String(expr);
        busy = true;
        _pending = serial;
        _pendingArgs = argsFor(clean, angle);
        if (runner.running) {
            _superseding = true;
            runner.running = false;
        } else {
            startPending();
        }
    }

    property int _pending: 0
    property var _pendingArgs: []
    property string _out: ""
    property string _err: ""
    function startPending() {
        _activeSerial = _pending;
        _out = "";
        _err = "";
        runner.command = _pendingArgs;
        runner.running = true;
        timeout.restart();
    }
    Process {
        id: runner
        stdout: StdioCollector { onStreamFinished: root._out = text }
        stderr: StdioCollector { onStreamFinished: root._err = text }
        onExited: code => {
            timeout.stop();
            if (root._superseding) {
                root._superseding = false;
                root.startPending();
                return;
            }
            if (root._timedOut) {
                root._timedOut = false;
                return;
            }
            if (root._activeSerial !== root._serial)
                return;
            const result = root.parse(code, root._out, root._err);
            root.busy = false;
            if (root._pending === root._serial)
                root.answered(root._expression, result.ok, result.text);
        }
    }
    Timer {
        id: timeout
        interval: 3000
        onTriggered: {
            root._timedOut = true;
            runner.running = false;
            root.busy = false;
            if (root._activeSerial === root._serial)
                root.answered(root._expression, false, "Calculation took too long");
        }
    }
    Process {
        command: ["sh", "-c", "command -v qalc >/dev/null"]
        running: true
        onExited: code => root.installed = code === 0
    }
}
