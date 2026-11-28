pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.bar.components
import qs.bar.services
import qs.shared.services

// Calculator tab. Keyboard and Scientific share the display (expression and result); Keyboard puts the
// history below it, Scientific a keypad. Graph has the three functions beside the plot.
Item {
    id: root

    property bool open: false
    signal closeRequested()
    signal cycleTabRequested(int step)

    property int historyIndex: -1
    property string pendingExpr: ""
    property bool copyPending: false
    property bool resultError: false
    property string focusedField: CalculatorState.focusedField
    readonly property bool graphMode: CalculatorState.mode === "graph"

    implicitHeight: 500
    Component.onCompleted: Qt.callLater(restoreFocus)
    Component.onDestruction: CalculatorState.flush()
    onOpenChanged: {
        if (open)
            Qt.callLater(restoreFocus);
        else
            CalculatorState.flush();
    }

    // The field that was in use, among those the current mode shows.
    function restoreFocus() {
        if (graphMode) {
            const index = Math.max(0, ["y1", "y2", "y3"].indexOf(CalculatorState.focusedField));
            graph.focusField(index);
            return;
        }
        expressionInput.forceActiveFocus();
        expressionInput.cursorPosition = CalculatorState.cursor;
    }
    function evaluate() {
        const expr = CalculatorState.input.trim();
        if (expr === "") {
            CalculatorState.result = "";
            return;
        }
        pendingExpr = expr;
        if (Qalc.installed) {
            Qalc.evaluate(expr, CalculatorState.angle);
        } else {
            const value = Calculator.evaluate(expr, CalculatorState.angle);
            CalculatorState.result = value === null ? "Invalid expression" : Calculator.format(value);
            resultError = value === null;
        }
    }
    function copyResult() {
        debounce.stop();
        pendingExpr = CalculatorState.input.trim();
        if (pendingExpr === "")
            return;
        if (Qalc.installed) {
            copyPending = true;
            Qalc.evaluate(pendingExpr, CalculatorState.angle);
            return;
        }
        evaluate();
        copyAndRecord();
    }
    function copyAndRecord() {
        if (!resultError && CalculatorState.result !== "" && CalculatorState.result !== "Invalid expression") {
            Quickshell.execDetached(["wl-copy", "--", CalculatorState.result]);
            CalculatorState.record(pendingExpr, CalculatorState.result);
            historyIndex = -1;
        }
    }
    function useExpression(text) {
        CalculatorState.input = text;
        expressionInput.cursorPosition = text.length;
        expressionInput.forceActiveFocus();
    }
    function stepHistory(step) {
        const count = CalculatorState.history.length;
        if (count === 0 || (step < 0 && historyIndex < 0))
            return;
        historyIndex = Math.max(-1, Math.min(count - 1, historyIndex + step));
        useExpression(historyIndex < 0 ? "" : CalculatorState.history[count - 1 - historyIndex].expr);
    }
    // Every shortcut of the tab, for whichever field has the keys.
    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Escape) {
            closeRequested();
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            cycleTabRequested(event.key === Qt.Key_Backtab || event.modifiers & Qt.ShiftModifier ? -1 : 1);
        } else if (graphMode && event.modifiers & Qt.AltModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
            graph.focusField(event.key - Qt.Key_1);
        } else if (!graphMode && !ctrl && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
            stepHistory(event.key === Qt.Key_Up ? 1 : -1);
        } else if (!ctrl) {
            return;
        } else if (event.key === Qt.Key_1) {
            CalculatorState.mode = "keyboard";
        } else if (event.key === Qt.Key_2) {
            CalculatorState.mode = "scientific";
        } else if (event.key === Qt.Key_3) {
            CalculatorState.mode = "graph";
        } else if (event.key === Qt.Key_D) {
            CalculatorState.angle = CalculatorState.angle === "deg" ? "rad" : "deg";
        } else if (!graphMode) {
            return;
        } else if (event.key === Qt.Key_0) {
            CalculatorState.view = CalculatorState.defaults().view;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            graph.zoomCentre(0.8);
        } else if (event.key === Qt.Key_Minus) {
            graph.zoomCentre(1.25);
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            CalculatorState.view = GraphMath.pan(CalculatorState.view, event.key === Qt.Key_Left ? -0.1 : 0.1, 0);
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            CalculatorState.view = GraphMath.pan(CalculatorState.view, 0, event.key === Qt.Key_Up ? 0.1 : -0.1);
        } else {
            return;
        }
        event.accepted = true;
    }

    Connections {
        target: CalculatorState
        function onModeChanged() {
            Qt.callLater(root.restoreFocus);
        }
        function onAngleChanged() {
            debounce.restart();
        }
    }
    Connections {
        target: Qalc
        function onAnswered(expr, ok, text) {
            if (expr !== root.pendingExpr)
                return;
            CalculatorState.result = text;
            root.resultError = !ok;
            if (root.copyPending && expr === CalculatorState.input.trim()) {
                root.copyPending = false;
                root.copyAndRecord();
            }
        }
    }
    Timer {
        id: debounce
        interval: 150
        onTriggered: root.evaluate()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space3

        // Mode switch on the left, angle unit on the right.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false

            Rectangle {
                implicitWidth: modes.implicitWidth + 8
                implicitHeight: 36
                radius: height / 2
                color: Theme.surfaceContainerHighest

                Row {
                    id: modes
                    anchors.centerIn: parent

                    Repeater {
                        model: [
                            { id: "keyboard", title: "Keyboard" },
                            { id: "scientific", title: "Scientific" },
                            { id: "graph", title: "Graph" }
                        ]

                        Rectangle {
                            id: segment
                            required property var modelData
                            readonly property bool current: CalculatorState.mode === modelData.id
                            width: 104
                            height: 28
                            radius: height / 2
                            color: current ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: segment.modelData.title
                                color: segment.current ? Theme.onPrimary : Theme.textDim
                                font.pixelSize: Theme.labelLarge
                                font.weight: segment.current ? Font.DemiBold : Font.Normal
                            }
                            StateLayer {
                                anchors.fill: parent
                                radius: height / 2
                                onClicked: CalculatorState.mode = segment.modelData.id
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                implicitWidth: 64
                implicitHeight: 36
                radius: height / 2
                color: Theme.primaryContainer

                StyledText {
                    anchors.centerIn: parent
                    text: CalculatorState.angle === "deg" ? "DEG" : "RAD"
                    color: Theme.text
                    font.pixelSize: Theme.labelLarge
                    font.weight: Font.Bold
                }
                StateLayer {
                    anchors.fill: parent
                    radius: height / 2
                    onClicked: CalculatorState.angle = CalculatorState.angle === "deg" ? "rad" : "deg"
                }
            }
        }

        // Display: the expression above, its result large below.
        Rectangle {
            visible: !root.graphMode
            Layout.fillWidth: true
            Layout.preferredHeight: 108
            radius: Theme.shapeMedium
            color: Theme.surfaceContainerHighest
            border.width: expressionInput.activeFocus ? 2 : 1
            border.color: expressionInput.activeFocus ? Theme.primary : Theme.border

            TextInput {
                id: expressionInput
                property bool trackingCursor: false
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space4
                clip: true
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.onPrimary
                font.family: Config.appearance.font
                font.pixelSize: Theme.titleLarge
                Component.onCompleted: {
                    text = CalculatorState.input;
                    cursorPosition = CalculatorState.cursor;
                    Qt.callLater(() => trackingCursor = true);
                }
                Connections {
                    target: CalculatorState
                    function onInputChanged() {
                        if (expressionInput.text !== CalculatorState.input)
                            expressionInput.text = CalculatorState.input;
                    }
                }
                onActiveFocusChanged: if (activeFocus) CalculatorState.focusedField = "expression"
                onTextChanged: {
                    if (CalculatorState.input !== text)
                        CalculatorState.input = text;
                    debounce.restart();
                }
                onCursorPositionChanged: if (trackingCursor) CalculatorState.cursor = cursorPosition
                Keys.onReturnPressed: root.copyResult()
                Keys.onEnterPressed: root.copyResult()
                Keys.onPressed: event => root.handleKey(event)

                StyledText {
                    anchors.fill: parent
                    visible: expressionInput.text === ""
                    text: "Type a calculation, e.g. sqrt(2)*10 or 10 km to mile"
                    color: Theme.textFaint
                    font.pixelSize: Theme.titleMedium
                }
            }
            StyledText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.space4
                anchors.rightMargin: Theme.space4
                anchors.bottomMargin: Theme.space2
                height: 46
                horizontalAlignment: Text.AlignRight
                text: CalculatorState.result
                color: root.resultError ? Theme.error : Theme.primary
                font.pixelSize: Theme.displaySmall
                fontSizeMode: Text.Fit
                minimumPixelSize: Theme.bodyMedium
            }
        }

        // Keyboard: the history, newest first, right under the display it comes from.
        ListView {
            id: historyList
            visible: CalculatorState.mode === "keyboard"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: CalculatorState.history.slice().reverse()

            StyledText {
                anchors.centerIn: parent
                visible: historyList.count === 0
                text: "Results copied with Enter are listed here"
                color: Theme.textFaint
                font.pixelSize: Theme.bodyMedium
            }
            delegate: Rectangle {
                id: entry
                required property var modelData
                width: historyList.width
                height: 34
                radius: Theme.shapeSmall
                color: "transparent"

                StyledText {
                    anchors.left: parent.left
                    anchors.right: value.left
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.expr
                    textFormat: Text.PlainText
                    color: Theme.textDim
                    font.pixelSize: Theme.bodyMedium
                }
                StyledText {
                    id: value
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space3
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, entry.width * 0.6)
                    text: entry.modelData.result
                    textFormat: Text.PlainText
                    font.pixelSize: Theme.titleMedium
                }
                StateLayer {
                    anchors.fill: parent
                    radius: Theme.shapeSmall
                    onClicked: root.useExpression(entry.modelData.expr)
                }
            }
        }

        CalcKeypad {
            visible: CalculatorState.mode === "scientific"
            Layout.fillWidth: true
            Layout.fillHeight: true
            input: expressionInput
            onRunRequested: root.copyResult()
        }

        CalcGraph {
            id: graph
            visible: root.graphMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            functions: CalculatorState.functions
            view: CalculatorState.view
            onFunctionsChanged: CalculatorState.functions = functions
            onViewRequested: view => CalculatorState.view = view
            onFocusRequested: index => CalculatorState.focusedField = `y${index + 1}`
            onKeyPressed: event => root.handleKey(event)
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !Qalc.installed && !root.graphMode ? "Install libqalculate for the full calculator"
                : root.graphMode ? "Alt+1·2·3 function  ·  Ctrl + / − zoom  ·  Ctrl+arrows move  ·  Ctrl+0 reset  ·  Ctrl+1·2·3 mode"
                : "Enter copies  ·  ↑↓ history  ·  Ctrl+D angle  ·  Ctrl+1·2·3 mode"
            color: Theme.textFaint
            font.pixelSize: Theme.labelSmall
        }
    }
}
