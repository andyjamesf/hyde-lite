pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.bar.components
import qs.bar.services
import qs.shared.services

// The three functions beside their plot; pointer movement reads existing samples only.
RowLayout {
    id: root
    property var functions: ["", "", ""]
    property var view: ({ xMin: -10, xMax: 10, yMin: -10, yMax: 10 })
    property var samples: [[], [], []]
    property string readout: ""
    property var functionFields: []
    property real dragX: 0
    property real dragY: 0
    readonly property var colors: [Theme.primary, Theme.success, Theme.warning]
    signal viewRequested(var view)
    signal focusRequested(int index)
    signal keyPressed(var event)
    spacing: Theme.space3

    function focusField(index) {
        functionFields[index]?.forceActiveFocus();
    }
    function zoomCentre(factor) {
        viewRequested(GraphMath.zoom(view, factor, (view.xMin + view.xMax) / 2, (view.yMin + view.yMax) / 2));
    }
    onFunctionsChanged: resample()
    onViewChanged: resample()
    Connections {
        target: CalculatorState
        function onAngleChanged() { root.resample(); }
        // Typing breaks the binding from the host, so "Clear all" is brought in here.
        function onFunctionsChanged() {
            if (JSON.stringify(root.functions) !== JSON.stringify(CalculatorState.functions))
                root.functions = CalculatorState.functions.slice();
        }
    }
    Connections {
        target: Theme
        function onPrimaryChanged() { canvas.requestPaint(); }
        function onSuccessChanged() { canvas.requestPaint(); }
        function onWarningChanged() { canvas.requestPaint(); }
        function onSurfaceContainerChanged() { canvas.requestPaint(); }
    }
    function resample() {
        samples = functions.map(f => f.trim() === "" ? [] : GraphMath.sample(Calculator.compile(f, CalculatorState.angle) || (() => null), view, Math.max(100, Math.floor(canvas.width))));
        canvas.requestPaint();
    }
    ColumnLayout {
        Layout.preferredWidth: 250
        Layout.maximumWidth: 250
        Layout.fillHeight: true
        spacing: Theme.space2

        Repeater {
            model: 3
            ColumnLayout {
                id: functionRow
                required property int index
                readonly property string formula: root.functions[index]
                Layout.fillWidth: true
                spacing: 2

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Theme.shapeSmall
                    color: Theme.surfaceContainerHighest
                    border.width: field.activeFocus ? 2 : 1
                    border.color: field.activeFocus ? root.colors[functionRow.index] : Theme.border

                    StyledText {
                        id: name
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: `y${functionRow.index + 1} =`
                        color: root.colors[functionRow.index]
                        font.pixelSize: Theme.titleMedium
                        font.weight: Font.Bold
                    }
                    TextInput {
                        id: field
                        Component.onCompleted: {
                            text = functionRow.formula;
                            const fields = root.functionFields.slice();
                            fields[functionRow.index] = this;
                            root.functionFields = fields;
                        }
                        anchors.left: name.right
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        color: Theme.text
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onPrimary
                        font.family: Config.appearance.font
                        font.pixelSize: Theme.titleMedium
                        onActiveFocusChanged: if (activeFocus) root.focusRequested(functionRow.index)
                        onTextChanged: {
                            if (root.functions[functionRow.index] === text)
                                return;
                            const values = root.functions.slice();
                            values[functionRow.index] = text;
                            root.functions = values;
                        }
                        Connections {
                            target: root
                            function onFunctionsChanged() {
                                if (field.text !== root.functions[functionRow.index])
                                    field.text = root.functions[functionRow.index];
                            }
                        }
                        Keys.onPressed: event => root.keyPressed(event)

                        StyledText {
                            anchors.fill: parent
                            visible: field.text === ""
                            text: ["x^2 - 4", "sin(x)", "1/x"][functionRow.index]
                            color: Theme.textFaint
                            font.pixelSize: Theme.titleMedium
                        }
                    }
                }
                StyledText {
                    visible: functionRow.formula !== "" && Calculator.compile(functionRow.formula, CalculatorState.angle) === null
                    Layout.leftMargin: 12
                    text: "Unknown graph function"
                    color: Theme.error
                    font.pixelSize: Theme.labelSmall
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.readout || "Drag to move, scroll to zoom"
            color: Theme.textDim
            font.pixelSize: Theme.bodyMedium
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            spacing: Theme.space3
            IconButton { icon: "zoom_out"; tonal: true; size: 38; tooltip: "Zoom out"; tooltipBelow: false; onClicked: root.zoomCentre(1.25) }
            IconButton { icon: "center_focus_strong"; tonal: true; size: 38; tooltip: "Reset view"; tooltipBelow: false; onClicked: root.viewRequested(CalculatorState.defaults().view) }
            IconButton { icon: "zoom_in"; tonal: true; size: 38; tooltip: "Zoom in"; tooltipBelow: false; onClicked: root.zoomCentre(0.8) }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.shapeMedium
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.border

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 6
            onWidthChanged: root.resample()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                ctx.fillStyle = Theme.surfaceContainer; ctx.fillRect(0, 0, width, height);
                const px = x => (x - root.view.xMin) / (root.view.xMax - root.view.xMin) * width;
                const py = y => height - (y - root.view.yMin) / (root.view.yMax - root.view.yMin) * height;
                ctx.font = `${Theme.labelSmall}px sans-serif`;
                ctx.fillStyle = Theme.textDim;
                ctx.strokeStyle = Theme.alpha(Theme.text, 0.10);
                ctx.lineWidth = 1;
                GraphMath.ticks(root.view.xMin, root.view.xMax, Math.max(2, Math.floor(width / 70))).forEach(value => {
                    const x = px(value);
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                    if (x > 16 && x < width - 16) ctx.fillText(String(value), x + 2, Math.max(12, Math.min(height - 3, py(0) + 12)));
                });
                GraphMath.ticks(root.view.yMin, root.view.yMax, Math.max(2, Math.floor(height / 32))).forEach(value => {
                    const y = py(value);
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                    if (value !== 0 && y > 10 && y < height - 2) ctx.fillText(String(value), Math.max(2, Math.min(width - 28, px(0) + 4)), y - 2);
                });
                ctx.strokeStyle = Theme.alpha(Theme.text, 0.25); ctx.lineWidth = 1;
                ctx.beginPath(); if (root.view.xMin <= 0 && root.view.xMax >= 0) { ctx.moveTo(px(0), 0); ctx.lineTo(px(0), height); }
                if (root.view.yMin <= 0 && root.view.yMax >= 0) { ctx.moveTo(0, py(0)); ctx.lineTo(width, py(0)); } ctx.stroke();
                ctx.fillStyle = Theme.textDim; ctx.font = `${Theme.labelSmall}px sans-serif`;
                ctx.fillText("x", width - 12, Math.max(12, Math.min(height - 4, py(0) - 4)));
                ctx.fillText("y", Math.max(4, Math.min(width - 12, px(0) + 4)), 12);
                root.samples.forEach((curve, i) => {
                    ctx.strokeStyle = root.colors[i]; ctx.lineWidth = 2;
                    curve.forEach(segment => { ctx.beginPath(); segment.forEach((point, n) => n === 0 ? ctx.moveTo(px(point[0]), py(point[1])) : ctx.lineTo(px(point[0]), py(point[1]))); ctx.stroke(); });
                });
            }
            HoverHandler {
                onPointChanged: {
                    const x = root.view.xMin + point.position.x / canvas.width * (root.view.xMax - root.view.xMin);
                    const y = root.view.yMax - point.position.y / canvas.height * (root.view.yMax - root.view.yMin);
                    root.readout = `x ${Math.round(x * 100) / 100}, y ${Math.round(y * 100) / 100}`;
                }
            }
            DragHandler {
                target: null
                onActiveChanged: { root.dragX = 0; root.dragY = 0; }
                onTranslationChanged: {
                    const dx = translation.x - root.dragX;
                    const dy = translation.y - root.dragY;
                    root.dragX = translation.x;
                    root.dragY = translation.y;
                    if (dx === 0 && dy === 0) return;
                    root.viewRequested(GraphMath.pan(root.view, -dx / canvas.width, dy / canvas.height));
                }
            }
            WheelHandler {
                onWheel: event => {
                    const factor = event.angleDelta.y > 0 ? 0.8 : 1.25;
                    const cx = root.view.xMin + event.position.x / canvas.width * (root.view.xMax - root.view.xMin);
                    const cy = root.view.yMax - event.position.y / canvas.height * (root.view.yMax - root.view.yMin);
                    root.viewRequested(GraphMath.zoom(root.view, factor, cx, cy));
                }
            }
        }
    }
}
