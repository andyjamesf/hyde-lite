pragma ComponentBehavior: Bound
import QtQuick
import qs.island.config
import qs.island.core
import qs.shared.pickers

// Power menu in the island ("power" mode): a row of tiles from config/Power.qml
// (Lock · Suspend · Log out · Restart · Power off by default).
// - Safe ones (confirm: false): one click closes the island and runs the command.
// - Destructive ones (confirm: true): the first click arms the tile (turns red, "Confirm?"); the
//   second runs it. Arming another disarms the previous one; it disarms by itself after
//   Power.confirmTimeout and when leaving the view.
// Keyboard: ←/→ move the ring · Enter/Space = click (Enter twice confirms) · Esc is left to the
// island (IslandController.back()).
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through ModeSlot).
    property bool open: false

    readonly property real islandRadius: 30
    readonly property int pad: 16
    readonly property int gap: 10

    readonly property var actions: Power.actions

    // Tile with the selection ring.
    property int current: 0
    // Armed tile (waiting for confirmation), or -1.
    property int armed: -1
    // The ring only shows after using the keyboard or really moving the mouse.
    property bool showRing: false

    focus: true
    implicitWidth: row.implicitWidth + 2 * pad
    implicitHeight: row.implicitHeight + 2 * pad

    onOpenChanged: open ? reset() : disarm()
    Component.onCompleted: if (open)
        reset()

    // Every opening starts on the first tile, with no ring and nothing armed.
    function reset() {
        current = 0;
        armed = -1;
        showRing = false;
        // Ignores the "fake" movements the island generates when growing under a still cursor.
        mouseGuard.reset();
        // The window's keyboard focus only arrives a moment later (and the island still reclaims it
        // when changing mode): try again after that.
        focusRetry.start();
    }

    function disarm() {
        armed = -1;
        disarmTimer.stop();
    }

    function trigger(i) {
        const a = actions[i];
        if (!a)
            return;
        current = i;
        if (a.confirm && armed !== i) {
            armed = i;
            disarmTimer.restart();
            return;
        }
        disarm();
        // Close first (the island goes back to the clock) and only then run it.
        IslandController.close();
        Launch.run(a.command);
    }

    function move(delta) {
        const next = Math.max(0, Math.min(actions.length - 1, current + delta));
        if (next !== current)
            disarm();
        current = next;
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            break;
        case Qt.Key_Right:
            move(1);
            break;
        case Qt.Key_Home:
            move(-actions.length);
            break;
        case Qt.Key_End:
            move(actions.length);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            trigger(current);
            break;
        default:
            // Esc and the rest go on to the island.
            return;
        }
        showRing = true;
        event.accepted = true;
    }

    MouseGuard {
        id: mouseGuard
    }

    FocusRetry {
        id: focusRetry
        target: root
        when: root.open
    }

    Timer {
        id: disarmTimer
        interval: Power.confirmTimeout
        onTriggered: root.armed = -1
    }

    // Under everything: swallows clicks between the tiles and gives the focus back to the view.
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: root.actions

            PowerTile {
                required property var modelData
                required property int index

                glyph: modelData.glyph
                label: modelData.label
                destructive: modelData.confirm
                armed: root.armed === index
                selected: root.showRing && root.current === index
                // Mouse movement over a tile only counts if the cursor really moved.
                onMoved: g => {
                    if (mouseGuard.moved(null, g.x, g.y)) {
                        root.current = index;
                        root.showRing = true;
                    }
                }
                onClicked: {
                    root.forceActiveFocus();
                    root.trigger(index);
                }
            }
        }
    }
}
