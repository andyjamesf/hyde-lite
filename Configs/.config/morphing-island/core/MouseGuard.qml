import QtQuick
import qs.config

// Tells real mouse movement apart from the synthetic motion a compositor sends when a view opens
// or grows under a still cursor. Call reset() when the view opens; call moved(item, x, y) from
// onPositionChanged/onEntered: it returns true only for real movement (after Behaviour.mouseGuardMs
// and by more than Behaviour.mouseGuardPx on either axis).
//
//   MouseGuard { id: guard }
//   onOpened: guard.reset()
//   onPositionChanged: m => { if (guard.moved(this, m.x, m.y)) select(); }
QtObject {
    id: guard

    // Last global position seen (x < 0 = none yet).
    property point last: Qt.point(-1, -1)
    // When the view opened (ms since epoch).
    property real openedAt: 0
    // Becomes true after the first real movement since reset().
    property bool active: false

    function reset() {
        last = Qt.point(-1, -1);
        openedAt = Date.now();
        active = false;
    }

    // `item` maps (x, y) to global coordinates, so the check survives the view moving/resizing.
    // Pass item = null when x/y are already global.
    function moved(item, x, y) {
        const g = item ? item.mapToGlobal(x, y) : Qt.point(x, y);
        if (Date.now() - openedAt < Behaviour.mouseGuardMs || last.x < 0) {
            last = g;
            return false;
        }
        const px = Behaviour.mouseGuardPx;
        if (Math.abs(g.x - last.x) > px || Math.abs(g.y - last.y) > px) {
            last = g;
            active = true;
            return true;
        }
        return false;
    }
}
