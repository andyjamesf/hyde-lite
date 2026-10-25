pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config
import qs.shared.services

// Calendars and their events, for the calendar view (components/CalendarView.qml).
//
// The work is done by shared/scripts/ical_events.py: it reads the calendars listed in
// ~/.local/share/quickshell/calendars.json (links or local .ics files), expands recurring events and
// writes ~/.cache/quickshell/calendar.json, which this service watches. The HyDE Quickshell shell
// uses the same two files, so both shells show the same calendars.
//
// Adding a calendar: addLink(url, name) for iCal/webcal links, addFromClipboard(name) for the link in
// the clipboard, addFile(name) opens the system file chooser and copies the chosen .ics to
// ~/.local/share/quickshell/calendars/ (`name` optional: otherwise one is made up from the link or
// the file). rename(index, name), setColor(index, "#rrggbb") and remove(index) edit the list.
// Names are unique (colours and errors are matched by name): a repeated one gets a number.
Singleton {
    id: root

    readonly property string dataDir: `${Paths.dataHome}/quickshell`
    readonly property string configPath: `${dataDir}/calendars.json`
    readonly property string filesDir: `${dataDir}/calendars`

    // [{ name, url | path, color }]
    property var calendars: []
    // [{ title, location, allDay, start: Date, end: Date, calendar, color }], by start. The colour
    // comes from the calendar's entry, so changing it applies at once.
    readonly property var events: {
        const colors = {};
        for (const c of calendars)
            colors[c.name] = c.color;
        const hidden = _hidden.filter(h => Date.now() - h.at < 6 * 3600000);
        const read = calendars.length === 0 ? [] : _events.filter(e => !hidden.some(h => h.uid === e.uid && (h.original === "" || h.original === e.originalStart))).map(e => Object.assign({}, e, {
                    color: colors[e.calendar] || e.color
                }));
        // Events just created in Google Calendar (GoogleCalendar.add), until the calendars read
        // brings them (Google's iCal links can lag) or for 6 hours at most.
        const shown = _pending.filter(p => Date.now() - p.addedAt < 6 * 3600000 && !read.some(e => e.title === p.title && Math.abs(e.start - p.start) < 60000));
        return read.concat(shown).sort((a, b) => a.start - b.start);
    }
    property var _events: []
    property var _pending: []
    // Events just changed or deleted in Google Calendar, hidden until the links catch up (6 h at
    // most): [{ uid, original ("" = every occurrence), at }].
    property var _hidden: []
    // Result of an add that finishes later (the clipboard, the file chooser): what to tell the user.
    signal notice(string text, bool error)
    // "Name: reason" for calendars that could not be read last time.
    property var errors: []
    readonly property bool loading: fetcher.running
    property real lastRun: 0

    // Downloads the calendars again (at most every 2 minutes unless `force`).
    function refresh(force) {
        if (calendars.length === 0 || fetcher.running)
            return;
        if (!force && Date.now() - lastRun < 120000)
            return;
        lastRun = Date.now();
        fetcher.running = true;
    }

    // "2026-09-25" (all day) is a local date, not UTC midnight.
    function parseDate(s, allDay) {
        if (allDay) {
            const [y, m, d] = s.slice(0, 10).split("-").map(Number);
            return new Date(y, m - 1, d);
        }
        return new Date(s);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // Events touching a day (multi-day ones show on every day they cover).
    function eventsOn(day) {
        const start = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1);
        return events.filter(e => e.start < end && (e.end > start || (e.end.getTime() === e.start.getTime() && e.start >= start)));
    }

    // An event the calendar view should open for editing (set by IPC tests; the view clears it).
    property var editRequest: null

    // Whether an event can be changed or deleted here: it comes from a Google calendar you can
    // write to, and Google Calendar is connected.
    function editable(e) {
        return !!e && (e.googleCalendar ?? "") !== "" && (e.uid ?? "") !== "" && GoogleCalendar.connected && GoogleCalendar.calendars.some(c => c.id === e.googleCalendar);
    }

    // Hides an event changed or deleted elsewhere (GoogleCalendar.update/remove) right away.
    function hideEvent(uid, original) {
        _hidden = _hidden.concat([
            {
                uid: uid,
                original: original || "",
                at: Date.now()
            }
        ]);
        lastRun = 0;
        refreshSoon.restart();
    }

    // Shows an event created elsewhere (GoogleCalendar.add) right away, and reads the calendars
    // again. `event`: { title, allDay, start, end, location } as given to gcal.py.
    function addPending(event, color) {
        const allDay = !!event.allDay;
        const start = allDay ? parseDate(event.start, true) : new Date(event.start);
        let end;
        if (allDay) {
            const last = parseDate(event.end || event.start, true);
            end = new Date(last.getFullYear(), last.getMonth(), last.getDate() + 1);
        } else {
            end = event.end ? new Date(event.end) : new Date(start.getTime() + 3600000);
        }
        _pending = _pending.concat([
            {
                title: event.title,
                location: event.location || "",
                allDay: allDay,
                start: start,
                end: end,
                calendar: "Google Calendar",
                color: color || "",
                addedAt: Date.now()
            }
        ]);
        lastRun = 0;
        refreshSoon.restart();
    }

    // Adds an iCal link (https://, http:// or webcal://). Returns "" or why it was refused.
    function addLink(link, name) {
        const url = String(link ?? "").trim();
        if (!/^(https?|webcal):\/\/\S+$/i.test(url))
            return "Paste an https:// or webcal:// link to an iCal calendar";
        if (calendars.some(c => c.url === url))
            return "That calendar is already added";
        _add({
            name: _unique(String(name ?? "").trim() || _nameForLink(url), -1),
            url: url
        });
        return "";
    }

    // Renames calendar `index` (empty names are ignored). The events are read again under the new
    // name.
    function rename(index, name) {
        const n = String(name ?? "").trim();
        if (!calendars[index] || n === "" || n === calendars[index].name)
            return;
        const list = calendars.slice();
        list[index] = Object.assign({}, list[index], {
            name: _unique(n, index)
        });
        _write(list);
    }

    // `name`, or "name 2", "name 3"… if another calendar (not `except`) already has it.
    function _unique(name, except) {
        const taken = n => calendars.some((c, i) => i !== except && c.name === n);
        if (!taken(name))
            return name;
        let k = 2;
        while (taken(`${name} ${k}`))
            k++;
        return `${name} ${k}`;
    }

    // Adds the iCal link currently in the clipboard (answers through `notice`).
    function addFromClipboard(name) {
        if (clipboard.running)
            return;
        clipboard.name = String(name ?? "");
        clipboard.running = true;
    }

    // Colour of calendar `index` ("#rrggbb").
    function setColor(index, color) {
        if (!calendars[index])
            return;
        const list = calendars.slice();
        list[index] = Object.assign({}, list[index], {
            color: color
        });
        _write(list, false);
    }

    // Opens the system file chooser; the chosen .ics is copied next to the list and added.
    function addFile(name) {
        if (picker.running)
            return;
        picker.name = String(name ?? "").trim();
        picker.running = true;
    }

    function remove(index) {
        const c = calendars[index];
        if (!c)
            return;
        // A copied .ics goes too (only files inside our own folder).
        if (c.path && c.path.startsWith(filesDir + "/"))
            Quickshell.execDetached(["rm", "-f", "--", c.path]);
        _write(calendars.filter((_, i) => i !== index));
    }

    function _add(entry) {
        entry.color = CalendarConfig.colors[calendars.length % CalendarConfig.colors.length];
        _write(calendars.concat([entry]));
        notice(`Added "${entry.name}"`, false);
    }

    // Saves the list; `refetch` (default true) reads the calendars again (not needed for a colour).
    function _write(list, refetch) {
        calendars = list;
        configFile.setText(JSON.stringify({
            calendars: list
        }, null, 2) + "\n");
        if (refetch !== false) {
            lastRun = 0;
            refreshSoon.restart();
        }
    }

    // A readable name for a link: Google/Outlook/iCloud by host, else the host itself.
    function _nameForLink(url) {
        const host = (url.match(/^[a-z]+:\/\/([^\/?#]+)/i)?.[1] ?? "").toLowerCase();
        return host.includes("google.") ? "Google Calendar" : host.includes("outlook.") || host.includes("office365.") ? "Outlook" : host.includes("icloud.") ? "iCloud" : host.replace(/^www\./, "");
    }

    // Private links give read access to a calendar: the list and the copied files are yours only.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", 'mkdir -p -m 700 -- "$1" && chmod 700 -- "$1"', "sh", filesDir])

    // The list of calendars (the HyDE shell may change it too: watched).
    FileView {
        id: configFile
        path: root.configPath
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            // Every write (ours or the HyDE shell's) may create it world-readable: keep it private.
            Quickshell.execDetached(["chmod", "600", "--", root.configPath]);
            try {
                root.calendars = JSON.parse(text()).calendars ?? [];
            } catch (e) {
                root.calendars = [];
            }
            root.refresh(false);
        }
        // No list (never set up, or deleted): no calendars (and so no events).
        onLoadFailed: root.calendars = []
    }

    // The events the script wrote.
    FileView {
        path: `${Paths.cacheHome}/quickshell/calendar.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.errors = d.errors ?? [];
                root._events = (d.events ?? []).map(e => Object.assign({}, e, {
                            start: root.parseDate(e.start, e.allDay),
                            end: root.parseDate(e.end, e.allDay)
                        }));
            } catch (e) {}
        }
    }

    Timer {
        id: refreshSoon
        interval: 300
        onTriggered: root.refresh(true)
    }

    Timer {
        interval: Math.max(1, CalendarConfig.refreshMinutes) * 60000
        running: root.calendars.length > 0
        repeat: true
        onTriggered: root.refresh(true)
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.shellPath("shared/scripts/ical_events.py")]
        Component.onCompleted: Errors.watch(fetcher, "calendar", "ical_events.py")
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.info("calendar:", text.trim())
        }
    }

    Process {
        id: clipboard
        property string name: ""
        command: ["wl-paste", "--no-newline", "--type", "text"]
        stdout: StdioCollector {
            onStreamFinished: {
                const why = root.addLink(text, clipboard.name);
                if (why !== "")
                    root.notice(text.trim() === "" ? "The clipboard is empty: copy an iCal link first" : why, true);
            }
        }
    }

    // The chosen .ics is copied (the original may be moved or deleted later), then added.
    Process {
        id: picker
        property string name: ""
        command: ["python3", Quickshell.shellPath("shared/scripts/pick_file.py"), "Add a calendar (.ics)", "iCalendar:*.ics;*.ICS"]
        stdout: StdioCollector {
            onStreamFinished: {
                const src = text.trim();
                if (src === "")
                    return;
                const base = src.slice(src.lastIndexOf("/") + 1);
                const dst = `${root.filesDir}/${Date.now()}-${base}`;
                copier.dst = dst;
                copier.name = root._unique(picker.name || base.replace(/\.ics$/i, ""), -1);
                copier.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp -- "$1" "$2"', "sh", src, dst];
                copier.running = true;
            }
        }
    }

    Process {
        id: copier
        property string dst: ""
        property string name: ""
        onExited: code => {
            if (code === 0)
                root._add({
                    name: copier.name,
                    path: copier.dst
                });
        }
    }
}
