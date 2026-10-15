pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Extra pills beside the clock island (the island builder). Each is a list of widgets, drawn like the status
// pill: any id StatusZone knows (volume, wifi, battery, clock, date, mic, brightness, media...), plus
// "workspaces" for the workspace indicator. They live in prefs.json:
//   "pills.extra": [ { "side": "right", "widgets": ["clock", "media"] }, ... ]
// Up to maxPills; a pill that is not valid drops the whole list (config/PrefsSchema.qml reports why), and with
// no key set there are none: the island looks as it always did. Like the workspace and status pills they
// stack outward from the screen's edges and are absorbed into the island when it expands.
Singleton {
    // How many extra pills there can be (PrefsSchema checks the same number).
    readonly property int maxPills: 4
    // Space between neighbouring pills, in pixels. Default 8.
    readonly property int gap: 8
    // Inner padding at each end of a pill, in pixels. Default 12.
    readonly property int padding: 12
    // Space between the workspaces and the icons inside one pill, in pixels. Default 8.
    readonly property int innerSpacing: 8

    readonly property var extra: Prefs.get("pills.extra", [])

    // Edits of the pill list, pure so the Settings editor and the tests share them. Each returns a new list.
    function withPill(list, side) {
        return list.length >= maxPills ? list.slice() : list.concat([{ side: side, widgets: ["clock"] }]);
    }
    function withoutPill(list, k) {
        return list.filter((_, i) => i !== k);
    }
    function withSide(list, k, side) {
        return list.map((p, i) => i === k ? { side: side, widgets: p.widgets } : p);
    }
    // An empty widget list is not a valid pill, so emptying one removes it.
    function withWidgets(list, k, widgets) {
        return widgets.length === 0 ? withoutPill(list, k) : list.map((p, i) => i === k ? { side: p.side, widgets: widgets } : p);
    }

    // Left edge of pill k. `list` is the extra list, `widths` the pills' widths in the same order. Left pills
    // stack rightwards from `leftStart`, right pills leftwards from `rightStart` (the x their right edge starts
    // at); a pill of the other side in between does not move it.
    function xFor(list, widths, k, leftStart, rightStart, gap) {
        const side = list[k].side;
        let x = side === "left" ? leftStart : rightStart;
        for (let j = 0; j < k; j++) {
            if (list[j].side !== side)
                continue;
            x += side === "left" ? widths[j] + gap : -(widths[j] + gap);
        }
        return side === "left" ? x : x - widths[k];
    }
}
