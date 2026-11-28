pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.bar.services
import qs.bar.components
import qs.shared.services

// Scientific keypad: functions on the left, digits and operators on the right, editing keys below.
// A key inserts at the cursor of `input`; the ones with an `action` edit or run instead.
ColumnLayout {
    id: root

    property var input: null
    signal runRequested()

    spacing: Theme.space2

    function press(key) {
        const field = root.input;
        if (!field)
            return;
        if (key.action === "run") {
            runRequested();
        } else if (key.action === "clear") {
            CalculatorState.input = "";
            CalculatorState.result = "";
        } else if (key.action === "clearAll") {
            CalculatorState.clear();
        } else if (key.action === "back") {
            if (field.selectedText !== "")
                field.remove(field.selectionStart, field.selectionEnd);
            else if (field.cursorPosition > 0)
                field.remove(field.cursorPosition - 1, field.cursorPosition);
        } else {
            field.insert(field.cursorPosition, key.text ?? key.label);
        }
        field.forceActiveFocus();
    }

    component KeypadKey: Rectangle {
        id: key
        required property var modelData
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 1
        radius: Theme.shapeSmall
        color: modelData.tone === "accent" ? Theme.primary
            : modelData.tone === "operator" ? Theme.primaryContainer
            : Theme.alpha(Theme.text, modelData.tone === "digit" ? 0.11 : 0.05)

        StyledText {
            anchors.centerIn: parent
            text: key.modelData.label
            color: key.modelData.tone === "accent" ? Theme.onPrimary : Theme.text
            font.pixelSize: key.modelData.tone === "digit" ? Theme.titleLarge : Theme.titleMedium
        }
        StateLayer {
            anchors.fill: parent
            radius: Theme.shapeSmall
            onClicked: root.press(key.modelData)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.space4

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: [
                    { label: "sin", text: "sin(" }, { label: "cos", text: "cos(" }, { label: "tan", text: "tan(" }, { label: "√", text: "sqrt(" },
                    { label: "asin", text: "asin(" }, { label: "acos", text: "acos(" }, { label: "atan", text: "atan(" }, { label: "xʸ", text: "^" },
                    { label: "ln", text: "ln(" }, { label: "log", text: "log(" }, { label: "π", text: "pi" }, { label: "e" },
                    { label: "(" }, { label: ")" }, { label: "n!", text: "!" }, { label: "%" }
                ]
                KeypadKey {}
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: [
                    { label: "7", tone: "digit" }, { label: "8", tone: "digit" }, { label: "9", tone: "digit" }, { label: "÷", text: "/", tone: "operator" },
                    { label: "4", tone: "digit" }, { label: "5", tone: "digit" }, { label: "6", tone: "digit" }, { label: "×", text: "*", tone: "operator" },
                    { label: "1", tone: "digit" }, { label: "2", tone: "digit" }, { label: "3", tone: "digit" }, { label: "−", text: "-", tone: "operator" },
                    { label: "0", tone: "digit" }, { label: ".", tone: "digit" }, { label: "=", action: "run", tone: "accent" }, { label: "+", tone: "operator" }
                ]
                KeypadKey {}
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: 36
        Layout.maximumHeight: 36
        spacing: 6

        Repeater {
            model: [
                { label: "to unit", text: " to " }, { label: "⌫ delete", action: "back" },
                { label: "C clear", action: "clear" }, { label: "Clear all", action: "clearAll" }
            ]
            KeypadKey {}
        }
    }
}
