pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Calendar events (Google Calendar or any other with an iCal address), for the bar calendar.
// The work is done by scripts/ical_events.py, which downloads the calendars listed in
// ~/.local/share/quickshell/calendars.json and writes ~/.cache/quickshell/calendar.json; this
// service watches that file. It refreshes every 15 minutes and when the calendar is opened.
Singleton {
    id: root

    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"
    readonly property string configPath: `${dataHome}/quickshell/calendars.json`

    property bool configured: false
    property var events: []
    property var errors: []
    property real lastRun: 0

    // Refreshes, but no more than once every 2 minutes (opening and closing the popout repeatedly).
    function refresh() {
        if (configured && Date.now() - lastRun > 120000) {
            lastRun = Date.now();
            fetcher.running = true;
        }
    }

    // "2026-09-25" (all day) must be a local date, not UTC midnight.
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

    // Events touching a day (multi-day ones show up on every day).
    function eventsOn(day) {
        const start = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1);
        return events.filter(e => e.start < end && (e.end > start || (e.end.getTime() === e.start.getTime() && e.start >= start)));
    }

    function upcoming(count) {
        const now = new Date();
        return events.filter(e => e.end > now).slice(0, count);
    }

    function openInBrowser(day) {
        Utils.run(`xdg-open https://calendar.google.com/calendar/r/day/${day.getFullYear()}/${day.getMonth() + 1}/${day.getDate()}`);
    }

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.configured = true;
            root.lastRun = 0;
            root.refresh();
        }
        onLoadFailed: root.configured = false
    }

    FileView {
        path: `${root.cacheHome}/quickshell/calendar.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.errors = d.errors ?? [];
                root.events = (d.events ?? []).map(e => Object.assign({}, e, {
                            start: root.parseDate(e.start, e.allDay),
                            end: root.parseDate(e.end, e.allDay)
                        }));
            } catch (e) {}
        }
    }

    Process {
        id: fetcher
        command: ["python3", Quickshell.shellPath("scripts/ical_events.py")]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "")
                console.warn("calendar:", text.trim())
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.configured
        onTriggered: {
            root.lastRun = 0;
            root.refresh();
        }
    }
}
