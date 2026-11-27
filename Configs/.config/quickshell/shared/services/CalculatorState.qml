pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared.services

// Frozen calculator state shared by the tab and saved across shell restarts.
Singleton {
    id: root
    readonly property string path: `${Paths.stateHome}/quickshell/calculator.json`
    property string mode: "keyboard"
    property string angle: "deg"
    property string input: ""
    property int cursor: 0
    property string focusedField: "expression"
    property string result: ""
    property var history: []
    property var functions: ["", "", ""]
    property var view: ({ xMin: -10, xMax: 10, yMin: -10, yMax: 10 })
    property bool loaded: false

    function defaults() {
        return { mode: "keyboard", angle: "deg", input: "", cursor: 0, focusedField: "expression", result: "", history: [], functions: ["", "", ""],
                 view: { xMin: -10, xMax: 10, yMin: -10, yMax: 10 } };
    }
    function restore(text) {
        const d = defaults();
        try {
            const s = JSON.parse(text);
            if (!s || typeof s !== "object" || !["keyboard", "scientific", "graph"].includes(s.mode) || !["deg", "rad"].includes(s.angle)
                    || typeof s.input !== "string" || !Number.isInteger(s.cursor) || typeof s.result !== "string"
                    || !Array.isArray(s.history) || !Array.isArray(s.functions) || s.functions.length !== 3)
                return d;
            const v = s.view;
            if (!v || ![v.xMin, v.xMax, v.yMin, v.yMax].every(Number.isFinite) || v.xMin >= v.xMax || v.yMin >= v.yMax)
                return d;
            if (!s.history.every(h => h && typeof h.expr === "string" && typeof h.result === "string") || !s.functions.every(f => typeof f === "string"))
                return d;
            return { mode: s.mode, angle: s.angle, input: s.input, cursor: Math.max(0, Math.min(s.input.length, s.cursor)), focusedField: ["expression", "y1", "y2", "y3"].includes(s.focusedField) ? s.focusedField : "expression", result: s.result,
                     history: s.history.slice(-100), functions: s.functions.slice(), view: { xMin: v.xMin, xMax: v.xMax, yMin: v.yMin, yMax: v.yMax } };
        } catch (e) { return d; }
    }
    function record(expr, value) {
        history = history.concat([{ expr: String(expr), result: String(value) }]).slice(-100);
        scheduleWrite();
    }
    function changed() { scheduleWrite(); }
    function clear() {
        const d = defaults();
        mode = d.mode; angle = d.angle; input = d.input; cursor = d.cursor; focusedField = d.focusedField; result = d.result;
        history = d.history; functions = d.functions; view = d.view;
        scheduleWrite();
    }
    function scheduleWrite() { if (loaded) saveTimer.restart(); }
    function flush() { if (saveTimer.running) { saveTimer.stop(); write(); } }
    function write() {
        const s = { mode, angle, input, cursor, focusedField, result, history, functions, view };
        file.setText(JSON.stringify(s));
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", `${Paths.stateHome}/quickshell`])
    onModeChanged: scheduleWrite()
    onAngleChanged: scheduleWrite()
    onInputChanged: scheduleWrite()
    onCursorChanged: scheduleWrite()
    onFocusedFieldChanged: scheduleWrite()
    onResultChanged: scheduleWrite()
    onHistoryChanged: scheduleWrite()
    onFunctionsChanged: scheduleWrite()
    onViewChanged: scheduleWrite()
    Timer { id: saveTimer; interval: 500; onTriggered: root.write() }
    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            const s = root.restore(text());
            root.mode = s.mode; root.angle = s.angle; root.input = s.input; root.cursor = s.cursor;
            root.focusedField = s.focusedField;
            root.result = s.result; root.history = s.history; root.functions = s.functions; root.view = s.view;
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) root.loaded = true;
        }
    }
}
