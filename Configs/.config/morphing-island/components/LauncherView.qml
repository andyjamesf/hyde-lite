import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config as Config
import qs.core
import qs.services
import qs.theme
import qs.icons

// The island's launcher (mode "launcher"): a search field on top and the result list below.
// The prefix picks the mode (config/Launcher.qml `prefixes`): "=" calculator, ":" clipboard,
// "?" keybindings, no prefix = apps. With a picker active (LauncherState.provider, see
// services/Pickers.qml) there are no prefixes and no Tab, and the results come from the picker
// (windows, files, web, emoji…), as a list or, with `grid: true`, as a grid of tiles with the
// selected tile's name in a footer.
// The list is never rebuilt: on every search the ListModel is synced by differences (rows are
// removed, inserted and moved by key), so rows enter, leave and swap places animated.
// The island grows and shrinks with the number of rows (the spring handles the animation).
// Keyboard: ↑/↓ select · Enter open/copy/paste · Tab switches mode · Ctrl+F favourite ·
// Delete removes a clipboard entry · Esc closes. In picker grids, ←/→ select too.
// Sizes, caps and the debounce are in config/Launcher.qml.
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through the ModeSlot).
    property bool open: false

    readonly property var cfg: Config.Launcher
    readonly property real islandRadius: cfg.radius
    readonly property int rowHeight: cfg.rowHeight
    readonly property int maxRows: cfg.maxRows
    readonly property int searchHeight: Config.Pill.height + 12
    readonly property int pad: 8
    readonly property int sidePad: 20
    // Grid for pickers with `grid: true` (emoji, glyphs…): square tiles.
    readonly property int tileSize: cfg.tileSize
    readonly property int maxGridRows: cfg.maxGridRows
    readonly property int footerHeight: cfg.footer
    // Nerd Font family (the rows' `glyph` field and the picker header glyph).
    readonly property string nerdFont: Config.Appearance.nerdFont
    readonly property string font: Config.Appearance.font
    readonly property int fontSize: Config.Appearance.fontSize
    // Kinds LauncherGlyph draws; any other value in a picker's `glyph` is a character.
    readonly property var glyphKinds: leadGlyph.kinds

    // Search text (the source of truth is LauncherState, so IPC can write it).
    readonly property string query: LauncherState.query

    // Picker on screen ("" = normal launcher). A copy of LauncherState.provider taken on opening:
    // on close LauncherState is cleared right away, but this view, while fading out, keeps showing
    // the picker instead of jumping to the apps.
    property string providerName: ""
    readonly property var provider: Pickers.get(providerName)
    readonly property bool picking: provider !== null
    readonly property bool gridMode: picking && provider.grid === true
    readonly property string pickGlyph: picking ? String(provider.glyph ?? "") : ""
    readonly property bool pickGlyphIsKind: glyphKinds.includes(pickGlyph)
    readonly property string pickTextFont: picking ? String(provider.textFont ?? "") : ""
    // Picker search, slightly delayed (Launcher.pickerDebounceMs): some pickers scan tens of
    // thousands of entries and searching on every keystroke is not worth it.
    property string pickTerm: ""

    // Mode prefixes (config/Launcher.qml), by mode.
    readonly property var prefixes: ({
            "apps": "",
            "calc": cfg.prefixes.calc ?? "=",
            "clipboard": cfg.prefixes.clipboard ?? ":",
            "keys": cfg.prefixes.keys ?? "?"
        })
    readonly property string kind: picking ? "pick" : query.startsWith(prefixes.calc) ? "calc" : query.startsWith(prefixes.clipboard) ? "clipboard" : query.startsWith(prefixes.keys) ? "keys" : "apps"
    // Text without the mode prefix.
    readonly property string term: kind === "apps" || kind === "pick" ? query : query.slice(prefixes[kind].length)

    readonly property var calcValue: kind === "calc" && term.trim() !== "" ? Calculator.evaluate(term) : null
    readonly property bool hasCalc: typeof calcValue === "number" && isFinite(calcValue)

    // Results of the current search: { items: [rows in order], map: { key → entry } }.
    // Being a binding, it reruns on its own when the services change (apps loaded, favourites,
    // clipboard history) and the list syncs with animation.
    readonly property var results: compute(kind, kind === "pick" ? pickTerm : term, provider)

    // Selected row and a mirror of the ListModel keys (avoids walking the model with get()).
    property int current: 0
    property var keys: []
    property int revision: 0
    property string syncedQuery: ""

    readonly property int visibleRows: Math.min(listModel.count, maxRows)
    readonly property int gridColumns: Math.max(1, Math.floor((implicitWidth - 2 * pad) / tileSize))
    readonly property int gridRows: Math.ceil(listModel.count / gridColumns)
    readonly property int visibleGridRows: Math.min(gridRows, maxGridRows)
    readonly property string emptyText: {
        if (kind === "pick")
            return provider.loading ? "Loading…" : term.trim() !== "" ? "No results" : String(provider.emptyText ?? "");
        if (kind === "keys" && Keybinds.loading)
            return "Loading…";
        if (kind === "clipboard")
            return Clipboard.loading ? "Loading…" : (Clipboard.entries ?? []).length === 0 ? "Clipboard is empty" : "No matches";
        return term.trim() !== "" ? "No results" : "";
    }
    readonly property int bodyHeight: kind === "calc" ? cfg.calcBody : gridMode && visibleGridRows > 0 ? visibleGridRows * tileSize + footerHeight : visibleRows > 0 ? visibleRows * rowHeight : emptyText !== "" ? cfg.emptyBody : 0

    // Selected row (grid footer); `revision` rereads it when the model changes.
    readonly property var currentRow: revision >= 0 && current >= 0 && current < listModel.count ? listModel.get(current) : null

    // Summary for IPC: "<mode> <result count> <selected title>".
    readonly property string status: {
        if (revision < 0)
            return "";
        const n = kind === "calc" ? (hasCalc ? 1 : 0) : listModel.count;
        let sel = "";
        if (kind === "calc")
            sel = hasCalc ? "= " + Calculator.format(calcValue) : "";
        else if (current >= 0 && current < listModel.count)
            sel = listModel.get(current).title;
        return `${picking ? "pick:" + providerName : kind} ${n} ${sel}`.trim();
    }

    focus: true
    implicitWidth: cfg.width
    implicitHeight: searchHeight + (bodyHeight > 0 ? bodyHeight + pad : 0)

    onOpenChanged: if (open)
        reset()
    Component.onCompleted: {
        if (open)
            reset();
        apply();
    }
    onResultsChanged: apply()
    onQueryChanged: {
        if (input.text !== query) {
            input.text = query;
            input.cursorPosition = input.text.length;
        }
        if (picking) {
            if (query === "") {
                pickDebounce.stop();
                pickTerm = "";
            } else {
                pickDebounce.restart();
            }
        }
    }
    onKindChanged: {
        if (open && kind === "keys")
            Keybinds.refresh();
        if (open && kind === "clipboard")
            Clipboard.refresh();
    }
    onCurrentChanged: {
        if (current < 0 || current >= listModel.count)
            return;
        if (gridMode)
            grid.positionViewAtIndex(current, GridView.Contain);
        else
            list.positionViewAtIndex(current, ListView.Contain);
    }

    // A picker chosen while the launcher is already open (IPC `pick`) restarts the view. When
    // LauncherState is cleared (the launcher closed) the view stays as it is until it disappears.
    Connections {
        target: LauncherState
        function onProviderChanged() {
            if (root.open && LauncherState.provider !== "" && LauncherState.provider !== root.providerName)
                root.reset();
        }
    }

    Binding {
        target: LauncherState
        property: "status"
        value: root.status
        when: root.open
    }

    // Every opening starts from scratch: empty search, first row, focus in the field.
    function reset() {
        // Picker requested over IPC (`pick`); an unknown name opens the normal launcher.
        providerName = Pickers.get(LauncherState.provider) !== null ? LauncherState.provider : "";
        pickDebounce.stop();
        pickTerm = "";
        if (provider)
            provider.refresh();
        LauncherState.query = "";
        input.text = "";
        current = 0;
        // The next list counts as a new search (back to the first row), even when the empty text
        // equals last time's.
        syncedQuery = "\u0000";
        mouseGuard.reset();
        list.positionViewAtBeginning();
        grid.positionViewAtBeginning();
        // The window's (exclusive) keyboard focus only arrives a moment later: FocusRetry insists once.
        focusRetry.start();
    }

    function setQuery(q) {
        input.text = q;
        input.cursorPosition = q.length;
        input.forceActiveFocus();
    }

    // Tab: walks Launcher.cycleOrder (apps → clipboard → calculator → keys), keeping the typed text.
    function cycle(step) {
        // In pickers Tab does nothing (there are no other modes).
        if (picking)
            return;
        const order = (cfg.cycleOrder ?? []).filter(k => prefixes[k] !== undefined);
        if (order.length === 0)
            return;
        const at = order.indexOf(kind);
        // A mode missing from the order: Tab goes to the first one (Shift+Tab to the last).
        const next = at < 0 ? order[step > 0 ? 0 : order.length - 1] : order[(at + step + order.length) % order.length];
        setQuery(prefixes[next] + term);
    }

    function clipRow(e) {
        const text = String(e.text ?? "");
        if (e.image)
            return {
                "key": "",
                "type": "clip",
                "title": "Image",
                "subtitle": text.trim().slice(0, cfg.clipSubtitleChars),
                "icon": "",
                "image": true,
                "text": "",
                "glyph": "",
                "badge": ""
            };
        const lines = text.split("\n");
        const first = (lines.find(l => l.trim() !== "") ?? "").trim().replace(/\s+/g, " ").slice(0, cfg.clipTitleChars);
        return {
            "key": "",
            "type": "clip",
            "title": first,
            "subtitle": lines.length > 1 ? `${lines.length} lines` : "",
            "icon": "",
            "image": false,
            "text": "",
            "glyph": "",
            "badge": ""
        };
    }

    // A picker icon: freedesktop name (looked up in the icon theme), absolute path or URL.
    function iconSource(name) {
        const s = String(name ?? "");
        if (s === "")
            return "";
        if (s.startsWith("/"))
            return "file://" + s;
        if (/^[a-z]+:/.test(s))
            return s;
        return Quickshell.iconPath(s, true) ?? "";
    }

    function compute(k, t, p) {
        const items = [];
        const map = {};
        const add = (key, entry, row) => {
            // Repeated keys would break the sync: the first one wins.
            if (map[key] !== undefined)
                return;
            map[key] = entry;
            row.key = key;
            items.push(row);
        };
        if (k === "apps") {
            const found = Apps.search(t.trim()) ?? [];
            for (let i = 0; i < found.length; ++i) {
                const e = found[i];
                add("a:" + Apps.keyOf(e), e, {
                    "key": "",
                    "type": "app",
                    "title": e.name ?? "",
                    "subtitle": e.genericName || e.comment || "",
                    "icon": Apps.iconOf(e) ?? "",
                    "image": false,
                    "text": "",
                    "glyph": "",
                    "badge": ""
                });
            }
        } else if (k === "keys") {
            // One binding per action; alternative combos go together, separated by "|", and each
            // combo's keys by the invisible separator \u001f ("Volume +" already has a "+").
            const found = Keybinds.search(t) ?? [];
            for (let i = 0; i < found.length; ++i) {
                const e = found[i];
                add("k:" + e.category + "|" + e.title, e, {
                    "key": "",
                    "type": "key",
                    "title": e.title,
                    "subtitle": e.category,
                    "icon": e.combos.map(c => c.join("\u001f")).join("|"),
                    "image": false,
                    "text": "",
                    "glyph": "",
                    "badge": ""
                });
            }
        } else if (k === "pick" && p) {
            // The call stays inside the binding: whatever the picker reads (lists loading,
            // windows…) reruns the search on its own.
            const found = p.items(t) ?? [];
            for (let i = 0; i < found.length && items.length < cfg.maxPickerResults; ++i) {
                const e = found[i];
                if (!e || e.key === undefined || e.key === null || e.key === "")
                    continue;
                add("p:" + e.key, e, {
                    "key": "",
                    "type": "pick",
                    "title": String(e.title ?? ""),
                    "subtitle": String(e.subtitle ?? ""),
                    "icon": iconSource(e.icon),
                    "image": false,
                    "text": String(e.text ?? ""),
                    "glyph": String(e.glyph ?? ""),
                    "badge": String(e.badge ?? "")
                });
            }
        } else if (k === "clipboard") {
            const q = t.trim().toLowerCase();
            const entries = Clipboard.entries ?? [];
            for (let i = 0; i < entries.length && items.length < cfg.maxClipboardResults; ++i) {
                const e = entries[i];
                if (q !== "" && !String(e.text ?? "").toLowerCase().includes(q))
                    continue;
                add("c:" + e.id, e, clipRow(e));
            }
        }
        return {
            "items": items,
            "map": map
        };
    }

    // Brings the ListModel to `items` with the fewest changes: removes the rows that disappeared
    // (bottom up), then, position by position, inserts the new ones and moves the ones that
    // changed place. Rows that stay are only rewritten when their data changed.
    function sync(items) {
        const wanted = new Set(items.map(it => it.key));
        for (let i = keys.length - 1; i >= 0; --i) {
            if (!wanted.has(keys[i])) {
                listModel.remove(i);
                keys.splice(i, 1);
            }
        }
        for (let i = 0; i < items.length; ++i) {
            const it = items[i];
            const j = keys.indexOf(it.key, i);
            if (j < 0) {
                listModel.insert(i, it);
                keys.splice(i, 0, it.key);
                continue;
            }
            if (j !== i) {
                listModel.move(j, i, 1);
                keys.splice(j, 1);
                keys.splice(i, 0, it.key);
            }
            const old = listModel.get(i);
            if (old.title !== it.title || old.subtitle !== it.subtitle || old.icon !== it.icon || old.image !== it.image || old.text !== it.text || old.glyph !== it.glyph || old.badge !== it.badge)
                listModel.set(i, it);
        }
        revision++;
    }

    function apply() {
        const prevKey = keys[current] ?? "";
        sync(results.items);
        if (query !== syncedQuery) {
            // Typed: back to the first row.
            syncedQuery = query;
            userPicked = false;
            current = 0;
            list.positionViewAtBeginning();
            grid.positionViewAtBeginning();
        } else {
            // Only the list changed (favourite, deleted entry, data loading…): if the selection was
            // moved, keep the same row; otherwise stay on the first.
            const i = keys.indexOf(prevKey);
            current = !userPicked ? 0 : i >= 0 ? i : Math.max(0, Math.min(current, keys.length - 1));
        }
    }

    // The user picked the selection (arrows or mouse) since the last search.
    property bool userPicked: false

    function step(delta) {
        userPicked = true;
        const n = listModel.count;
        if (n > 0)
            current = (current + delta + n) % n;
    }

    // Grid: ↑/↓ jump one row and ←/→ one tile, without wrapping.
    function stepGrid(delta) {
        userPicked = true;
        const n = listModel.count;
        if (n > 0)
            current = Math.max(0, Math.min(n - 1, current + delta));
    }

    function entryAt(i) {
        const key = keys[i];
        return key === undefined ? undefined : results.map[key];
    }

    function activate(i) {
        if (kind === "calc") {
            if (!hasCalc)
                return;
            Quickshell.clipboardText = Calculator.format(calcValue);
            IslandController.close();
            return;
        }
        const e = entryAt(i);
        if (e === undefined)
            return;
        if (kind === "pick") {
            // Keep the picker and close first (focus returns to the previous window; closing clears
            // LauncherState.provider), then the picker acts.
            const p = provider;
            if (p.keepOpen !== true)
                IslandController.close();
            p.activate(e);
        } else if (kind === "apps") {
            Apps.launch(e);
            IslandController.close();
        } else if (kind === "keys") {
            // The binding runs after the island closes (it acts on the window that had focus).
            IslandController.close();
            Keybinds.run(e);
        } else {
            // Close first (focus goes back to the target window), then paste.
            IslandController.close();
            Clipboard.paste(e);
        }
    }

    // The mouse only counts (selection and highlight) after it really moves with the launcher
    // open: opening under the cursor, the island reshaping under a still cursor or the list
    // changing while typing must not select anything (core/MouseGuard.qml).
    readonly property bool mouseActive: mouseGuard.active

    MouseGuard {
        id: mouseGuard
    }

    FocusRetry {
        id: focusRetry
        target: input
        when: root.open
    }

    function duration(ms) {
        return Config.Animations.duration(ms);
    }

    ListModel {
        id: listModel
    }

    Timer {
        id: pickDebounce
        interval: Math.max(0, root.cfg.pickerDebounceMs)
        onTriggered: root.pickTerm = root.query
    }

    // Beneath everything: swallows clicks outside the rows (they never reach the island's "empty
    // area") and gives focus back to the field.
    MouseArea {
        anchors.fill: parent
        onPressed: input.forceActiveFocus()
    }

    // Search row
    Item {
        id: searchRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.searchHeight

        Item {
            id: lead
            anchors.left: parent.left
            anchors.leftMargin: root.sidePad
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22

            SearchIcon {
                anchors.centerIn: parent
                visible: root.kind === "apps"
                size: 18
                color: Theme.dim
            }

            // Pickers with a Nerd Font glyph in the header.
            Label {
                anchors.centerIn: parent
                visible: root.picking && root.pickGlyph !== "" && !root.pickGlyphIsKind
                text: root.pickGlyph
                textFormat: Text.PlainText
                elide: Text.ElideNone
                color: Theme.accent
                font.family: root.nerdFont
                font.pixelSize: 19
            }

            LauncherGlyph {
                id: leadGlyph
                anchors.centerIn: parent
                visible: root.kind !== "apps" && !(root.picking && root.pickGlyph !== "" && !root.pickGlyphIsKind)
                kind: root.picking ? (root.pickGlyphIsKind ? root.pickGlyph : "picker") : root.kind === "calc" ? "calc" : root.kind === "keys" ? "keys" : "clipboard"
                size: 20
                color: Theme.accent
            }
        }

        TextInput {
            id: input
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.right: hint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            clip: true
            selectByMouse: true
            color: Theme.foreground
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentContent
            font.family: root.font
            font.pixelSize: root.fontSize + 3
            renderType: Text.NativeRendering

            onTextChanged: {
                if (root.open && LauncherState.query !== text)
                    LauncherState.query = text;
            }

            Keys.onEscapePressed: event => {
                event.accepted = true;
                IslandController.back();
            }
            Keys.onUpPressed: root.gridMode ? root.stepGrid(-root.gridColumns) : root.step(-1)
            Keys.onDownPressed: root.gridMode ? root.stepGrid(root.gridColumns) : root.step(1)
            Keys.onReturnPressed: root.activateNow()
            Keys.onEnterPressed: root.activateNow()
            Keys.onTabPressed: root.cycle(1)
            Keys.onBacktabPressed: root.cycle(-1)
            Keys.onPressed: event => {
                const page = root.gridMode ? root.gridColumns * root.maxGridRows : root.maxRows;
                if (event.key === Qt.Key_PageDown) {
                    root.current = Math.min(listModel.count - 1, root.current + page);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.current = Math.max(0, root.current - page);
                    event.accepted = true;
                } else if (root.gridMode && (event.key === Qt.Key_Left || event.key === Qt.Key_Right) && !(event.modifiers & Qt.ShiftModifier)) {
                    root.stepGrid(event.key === Qt.Key_Left ? -1 : 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier) && root.kind === "apps") {
                    const e = root.entryAt(root.current);
                    if (e !== undefined)
                        Apps.toggleFavorite(e);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete && root.kind === "clipboard" && input.cursorPosition === input.text.length) {
                    // With the cursor at the end Delete would remove nothing from the text: it removes the entry.
                    const e = root.entryAt(root.current);
                    if (e !== undefined) {
                        Clipboard.remove(e);
                        event.accepted = true;
                    }
                }
            }

            Label {
                anchors.fill: parent
                visible: input.text === ""
                text: root.picking ? String(root.provider.placeholder || "Search…") : "Search apps…"
                color: Theme.faint
                font.pixelSize: input.font.pixelSize
            }
        }

        // On the right: prefix hints (empty field) or the mode's name.
        Label {
            id: hint
            anchors.right: parent.right
            // Sized by its text: no eliding (a Text eliding at its implicit width loops on "width").
            elide: Text.ElideNone
            anchors.rightMargin: root.sidePad
            anchors.verticalCenter: parent.verticalCenter
            text: root.picking ? String(root.provider.title ?? "") : root.kind === "calc" ? "Calculator" : root.kind === "clipboard" ? "Clipboard" : root.kind === "keys" ? "Keybindings" : input.text === "" ? `${root.prefixes.calc}  calculate    ${root.prefixes.clipboard}  clipboard    ${root.prefixes.keys}  keys` : ""
            color: root.kind === "apps" ? Theme.faint : Theme.dim
            font.pixelSize: root.fontSize - 2
        }
    }

    // Separator between the search and the results.
    Rectangle {
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.sidePad
        anchors.rightMargin: root.sidePad
        height: 1
        color: Theme.border
        opacity: root.bodyHeight > 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.duration(150)
            }
        }
    }

    // Calculator: big result, the expression faded above it.
    Item {
        id: calcArea
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.cfg.calcBody
        visible: root.kind === "calc"

        Column {
            anchors.left: parent.left
            anchors.leftMargin: root.sidePad
            anchors.right: calcHint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Label {
                width: parent.width
                text: root.term.trim() !== "" ? root.term.trim() : "Type an expression, e.g. (2+3)*4^2"
                textFormat: Text.PlainText
                color: Theme.dim
            }

            Label {
                width: parent.width
                text: root.hasCalc ? "= " + Calculator.format(root.calcValue) : root.term.trim() !== "" ? "…" : ""
                textFormat: Text.PlainText
                color: root.hasCalc ? Theme.foreground : Theme.faint
                font.pixelSize: 28
                font.weight: Font.Light
            }
        }

        Label {
            id: calcHint
            anchors.right: parent.right
            elide: Text.ElideNone
            anchors.rightMargin: root.sidePad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            opacity: root.hasCalc ? 1 : 0
            text: "Enter copies"
            color: Theme.faint
            font.pixelSize: root.fontSize - 2

            Behavior on opacity {
                NumberAnimation {
                    duration: root.duration(150)
                }
            }
        }
    }

    // No results
    Label {
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.cfg.emptyBody
        visible: root.kind !== "calc" && listModel.count === 0 && root.emptyText !== ""
        horizontalAlignment: Text.AlignHCenter
        text: root.emptyText
        color: Theme.faint
    }

    // Results (apps, clipboard, keybindings and list pickers)
    ListView {
        id: list
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        height: root.visibleRows * root.rowHeight
        visible: root.kind !== "calc" && !root.gridMode
        clip: true
        // In grid mode the model moves to the GridView (the two never create delegates at once).
        model: root.gridMode ? null : listModel
        // The selection is ours (root.current); the ListView never scrolls on its own.
        currentIndex: -1
        interactive: listModel.count > root.maxRows
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.duration(200)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "slide"
                from: 10
                to: 0
                duration: root.duration(240)
                easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: root.duration(140)
                easing.type: Easing.OutCubic
            }
        }
        move: Transition {
            NumberAnimation {
                property: "y"
                duration: root.duration(180)
                easing.type: Easing.OutCubic
            }
            // If an entry animation was interrupted halfway, finish it here.
            NumberAnimation {
                properties: "opacity"
                to: 1
                duration: root.duration(120)
            }
            NumberAnimation {
                property: "slide"
                to: 0
                duration: root.duration(120)
            }
        }
        // Used for addDisplaced, removeDisplaced and moveDisplaced (those not defined separately
        // fall back to this one).
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: root.duration(180)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                properties: "opacity"
                to: 1
                duration: root.duration(120)
            }
            NumberAnimation {
                property: "slide"
                to: 0
                duration: root.duration(120)
            }
        }

        delegate: Item {
            id: row

            required property int index
            required property string key
            required property string type
            required property string title
            required property string subtitle
            required property string icon
            required property bool image
            required property string text
            required property string glyph
            required property string badge

            readonly property bool selected: index === root.current
            readonly property var entry: root.results.map[key]
            readonly property bool favorite: type === "app" && entry !== undefined && Apps.isFavorite(entry)
            // Pickers: what takes the icon's place (big text > Nerd Font glyph > icon).
            readonly property string bigText: type === "pick" ? (text !== "" ? text : glyph) : ""
            readonly property bool hasIcon: (type === "app" || type === "pick") && appIcon.status === Image.Ready
            // Vertical offset of the entry (animated by the `add` transition).
            property real slide: 0

            width: ListView.view.width
            height: root.rowHeight

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (mouseGuard.moved(rowMouse, mouse.x, mouse.y)) {
                        root.userPicked = true;
                        root.current = row.index;
                    }
                }
                onClicked: root.activate(row.index)
            }

            Item {
                anchors.fill: parent
                transform: Translate {
                    y: row.slide
                }

                // Background of the selected row, beneath the icon and the text.
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 14
                    color: row.selected ? Qt.alpha(Theme.accent, 0.18) : rowMouse.containsMouse && root.mouseActive ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: root.duration(120)
                        }
                    }
                }

                // App icon (or its initial when there is none), or the clipboard glyph.
                Item {
                    id: rowLead
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32

                    IconImage {
                        id: appIcon
                        anchors.fill: parent
                        visible: row.hasIcon && row.bigText === ""
                        source: row.type === "app" || (row.type === "pick" && row.bigText === "") ? row.icon : ""
                        asynchronous: true
                        mipmap: true
                    }

                    // Pickers: emoji, glyph or big character instead of the icon.
                    Label {
                        anchors.fill: parent
                        visible: row.bigText !== ""
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideNone
                        text: row.bigText
                        textFormat: Text.PlainText
                        color: row.selected ? Theme.accent : Theme.foreground
                        font.family: row.text !== "" ? (root.pickTextFont || root.font) : root.nerdFont
                        font.pixelSize: 22
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: (row.type === "app" && !row.hasIcon) || (row.type === "pick" && row.bigText === "" && !row.hasIcon && !root.pickGlyphIsKind)
                        radius: 9
                        color: Qt.alpha(Theme.accent, 0.18)

                        Label {
                            anchors.centerIn: parent
                            text: row.title.charAt(0).toUpperCase()
                            color: Theme.accent
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }

                    LauncherGlyph {
                        anchors.centerIn: parent
                        visible: row.type === "clip" || row.type === "key" || (row.type === "pick" && row.bigText === "" && !row.hasIcon && root.pickGlyphIsKind)
                        kind: row.type === "pick" ? root.pickGlyph : row.type === "key" ? "keys" : row.image ? "image" : "clipboard"
                        size: 22
                        color: row.selected ? Theme.accent : Theme.dim
                    }
                }

                // Keybindings: keys as chips, alternatives separated by "or".
                Row {
                    id: keyChips
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.type === "key"
                    spacing: 6

                    Repeater {
                        model: row.type === "key" ? row.icon.split("|") : []

                        Row {
                            id: combo

                            required property string modelData
                            required property int index

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Label {
                                visible: combo.index > 0
                                anchors.verticalCenter: parent.verticalCenter
                                rightPadding: 2
                                text: "or"
                                elide: Text.ElideNone
                                color: Theme.faint
                                font.pixelSize: root.fontSize - 2
                            }

                            Repeater {
                                model: combo.modelData.split("\u001f")

                                Rectangle {
                                    id: keyCap

                                    required property string modelData

                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: Math.max(implicitHeight, keyLabel.implicitWidth + 14)
                                    implicitHeight: 22
                                    radius: 7
                                    color: row.selected ? Qt.alpha(Theme.accent, 0.22) : Qt.alpha(Theme.foreground, 0.08)

                                    Label {
                                        id: keyLabel
                                        anchors.centerIn: parent
                                        text: keyCap.modelData
                                        elide: Text.ElideNone
                                        font.pixelSize: root.fontSize - 2
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }

                // Pickers: small text on the right (e.g. "Current"). Sized by its text, so no
                // eliding: a Text eliding at its own implicit width loops on "width".
                Label {
                    id: badgeLabel
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.type === "pick" && row.badge !== ""
                    elide: Text.ElideNone
                    text: row.badge
                    textFormat: Text.PlainText
                    color: row.selected ? Theme.dim : Theme.faint
                    font.pixelSize: root.fontSize - 2
                }

                Column {
                    anchors.left: rowLead.right
                    anchors.leftMargin: 12
                    anchors.right: row.type === "key" ? keyChips.left : row.type === "pick" ? badgeLabel.left : star.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Label {
                        width: parent.width
                        text: row.title
                        textFormat: Text.PlainText
                        font.pixelSize: root.fontSize + 1
                        font.weight: row.selected ? Font.Medium : Font.Normal
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: row.subtitle
                        textFormat: Text.PlainText
                        color: Theme.dim
                        font.pixelSize: root.fontSize - 2
                    }
                }

                // Favourite: filled star if it is one; outline on the selected or hovered row.
                Item {
                    id: star
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    opacity: row.type === "app" && (row.favorite || row.selected || (root.mouseActive && (rowMouse.containsMouse || starMouse.containsMouse))) ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.duration(120)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: starMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    LauncherGlyph {
                        anchors.centerIn: parent
                        kind: row.favorite ? "star" : "starOutline"
                        size: 16
                        color: row.favorite ? Theme.accent : Theme.faint
                    }

                    MouseArea {
                        id: starMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (row.entry !== undefined)
                                Apps.toggleFavorite(row.entry);
                            input.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // Enter: if the picker's delayed search has not run yet, run it now (so the result of the
    // previous search is never opened).
    function activateNow() {
        if (picking && pickTerm !== query) {
            pickDebounce.stop();
            pickTerm = query;
        }
        activate(current);
    }

    // Grid pickers (grid: true): square tiles with the big glyph. Uses the same ListModel synced by
    // differences, so tiles also enter, leave and change place animated.
    GridView {
        id: grid
        anchors.top: searchRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        height: root.visibleGridRows * root.tileSize
        visible: root.gridMode
        clip: true
        model: root.gridMode ? listModel : null
        cellWidth: Math.floor(width / root.gridColumns)
        cellHeight: root.tileSize
        currentIndex: -1
        interactive: root.gridRows > root.maxGridRows
        boundsBehavior: Flickable.StopAtBounds

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.duration(200)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.8
                to: 1
                duration: root.duration(220)
                easing.type: Easing.OutCubic
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: root.duration(140)
                easing.type: Easing.OutCubic
            }
        }
        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.duration(180)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: root.duration(120)
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: root.duration(180)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                properties: "opacity,scale"
                to: 1
                duration: root.duration(120)
            }
        }

        delegate: Item {
            id: tile

            required property int index
            required property string title
            required property string icon
            required property string text
            required property string glyph

            readonly property bool selected: index === root.current
            readonly property string bigText: text !== "" ? text : glyph

            width: GridView.view.cellWidth
            height: GridView.view.cellHeight

            MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => {
                    if (mouseGuard.moved(tileMouse, mouse.x, mouse.y)) {
                        root.userPicked = true;
                        root.current = tile.index;
                    }
                }
                onClicked: root.activate(tile.index)
            }

            Rectangle {
                anchors.centerIn: parent
                width: root.tileSize - 4
                height: root.tileSize - 4
                radius: 14
                color: tile.selected ? Qt.alpha(Theme.accent, 0.18) : tileMouse.containsMouse && root.mouseActive ? Theme.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: root.duration(120)
                    }
                }

                Label {
                    anchors.fill: parent
                    visible: tile.bigText !== ""
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideNone
                    text: tile.bigText
                    textFormat: Text.PlainText
                    color: tile.selected ? Theme.accent : Theme.foreground
                    font.family: tile.text !== "" ? (root.pickTextFont || root.font) : root.nerdFont
                    font.pixelSize: 26
                }

                IconImage {
                    id: tileIcon
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    visible: tile.bigText === "" && status === Image.Ready
                    source: tile.bigText === "" ? tile.icon : ""
                    asynchronous: true
                    mipmap: true
                }

                Label {
                    anchors.centerIn: parent
                    visible: tile.bigText === "" && tileIcon.status !== Image.Ready
                    text: tile.title.charAt(0).toUpperCase()
                    color: Theme.accent
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // Grid footer: name (and description) of the selected tile.
    Item {
        anchors.top: grid.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.footerHeight
        visible: root.gridMode && listModel.count > 0

        Label {
            id: footerBadge
            anchors.right: parent.right
            elide: Text.ElideNone
            anchors.rightMargin: root.sidePad
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentRow ? root.currentRow.badge : ""
            textFormat: Text.PlainText
            color: Theme.faint
            font.pixelSize: root.fontSize - 2
        }

        // Natural width of the title, measured apart: binding a Text's width to its own
        // implicitWidth while it elides is a binding loop.
        TextMetrics {
            id: footerTitleMetrics
            font: footerTitle.font
            text: footerTitle.text
        }

        Label {
            id: footerTitle
            anchors.left: parent.left
            anchors.leftMargin: root.sidePad
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(Math.ceil(footerTitleMetrics.advanceWidth), footerBadge.x - root.sidePad - 12))
            text: root.currentRow ? root.currentRow.title : ""
            textFormat: Text.PlainText
            font.pixelSize: root.fontSize - 1
        }

        Label {
            anchors.left: footerTitle.right
            anchors.leftMargin: 10
            anchors.right: footerBadge.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentRow ? root.currentRow.subtitle : ""
            textFormat: Text.PlainText
            color: Theme.dim
            font.pixelSize: root.fontSize - 2
        }
    }
}
