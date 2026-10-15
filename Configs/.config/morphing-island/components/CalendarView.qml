import QtQuick
import qs.config
import qs.core
import qs.icons
import qs.services
import qs.theme

// Calendar (island mode "calendar"): the month, the chosen day's events and your calendars.
// A click on a day shows its events; ‹ › change month, the month name goes back to today.
// ☰ opens the calendars page: your calendars (click a colour dot to pick another colour, click a
// name to rename it, × removes) and adding one: an optional name, then type or paste an iCal/webcal
// link and press Enter, "Paste link" (straight from the clipboard) or "Add .ics file…". ← goes back
// to the month.
// Keyboard: ←/→ previous/next day, ↑/↓ a week, PageUp/PageDown a month, Esc closes (or goes back
// from the calendars page).
// Data: services/Calendar.qml; options: config/CalendarConfig.qml.
Item {
    id: root

    property bool open: false
    readonly property real islandRadius: 26
    readonly property int pad: 16
    readonly property var locale: Clock.qtLocale

    // The day whose events are listed, and the month shown.
    property date selected: new Date()
    property int year: selected.getFullYear()
    property int month: selected.getMonth()
    // Feedback under "Add a calendar" (red when something went wrong).
    property string message: ""
    property bool messageError: false
    // Calendar whose colour palette is open (-1: none).
    property int colorFor: -1
    // Calendar being renamed (-1: none).
    property int renameFor: -1
    // "month" (the month and the day's events), "calendars" (your calendars, adding new ones), "new"
    // (a new Google event) or "edit" (changing one).
    property string page: "month"

    Connections {
        target: Calendar
        function onEditRequestChanged() {
            const e = Calendar.editRequest;
            if (!e)
                return;
            Calendar.editRequest = null;
            root.select(e.start);
            root.editEvent(e);
        }
    }

    // Opens an event of a Google calendar for editing.
    function editEvent(e) {
        showPage("edit");
        eventForm.edit(e);
    }

    function showPage(p) {
        page = p;
        colorFor = -1;
        renameFor = -1;
        message = "";
        root.forceActiveFocus();
        if (p === "new")
            eventForm.reset(selected);
        if (p === "calendars")
            GoogleCalendar.refreshStatus();
    }

    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - (CalendarConfig.firstDayOfWeek % 7) + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; ++i)
            out.push(new Date(year, month, 1 - offset + i));
        return out;
    }
    readonly property var dayEvents: Calendar.eventsOn(selected).slice(0, CalendarConfig.maxEvents)

    focus: true
    implicitWidth: CalendarConfig.width
    // Tall pages (the full event form) scroll inside this height.
    readonly property int maxBodyHeight: 600
    implicitHeight: Math.min(column.implicitHeight, maxBodyHeight) + 2 * pad

    onOpenChanged: if (open)
        reset()
    Component.onCompleted: if (open)
        reset()

    function reset() {
        select(new Date());
        message = "";
        colorFor = -1;
        renameFor = -1;
        page = "month";
        input.text = "";
        nameInput.text = "";
        Calendar.refresh(false);
        focusRetry.start();
    }

    function select(d) {
        selected = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        year = selected.getFullYear();
        month = selected.getMonth();
    }

    function stepMonth(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    // Adds the pasted link; on success the field empties, otherwise the reason shows below it.
    function addFromInput() {
        const why = Calendar.addLink(input.text, nameInput.text);
        if (why === "")
            input.text = "";
        else {
            message = why;
            messageError = true;
        }
    }

    Connections {
        target: Calendar
        function onNotice(text, error) {
            root.message = text;
            root.messageError = error;
            // Added: the name was used, the field is ready for the next one.
            if (!error)
                nameInput.text = "";
        }
    }

    function timeOf(e) {
        return e.allDay ? "All day" : root.locale.toString(e.start, Clock.timeFormat);
    }

    FocusRetry {
        id: focusRetry
        target: root
        when: root.open
    }

    // Esc on the calendars or new-event page goes back to the month (on the month it closes the
    // island).
    Keys.onEscapePressed: event => {
        if (page !== "month")
            showPage("month");
        else
            event.accepted = false;
    }

    Keys.onPressed: event => {
        const k = event.key;
        const shift = k === Qt.Key_Left ? -1 : k === Qt.Key_Right ? 1 : k === Qt.Key_Up ? -7 : k === Qt.Key_Down ? 7 : 0;
        if (shift !== 0) {
            select(new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + shift));
            event.accepted = true;
        } else if (k === Qt.Key_PageUp || k === Qt.Key_PageDown) {
            select(new Date(selected.getFullYear(), selected.getMonth() + (k === Qt.Key_PageUp ? -1 : 1), 1));
            event.accepted = true;
        }
    }

    // Under everything: swallows clicks on empty space (they must not toggle the island's pin).
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    Flickable {
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.height - 2 * root.pad
        contentHeight: column.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: 12

            // Header. Month page: the month (click: back to today), ‹ › and ☰ (your calendars).
            // Calendars page: ← and the title.
            Item {
                width: parent.width
                height: 32

                Label {
                    visible: root.page === "month"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.locale.toString(new Date(root.year, root.month, 1), "MMMM yyyy")
                    font.pixelSize: Appearance.fontSize + 3
                    font.weight: Font.DemiBold

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.select(new Date())
                    }
                }

                Row {
                    visible: root.page === "month"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    IconButton {
                        size: 30
                        onClicked: root.stepMonth(-1)
                        Glyph {
                            kind: "back"
                            size: 16
                        }
                    }
                    IconButton {
                        size: 30
                        onClicked: root.stepMonth(1)
                        Glyph {
                            kind: "chevron"
                            size: 16
                        }
                    }
                    IconButton {
                        size: 30
                        onClicked: root.showPage("new")
                        Glyph {
                            kind: "plus"
                            size: 16
                        }
                    }
                    IconButton {
                        size: 30
                        onClicked: root.showPage("calendars")
                        Glyph {
                            kind: "menu"
                            size: 16
                        }
                    }
                }

                Row {
                    visible: root.page !== "month"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 30
                        onClicked: root.showPage("month")
                        Glyph {
                            kind: "back"
                            size: 16
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.page === "new" ? "New event" : root.page === "edit" ? "Edit event" : "Calendars"
                        font.pixelSize: Appearance.fontSize + 3
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Weekday names and the 6×7 day grid.
            Grid {
                id: grid
                visible: root.page === "month"
                width: parent.width
                columns: 7
                readonly property real cell: width / 7

                Repeater {
                    model: 7
                    Label {
                        required property int index
                        width: grid.cell
                        height: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: root.locale.dayName((CalendarConfig.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                        font.pixelSize: Appearance.fontSize - 2
                        color: Theme.dim
                    }
                }

                Repeater {
                    model: root.days

                    Item {
                        id: day

                        required property var modelData
                        readonly property bool inMonth: modelData.getMonth() === root.month
                        // Time.date changes at midnight: the binding re-evaluates then.
                        readonly property bool today: Time.date !== "" && Calendar.sameDay(modelData, new Date())
                        readonly property bool chosen: Calendar.sameDay(modelData, root.selected)
                        // Up to three dots, in the colours of that day's calendars.
                        readonly property var dots: {
                            const seen = [];
                            for (const e of Calendar.eventsOn(modelData)) {
                                if (!seen.includes(e.color))
                                    seen.push(e.color);
                                if (seen.length === 3)
                                    break;
                            }
                            return seen;
                        }

                        width: grid.cell
                        height: 38

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 3
                            width: 30
                            height: 30
                            radius: 15
                            color: day.today ? Theme.accent : dayMouse.containsMouse ? Theme.hover : "transparent"
                            border.width: day.chosen && !day.today ? 1.5 : 0
                            border.color: Theme.accent

                            Label {
                                anchors.centerIn: parent
                                text: day.modelData.getDate()
                                font.weight: day.today || day.chosen ? Font.DemiBold : Font.Normal
                                color: day.today ? Theme.accentContent : day.inMonth ? Theme.foreground : Theme.faint
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            spacing: 3
                            Repeater {
                                model: day.dots
                                Rectangle {
                                    required property var modelData
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: modelData || Theme.accent
                                }
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.select(day.modelData)
                        }
                    }
                }
            }

            // The chosen day's events.
            Column {
                visible: root.page === "month"
                width: parent.width
                spacing: 6

                Label {
                    text: Calendar.sameDay(root.selected, new Date()) ? "Today" : root.locale.toString(root.selected, Clock.longDateFormat)
                    font.pixelSize: Appearance.fontSize - 1
                    font.weight: Font.DemiBold
                    color: Theme.dim
                }

                Label {
                    visible: root.dayEvents.length === 0
                    text: Calendar.calendars.length === 0 ? "No calendars yet: add one with ☰" : Calendar.loading && Calendar.events.length === 0 ? "Loading…" : "No events"
                    color: Theme.faint
                }

                Repeater {
                    model: root.dayEvents

                    Item {
                        id: ev
                        required property var modelData
                        // From one of your Google calendars: a click edits it (or deletes it).
                        readonly property bool editable: Calendar.editable(modelData)
                        width: parent.width
                        height: evRow.implicitHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            radius: 8
                            color: evMouse.containsMouse ? Theme.hover : "transparent"
                        }

                        Row {
                            id: evRow
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4
                                height: 28
                                radius: 2
                                color: ev.modelData.color || Theme.accent
                            }

                            Column {
                                width: parent.width - 14
                                Label {
                                    width: parent.width
                                    text: ev.modelData.title
                                    font.weight: Font.Medium
                                }
                                Label {
                                    width: parent.width
                                    text: [root.timeOf(ev.modelData), ev.modelData.location, ev.modelData.calendar].filter(x => x).join("  ·  ")
                                    font.pixelSize: Appearance.fontSize - 2
                                    color: Theme.dim
                                }
                            }
                        }

                        MouseArea {
                            id: evMouse
                            anchors.fill: parent
                            enabled: ev.editable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editEvent(ev.modelData)
                        }
                    }
                }
            }

            // Calendars page: your calendars, colour (click the dot to change it), name, remove.
            Column {
                visible: root.page === "calendars"
                width: parent.width
                spacing: 4

                Label {
                    visible: Calendar.calendars.length === 0
                    text: "No calendars yet"
                    color: Theme.faint
                }

                Repeater {
                    model: Calendar.calendars

                    Column {
                        id: cal
                        required property var modelData
                        required property int index
                        readonly property string error: Calendar.errors.find(x => x.startsWith(modelData.name + ":")) ?? ""
                        readonly property bool picking: root.colorFor === index
                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 30

                            // The calendar's colour: a click opens the palette below.
                            Rectangle {
                                id: swatch
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: 8
                                color: cal.modelData.color || Theme.accent
                                border.width: swatchMouse.containsMouse || cal.picking ? 2 : 0
                                border.color: Theme.foreground

                                MouseArea {
                                    id: swatchMouse
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.colorFor = cal.picking ? -1 : cal.index
                                }
                            }

                            // The name: a click turns it into a field (Enter saves, Esc cancels).
                            Label {
                                visible: root.renameFor !== cal.index
                                anchors.left: swatch.right
                                anchors.leftMargin: 10
                                anchors.right: removeButton.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: cal.error !== "" ? `${cal.modelData.name}  ·  couldn't read it` : `${cal.modelData.name}  ·  ${cal.modelData.path ? "file" : "link"}`
                                color: cal.error !== "" ? Theme.danger : nameMouse.containsMouse ? Theme.accent : Theme.foreground

                                MouseArea {
                                    id: nameMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.IBeamCursor
                                    onClicked: {
                                        root.colorFor = -1;
                                        root.renameFor = cal.index;
                                        renameInput.text = cal.modelData.name;
                                        renameInput.selectAll();
                                        renameInput.forceActiveFocus();
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.renameFor === cal.index
                                anchors.left: swatch.right
                                anchors.leftMargin: 6
                                anchors.right: removeButton.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                height: 28
                                radius: 14
                                color: Theme.surface
                                border.width: 1.5
                                border.color: Theme.accent

                                TextInput {
                                    id: renameInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.foreground
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentContent
                                    font.family: Appearance.font
                                    font.pixelSize: Appearance.fontSize
                                    clip: true
                                    function save() {
                                        Calendar.rename(cal.index, text);
                                        root.renameFor = -1;
                                        root.forceActiveFocus();
                                    }
                                    Keys.onReturnPressed: save()
                                    Keys.onEnterPressed: save()
                                    Keys.onEscapePressed: {
                                        root.renameFor = -1;
                                        root.forceActiveFocus();
                                    }
                                }
                            }

                            IconButton {
                                id: removeButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                size: 26
                                onClicked: {
                                    root.colorFor = -1;
                                    Calendar.remove(cal.index);
                                }
                                Glyph {
                                    kind: "close"
                                    size: 14
                                }
                            }
                        }

                        // Palette (CalendarConfig.colors).
                        Flow {
                            visible: cal.picking
                            width: parent.width
                            leftPadding: 26
                            spacing: 8
                            bottomPadding: 4

                            Repeater {
                                model: CalendarConfig.colors

                                Rectangle {
                                    id: option
                                    required property string modelData
                                    readonly property bool chosen: modelData.toLowerCase() === String(cal.modelData.color).toLowerCase()
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: modelData
                                    border.width: chosen || optionMouse.containsMouse ? 2 : 0
                                    border.color: Theme.foreground

                                    MouseArea {
                                        id: optionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Calendar.setColor(cal.index, option.modelData);
                                            root.colorFor = -1;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Calendars page: adding one, an iCal link (typed, pasted into the field, or straight from
            // the clipboard with "Paste link") or a .ics file.
            Column {
                visible: root.page === "calendars"
                width: parent.width
                spacing: 8

                Label {
                    text: "Add a calendar"
                    font.pixelSize: Appearance.fontSize - 1
                    font.weight: Font.DemiBold
                    color: Theme.dim
                }

                // Name for the next calendar (optional; used by the link and the file).
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 18
                    color: Theme.surface
                    border.width: nameInput.activeFocus ? 1.5 : 1
                    border.color: nameInput.activeFocus ? Theme.accent : Theme.border

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentContent
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize
                        clip: true
                        KeyNavigation.tab: input
                        Keys.onReturnPressed: input.forceActiveFocus()
                        Keys.onEnterPressed: input.forceActiveFocus()

                        Label {
                            visible: nameInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Name (optional)"
                            color: Theme.faint
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 18
                    color: Theme.surface
                    border.width: input.activeFocus ? 1.5 : 1
                    border.color: input.activeFocus ? Theme.accent : Theme.border

                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentContent
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize
                        clip: true
                        Keys.onReturnPressed: root.addFromInput()
                        Keys.onEnterPressed: root.addFromInput()

                        Label {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "iCal link (https:// or webcal://), Enter adds it"
                            color: Theme.faint
                        }
                    }
                }

                Row {
                    spacing: 8

                    Repeater {
                        model: [
                            {
                                label: "Paste link",
                                run: () => Calendar.addFromClipboard(nameInput.text)
                            },
                            {
                                label: "Add .ics file…",
                                run: () => Calendar.addFile(nameInput.text)
                            }
                        ]

                        Rectangle {
                            id: button
                            required property var modelData
                            width: buttonLabel.implicitWidth + 28
                            height: 32
                            radius: 16
                            color: buttonMouse.pressed ? Theme.pressed : buttonMouse.containsMouse ? Theme.hover : Theme.surface
                            border.width: 1
                            border.color: Theme.border

                            Label {
                                id: buttonLabel
                                anchors.centerIn: parent
                                text: button.modelData.label
                            }

                            MouseArea {
                                id: buttonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.message = "";
                                    button.modelData.run();
                                }
                            }
                        }
                    }
                }

                Label {
                    visible: root.message !== ""
                    width: parent.width
                    text: root.message
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.fontSize - 2
                    color: root.messageError ? Theme.danger : Theme.dim
                }
            }

            // Calendars page: Google Calendar connection (to add events).
            GoogleSetup {
                visible: root.page === "calendars"
                width: parent.width
            }

            // New event page (Google Calendar).
            CalendarEventForm {
                id: eventForm
                visible: root.page === "new" || root.page === "edit"
                width: parent.width
                onDone: root.showPage("month")
            }
        }
    }
}
