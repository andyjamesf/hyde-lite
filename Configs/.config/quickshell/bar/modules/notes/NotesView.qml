pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.bar.components
import qs.bar.services

// Quick notes, without a window: hosted by the notes window (NotesWindow.qml, a card in the middle of the
// screen) and by the control centre's Notes tab. The host says when it is `open` and what to do on
// `closeRequested`.
//
// Quick notes. Two faces:
//   edit  the open note, written line by line like Obsidian's live preview: the line the cursor is on
//         shows its Markdown, every other line is rendered (headings, bold, lists, quotes, code).
//   list  every note as a card with a preview, filtered by what is typed; Enter opens the first.
// The notes are .md files in the Obsidian vault (services/Notes.qml).
// A selection that spans lines (Shift+arrows, Ctrl+A, dragging) turns the page into one plain text for as
// long as it lasts, so selecting, copying and replacing work as in any editor.
// Ctrl+N new · Ctrl+S save · Ctrl+L all notes · Esc / click outside closes.
Item {
    id: win

    property bool open: false
    signal closeRequested
    // The control centre's Tab and Shift+Tab: with `tabCycles` the page does not type a tab, it asks
    // the host to go to the next or previous tab.
    property bool tabCycles: false
    signal cycleTabRequested(int step)

    function tabKey(event) {
        if (!tabCycles || (event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab))
            return false;
        cycleTabRequested(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
        event.accepted = true;
        return true;
    }
    readonly property bool listing: ShellState.notesMode === "list"
    // The line being edited (index into `lines`), and where to put the cursor in it when it opens:
    // -1 = the end.
    property int cur: 0
    property int wantPos: -1
    // A selection over several lines: the whole note as one plain text (`raw`) until it collapses.
    property bool rawMode: false
    property bool rawEntering: false
    // The mouse button is down on the page, which may turn into a selection.
    property bool dragging: false
    // Undo: whole-note snapshots, typing within half a second counts as one step.
    property var hist: []
    property int hi: -1
    property real histT: 0
    readonly property string stats: {
        const n = Notes.text.trim();
        if (n === "")
            return "";
        const words = n.split(/\s+/).length;
        return `${words} ${words === 1 ? "word" : "words"}`;
    }
    readonly property string query: search.text.trim().toLowerCase()
    // "New note" first, then the notes that contain what is typed.
    readonly property var cards: [
        {
            isNew: true
        }
    ].concat(Notes.notes.filter(n => query === "" || n.search.includes(query)))

    implicitWidth: 700
    implicitHeight: 480

    function focusNow() {
        if (listing)
            search.focusInput();
        else
            gotoLine(lines.count - 1, -1);
    }

    function init() {
        if (open) {
            search.text = "";
            rawMode = false;
            Notes.refresh();
            Notes.resume();
            resetHistory();
            focusTimer.restart();
        }
    }

    onOpenChanged: init()
    onListingChanged: if (open)
        focusTimer.restart()

    function close() {
        Notes.save();
        closeRequested();
    }

    function pick(c) {
        if (c.isNew)
            Notes.newNote();
        else
            Notes.openNote(c.path);
        ShellState.notesMode = "edit";
    }

    // ── The page as lines ─────────────────────────────────────────────────────────────────
    // One row per line of the note. Rows are edited in place (setProperty), never rebuilt while
    // typing, or the line being written would lose the keyboard. Notes.text is the lines joined.
    ListModel {
        id: lines
    }

    function joined() {
        const out = [];
        for (let i = 0; i < lines.count; i++)
            out.push(lines.get(i).t);
        return out.join("\n");
    }

    // "text", "code" (inside a fenced block) or "fence" (the ``` line itself).
    function classify() {
        let inCode = false;
        for (let i = 0; i < lines.count; i++) {
            const fence = /^\s*(```|~~~)/.test(lines.get(i).t);
            const kind = fence ? "fence" : inCode ? "code" : "text";
            if (fence)
                inCode = !inCode;
            if (lines.get(i).kind !== kind)
                lines.setProperty(i, "kind", kind);
        }
    }

    function load(text) {
        lines.clear();
        for (const l of text.split("\n"))
            lines.append({
                t: l,
                kind: "text"
            });
        classify();
        cur = Math.min(cur, lines.count - 1);
    }

    function commit() {
        classify();
        Notes.set(joined());
        snap();
    }

    function lenOf(i) {
        return lines.get(i).t.length;
    }

    // Offset of the start of line i in the whole text.
    function lineStart(i) {
        let n = 0;
        for (let k = 0; k < i; k++)
            n += lenOf(k) + 1;
        return n;
    }

    function rowAt(y) {
        for (let i = 0; i < lines.count; i++) {
            const it = rep.itemAt(i);
            if (it && y < it.y + it.height)
                return i;
        }
        return lines.count - 1;
    }

    // ── Selections over several lines ─────────────────────────────────────────────────────
    function enterRaw(a, b) {
        rawEntering = true;
        rawMode = true;
        raw.text = Notes.text;
        raw.forceActiveFocus();
        raw.select(a, b);
        Qt.callLater(() => win.rawEntering = false);
    }

    function exitRawIfCollapsed() {
        if (!rawMode || rawEntering || raw.selectionStart !== raw.selectionEnd)
            return;
        const off = raw.cursorPosition;
        const text = raw.text;
        rawMode = false;
        cur = -1;
        load(text);
        let n = 0;
        let i = 0;
        for (; i < lines.count - 1; i++) {
            if (off <= n + lenOf(i))
                break;
            n += lenOf(i) + 1;
        }
        commit();
        gotoLine(i, off - n);
    }

    // Dragging from line a to line b selects the lines from a's start (or end) to b's.
    function dragSelect(a, b) {
        const anchor = a <= b ? lineStart(a) : lineStart(a) + lenOf(a);
        const head = a <= b ? lineStart(b) + lenOf(b) : lineStart(b);
        if (rawMode)
            raw.select(anchor, head);
        else
            enterRaw(anchor, head);
    }

    // ── Undo ──────────────────────────────────────────────────────────────────────────────
    function snap() {
        const t = Notes.text;
        if (hi >= 0 && hist[hi].text === t)
            return;
        const now = Date.now();
        const h = hist.slice(0, hi + 1);
        const entry = {
            text: t,
            line: cur
        };
        if (now - histT < 500 && h.length > 1)
            h[h.length - 1] = entry;
        else
            h.push(entry);
        hist = h;
        hi = h.length - 1;
        histT = now;
    }

    function resetHistory() {
        hist = [
            {
                text: Notes.text,
                line: cur
            }
        ];
        hi = 0;
        histT = 0;
    }

    function restore(i) {
        if (i < 0 || i >= hist.length)
            return;
        hi = i;
        const e = hist[i];
        load(e.text);
        Notes.set(e.text);
        gotoLine(Math.min(e.line, lines.count - 1), -1);
    }
    function undo() {
        histT = 0;
        restore(hi - 1);
    }
    function redo() {
        restore(hi + 1);
    }

    function setLine(i, t) {
        lines.setProperty(i, "t", t);
        commit();
    }

    function gotoLine(i, pos) {
        const n = Math.max(0, Math.min(i, lines.count - 1));
        wantPos = pos;
        if (n === cur)
            rep.itemAt(n)?.refocus(pos);
        else
            cur = n;
    }

    // Enter: the line splits at the cursor. A list or quote goes on with the next marker; an empty
    // item ends the list instead.
    function enter(i, at) {
        const t = lines.get(i).t;
        const m = /^(\s*)(?:([-*+]) (?:\[[ xX]\] )?|(\d+)\. |(>) )/.exec(t);
        let prefix = "";
        if (m && at >= m[0].length) {
            if (t.length === m[0].length) {
                setLine(i, "");
                return;
            }
            prefix = m[3] ? `${m[1]}${parseInt(m[3]) + 1}. ` : m[0].replace(/\[[xX]\]/, "[ ]");
        }
        lines.setProperty(i, "t", t.slice(0, at));
        lines.insert(i + 1, {
            t: prefix + t.slice(at),
            kind: "text"
        });
        commit();
        gotoLine(i + 1, prefix.length);
    }

    // Backspace at the start of a line (or Delete at the end of the one before): the two become one.
    function join(i) {
        const a = lines.get(i).t;
        lines.setProperty(i, "t", a + lines.get(i + 1).t);
        lines.remove(i + 1);
        commit();
        gotoLine(i, a.length);
    }

    // A line whose text now has line breaks (a paste): each piece becomes a line.
    function splitInto(i, text) {
        const parts = text.split("\n");
        lines.setProperty(i, "t", parts[0]);
        for (let k = 1; k < parts.length; k++)
            lines.insert(i + k, {
                t: parts[k],
                kind: "text"
            });
        commit();
        gotoLine(i + parts.length - 1, -1);
    }

    // The note changed under us (another note opened, the file edited in Obsidian).
    Connections {
        target: Notes
        function onTextChanged() {
            if (win.rawMode || Notes.text === win.joined())
                return;
            win.load(Notes.text);
            win.resetHistory();
        }
    }

    Component.onCompleted: {
        load(Notes.text);
        init();
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: win.focusNow()
    }

    // Closing by any route must not lose what was typed inside the save delay.
    Component.onDestruction: Notes.save()

    Item {
        id: card

        anchors.fill: parent

        // Keys the text field and the editor leave alone arrive here.
        Keys.onEscapePressed: win.close()
        Keys.onPressed: event => {
            if (!(event.modifiers & Qt.ControlModifier))
                return;
            event.accepted = true;
            if (event.key === Qt.Key_N)
                win.pick({
                    isNew: true
                });
            else if (event.key === Qt.Key_S)
                Notes.save();
            else if (event.key === Qt.Key_L)
                ShellState.notesMode = win.listing ? "edit" : "list";
            else
                event.accepted = false;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.space5
            spacing: Theme.space3

            // ── Header ────────────────────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3

                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: 17
                    color: Theme.primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        icon: win.listing ? "grid_view" : "sticky_note_2"
                        size: 18
                        fill: 1
                        color: Theme.onPrimaryContainer
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: win.listing ? "All notes" : Notes.title
                    elide: Text.ElideRight
                    font.pixelSize: Theme.titleMedium
                    font.weight: Font.DemiBold
                }

                // Reassurance, not a warning: a dot while the save delay runs.
                Rectangle {
                    visible: !win.listing
                    implicitWidth: 7
                    implicitHeight: 7
                    radius: 3.5
                    color: Theme.primary
                    opacity: Notes.dirty ? 0.9 : 0

                    Behavior on opacity {
                        NumberAnim {
                            duration: Anim.fast
                        }
                    }
                }

                IconButton {
                    icon: "add"
                    size: 34
                    tooltip: "New note (Ctrl+N)"
                    onClicked: win.pick({
                        isNew: true
                    })
                }
                IconButton {
                    visible: !win.listing
                    icon: "save"
                    size: 34
                    tooltip: "Save (Ctrl+S)"
                    onClicked: Notes.save()
                }
                IconButton {
                    icon: "grid_view"
                    size: 34
                    checked: win.listing
                    tooltip: "All notes (Ctrl+L)"
                    onClicked: ShellState.notesMode = win.listing ? "edit" : "list"
                }
            }

            // ── Edit ──────────────────────────────────────────────────────────────────────
            Rectangle {
                visible: !win.listing
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.shapeLarge - 4
                color: Theme.surfaceContainerHigh

                // The mouse belongs to the page below (it selects), so scrolling is the wheel's job.
                WheelHandler {
                    onWheel: event => flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY - event.angleDelta.y))
                }

                Flickable {
                    id: flick

                    anchors.fill: parent
                    anchors.margins: Theme.space4
                    contentWidth: width
                    contentHeight: win.rawMode ? raw.height : page.implicitHeight
                    interactive: false
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // The whole note as plain text, while a selection spans lines.
                    TextEdit {
                        id: raw

                        visible: win.rawMode
                        width: flick.width
                        height: Math.max(implicitHeight, flick.height)
                        color: Theme.text
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onPrimary
                        font.family: Config.appearance.font
                        font.pixelSize: Theme.titleSmall
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        persistentSelection: true
                        onTextChanged: if (win.rawMode)
                            Notes.set(text)
                        onSelectionStartChanged: Qt.callLater(win.exitRawIfCollapsed)
                        onSelectionEndChanged: Qt.callLater(win.exitRawIfCollapsed)
                        onCursorRectangleChanged: {
                            if (!win.rawMode)
                                return;
                            const y = cursorRectangle.y;
                            if (y < flick.contentY)
                                flick.contentY = Math.max(0, y);
                            else if (y + cursorRectangle.height > flick.contentY + flick.height)
                                flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), y + cursorRectangle.height - flick.height);
                        }
                        Keys.onPressed: event => {
                            if (win.tabKey(event))
                                return;
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                                raw.selectAll();
                                event.accepted = true;
                            }
                        }
                    }

                    Column {
                        id: page

                        visible: !win.rawMode
                        width: flick.width

                        Repeater {
                            id: rep

                            model: lines

                            delegate: Item {
                                id: row

                                required property int index
                                required property string t
                                required property string kind
                                readonly property bool isCur: index === win.cur
                                readonly property int fs: Theme.titleSmall

                                width: page.width
                                height: isCur && editLoader.item ? editLoader.item.height : shown.height

                                // The link under a point (in the page's coordinates), if any.
                                function linkAtPoint(px, py) {
                                    return rendered.visible ? rendered.linkAt(px - rendered.x, py - row.y - rendered.y) : "";
                                }

                                function refocus(pos) {
                                    const e = editLoader.item;
                                    if (!e)
                                        return;
                                    e.cursorPosition = pos < 0 ? e.length : Math.min(pos, e.length);
                                    e.forceActiveFocus();
                                }

                                // The line as it reads once rendered. A blank line keeps some height.
                                Item {
                                    id: shown

                                    visible: !row.isCur
                                    width: parent.width
                                    height: row.kind === "fence" ? 4 : Math.max(rendered.height, row.t.trim() === "" ? row.fs : 0)

                                    Rectangle {
                                        visible: row.kind === "code"
                                        anchors.fill: parent
                                        color: Theme.surfaceContainerHighest
                                    }

                                    Text {
                                        id: rendered

                                        visible: row.kind !== "fence"
                                        x: row.kind === "code" ? Theme.space2 : 0
                                        width: parent.width - 2 * x
                                        // [[note]] and [[note|shown]] read as the name; Markdown does the rest.
                                        text: row.kind === "code" ? row.t : row.t.replace(/!?\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, "$1")
                                        textFormat: row.kind === "code" ? Text.PlainText : Text.MarkdownText
                                        wrapMode: Text.Wrap
                                        color: Theme.text
                                        linkColor: Theme.primary
                                        font.family: row.kind === "code" ? Config.appearance.monoFont : Config.appearance.font
                                        font.pixelSize: row.fs
                                    }
                                }

                                // The line being written, as plain Markdown.
                                Loader {
                                    id: editLoader

                                    active: row.isCur
                                    width: parent.width
                                    onLoaded: {
                                        item.text = row.t;
                                        row.refocus(win.wantPos);
                                    }

                                    sourceComponent: TextEdit {
                                        id: edit

                                        color: Theme.text
                                        selectionColor: Theme.primary
                                        selectedTextColor: Theme.onPrimary
                                        font.family: Config.appearance.font
                                        font.pixelSize: row.fs
                                        wrapMode: TextEdit.Wrap
                                        textFormat: TextEdit.PlainText
                                        persistentSelection: true
                                        // A blank line is as tall as a written one.
                                        height: Math.max(implicitHeight, row.fs + 6)

                                        onTextChanged: {
                                            if (text === row.t)
                                                return;
                                            // Pasted lines, or anything else with line breaks, become lines.
                                            if (text.includes("\n"))
                                                win.splitInto(row.index, text);
                                            else
                                                win.setLine(row.index, text);
                                        }

                                        // Keeps the caret in view while typing or moving.
                                        onCursorRectangleChanged: {
                                            const y = row.y + cursorRectangle.y;
                                            if (y < flick.contentY)
                                                flick.contentY = Math.max(0, y);
                                            else if (y + cursorRectangle.height > flick.contentY + flick.height)
                                                flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), y + cursorRectangle.height - flick.height);
                                        }

                                        Keys.onPressed: event => {
                                            if (win.tabKey(event))
                                                return;
                                            if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                                                return;
                                            const ctrl = event.modifiers & Qt.ControlModifier;
                                            const shift = event.modifiers & Qt.ShiftModifier;
                                            const noSel = selectionStart === selectionEnd;
                                            const first = cursorRectangle.y < font.pixelSize;
                                            const last = cursorRectangle.y + cursorRectangle.height > height - font.pixelSize / 2;
                                            // Where the selection began, in the whole text (the cursor is its other end).
                                            const base = win.lineStart(row.index);
                                            const anchor = base + (cursorPosition === selectionStart ? selectionEnd : selectionStart);
                                            if (ctrl) {
                                                // Not the line's own undo and select-all: the page's.
                                                if (event.key === Qt.Key_A)
                                                    win.enterRaw(0, Notes.text.length);
                                                else if (event.key === Qt.Key_Z && !shift)
                                                    win.undo();
                                                else if (event.key === Qt.Key_Y || (event.key === Qt.Key_Z && shift))
                                                    win.redo();
                                                else
                                                    return;
                                            } else if (shift && event.key === Qt.Key_Up && first && row.index > 0) {
                                                win.enterRaw(anchor, win.lineStart(row.index - 1) + Math.min(cursorPosition, win.lenOf(row.index - 1)));
                                            } else if (shift && event.key === Qt.Key_Down && last && row.index < lines.count - 1) {
                                                win.enterRaw(anchor, win.lineStart(row.index + 1) + Math.min(cursorPosition, win.lenOf(row.index + 1)));
                                            } else if (shift && event.key === Qt.Key_Left && cursorPosition === 0 && row.index > 0) {
                                                win.enterRaw(anchor, base - 1);
                                            } else if (shift && event.key === Qt.Key_Right && cursorPosition === length && row.index < lines.count - 1) {
                                                win.enterRaw(anchor, base + length + 1);
                                            } else if (shift) {
                                                return;
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                win.enter(row.index, cursorPosition);
                                            } else if (event.key === Qt.Key_Up && first && row.index > 0) {
                                                win.gotoLine(row.index - 1, -1);
                                            } else if (event.key === Qt.Key_Down && last && row.index < lines.count - 1) {
                                                win.gotoLine(row.index + 1, 0);
                                            } else if (event.key === Qt.Key_Left && noSel && cursorPosition === 0 && row.index > 0) {
                                                win.gotoLine(row.index - 1, -1);
                                            } else if (event.key === Qt.Key_Right && noSel && cursorPosition === length && row.index < lines.count - 1) {
                                                win.gotoLine(row.index + 1, 0);
                                            } else if (event.key === Qt.Key_Backspace && noSel && cursorPosition === 0 && row.index > 0) {
                                                win.join(row.index - 1);
                                            } else if (event.key === Qt.Key_Delete && noSel && cursorPosition === length && row.index < lines.count - 1) {
                                                win.join(row.index);
                                            } else {
                                                return;
                                            }
                                            event.accepted = true;
                                        }

                                        StyledText {
                                            visible: Notes.text === ""
                                            text: "Write in Markdown…"
                                            font.pixelSize: row.fs
                                            color: Theme.textFaint
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Clicks, links and drags over the rendered lines. The line being written, and the
                    // plain text, keep their own mouse.
                    MouseArea {
                        id: pageMouse

                        property int pressRow: -1
                        property bool moved: false

                        width: flick.width
                        height: Math.max(flick.contentHeight, flick.height)
                        acceptedButtons: Qt.LeftButton
                        onPressed: mouse => {
                            if (win.rawMode) {
                                mouse.accepted = false;
                                return;
                            }
                            const r = win.rowAt(mouse.y);
                            const it = rep.itemAt(r);
                            if (r === win.cur && it && mouse.y < it.y + it.height) {
                                mouse.accepted = false;
                                return;
                            }
                            pressRow = r;
                            moved = false;
                            win.dragging = true;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const r = win.rowAt(mouse.y);
                            if (r !== pressRow || win.rawMode) {
                                moved = true;
                                win.dragSelect(pressRow, r);
                            }
                        }
                        onReleased: mouse => {
                            win.dragging = false;
                            if (moved)
                                return;
                            const it = rep.itemAt(pressRow);
                            const link = it ? it.linkAtPoint(mouse.x, mouse.y) : "";
                            if (link !== "")
                                Qt.openUrlExternally(link);
                            else
                                win.gotoLine(pressRow, -1);
                        }
                        onCanceled: win.dragging = false
                    }
                }
            }

            RowLayout {
                visible: !win.listing
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: win.stats
                    font.pixelSize: Theme.labelMedium
                    color: Theme.textFaint
                }

                StyledText {
                    text: "Saved in the vault · Esc to close"
                    font.pixelSize: Theme.labelMedium
                    color: Theme.textFaint
                }
            }

            // ── List ──────────────────────────────────────────────────────────────────────
            StyledTextField {
                id: search

                visible: win.listing
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Search notes…"
                onAccepted: if (win.cards.length > 0)
                    win.pick(win.cards[win.query === "" ? 0 : Math.min(1, win.cards.length - 1)])
            }

            GridView {
                id: grid

                visible: win.listing
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property int columns: 3
                cellWidth: Math.floor(width / columns)
                cellHeight: 150
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.cards

                delegate: Item {
                    id: cell

                    required property var modelData

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: Theme.shapeLarge - 4
                        color: cell.modelData.isNew ? Theme.primaryContainer : area.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: cell.modelData.path === Notes.path ? Theme.primary : "transparent"

                        Behavior on color {
                            ColorAnim {}
                        }

                        ColumnLayout {
                            visible: cell.modelData.isNew === true
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "add"
                                size: 28
                                color: Theme.onPrimaryContainer
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: "New note"
                                color: Theme.onPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            visible: cell.modelData.isNew !== true
                            anchors.fill: parent
                            anchors.margins: Theme.space3
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: cell.modelData.title ?? ""
                                elide: Text.ElideRight
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: cell.modelData.preview ?? ""
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 4
                                font.pixelSize: Theme.labelMedium
                                color: Theme.textDim
                            }
                            StyledText {
                                text: cell.modelData.mtime ? Qt.formatDateTime(new Date(cell.modelData.mtime * 1000), "d MMM, HH:mm") : ""
                                font.pixelSize: Theme.labelSmall
                                color: Theme.textFaint
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.pick(cell.modelData)
                        }
                    }
                }
            }
        }
    }
}
