import QtQuick
import qs.config
import qs.theme

// A row of choices as chips (wraps to more lines when needed). `options`: [{ label, value }];
// `value` is the chosen one (with `multi`, `values` holds several). Picking one emits `picked`.
Flow {
    id: root

    property var options: []
    property var value: undefined
    property bool multi: false
    property var values: []

    signal picked(var value)

    spacing: 6

    Repeater {
        model: root.options

        Rectangle {
            id: chip

            required property var modelData
            readonly property bool chosen: root.multi ? root.values.includes(modelData.value) : root.value === modelData.value

            width: label.implicitWidth + 22
            height: 28
            radius: 14
            color: chosen ? Theme.accent : mouse.pressed ? Theme.pressed : mouse.containsMouse ? Theme.hover : Theme.surface
            border.width: chosen ? 0 : 1
            border.color: Theme.border

            Label {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.label
                font.pixelSize: Appearance.fontSize - 1
                color: chip.chosen ? Theme.accentContent : Theme.foreground
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.multi) {
                        const v = chip.modelData.value;
                        root.values = root.values.includes(v) ? root.values.filter(x => x !== v) : root.values.concat([v]);
                    } else {
                        root.value = chip.modelData.value;
                    }
                    root.picked(chip.modelData.value);
                }
            }
        }
    }
}
