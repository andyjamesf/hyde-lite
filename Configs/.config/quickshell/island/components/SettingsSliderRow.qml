import QtQuick
import qs.shared.controlcenter

// A row with a slider (BigSlider) for a value between `from` and `to`, in steps of `step`.
// Applies live: every movement emits valueEdited(v) with the value already rounded to the step;
// the user writes it to the preferences. Left/right arrows arrive through the view as
// adjustRequested(±1) and move one step.
SettingsRow {
    id: root

    property real from: 0
    property real to: 1
    property real step: 1
    property real value: 0
    // Value text inside the track (e.g. "36 px").
    property string valueText: ""
    // Track width.
    property real sliderWidth: 220

    signal valueEdited(real v)

    clickable: false

    function snap(v) {
        const n = Math.round((v - from) / step);
        const out = from + n * step;
        // Avoids 1.2000000000000002 and the like.
        return Math.max(from, Math.min(to, Math.round(out * 1000) / 1000));
    }

    function edit(v) {
        const s = snap(v);
        if (s !== value)
            valueEdited(s);
    }

    onAdjustRequested: direction => edit(value + direction * step)

    BigSlider {
        width: root.sliderWidth
        thickness: 26
        value: (root.value - root.from) / (root.to - root.from)
        wheelStep: root.step / (root.to - root.from)
        label: root.valueText
        onMoved: v => root.edit(root.from + v * (root.to - root.from))
    }
}
