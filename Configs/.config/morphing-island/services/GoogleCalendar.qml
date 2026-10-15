pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Google Calendar: creating events (the calendars the calendar view reads are iCal links, which are
// read-only). The work is done by scripts/gcal.py (OAuth, calendar list, event creation); the
// client file and the granted access live in ~/.local/share/quickshell/google/, outside git.
//
// Setup, once: chooseClient() (the OAuth client file from Google Cloud Console), then connect()
// (the browser asks for permission). Then add(event) creates events (fields: see gcal.py).
Singleton {
    id: root

    property bool hasClient: false
    property bool connected: false
    // Your Google calendars you can add events to: [{ id, name, color, primary }].
    property var calendars: []
    // A command is running (connecting waits for the browser).
    readonly property bool busy: runner.running
    property string error: ""

    // Google's event colours (colorId → name and colour).
    readonly property var eventColors: [
        {
            id: "1",
            name: "Lavender",
            color: "#7986cb"
        },
        {
            id: "2",
            name: "Sage",
            color: "#33b679"
        },
        {
            id: "3",
            name: "Grape",
            color: "#8e24aa"
        },
        {
            id: "4",
            name: "Flamingo",
            color: "#e67c73"
        },
        {
            id: "5",
            name: "Banana",
            color: "#f6bf26"
        },
        {
            id: "6",
            name: "Tangerine",
            color: "#f4511e"
        },
        {
            id: "7",
            name: "Peacock",
            color: "#039be5"
        },
        {
            id: "8",
            name: "Graphite",
            color: "#616161"
        },
        {
            id: "9",
            name: "Blueberry",
            color: "#3f51b5"
        },
        {
            id: "10",
            name: "Basil",
            color: "#0b8043"
        },
        {
            id: "11",
            name: "Tomato",
            color: "#d50000"
        }
    ]

    // An event was created (ok) or refused (the text says why).
    signal added(bool ok, string text)
    // An event to edit arrived (load): the form's fields plus "id"; or `error` says why not.
    signal loaded(var fields)
    // An event was changed or deleted (ok) or refused.
    signal changed(bool ok, string text)

    function colorOf(id) {
        return eventColors.find(c => c.id === String(id))?.color ?? "";
    }

    function refreshStatus() {
        _run("status", ["status"]);
    }

    // Opens the system file chooser for the OAuth client file Google gave you.
    function chooseClient() {
        if (!picker.running)
            picker.running = true;
    }

    // Opens the browser to grant access; finishes when you answer there (up to 5 minutes).
    function connect() {
        error = "";
        _run("connect", ["connect"]);
    }

    function disconnect() {
        _run("disconnect", ["disconnect"]);
    }

    function loadCalendars() {
        if (connected)
            _run("calendars", ["calendars"]);
    }

    // `event`: { calendar, title, allDay, start, end, repeat, color, location, description,
    // reminders } (see scripts/gcal.py). The new event shows in the calendar view at once.
    function add(event) {
        error = "";
        _pendingEvent = event;
        _run("add", ["add", JSON.stringify(event)]);
    }

    // Editing (the calendar view's events from Google calendars, see Calendar.editable):
    // `event` from the calendar view ({ googleCalendar, uid, originalStart, … }); scope "this" (one
    // occurrence of a repeating event) or "all".
    function load(event, scope) {
        error = "";
        _run("get", ["get", event.googleCalendar, event.uid, event.originalStart || "", scope]);
    }
    // `target`: { calendar, id, uid, originalStart, scope }; `event` as for add.
    function update(target, event) {
        error = "";
        _target = target;
        _pendingEvent = event;
        _run("update", ["update", target.calendar, target.id, JSON.stringify(event)]);
    }
    function remove(target) {
        error = "";
        _target = target;
        _run("delete", ["delete", target.calendar, target.id]);
    }
    property var _target: null

    property var _pendingEvent: null
    property var _queue: []

    function _run(kind, args) {
        if (runner.running) {
            // One command at a time; status/calendars can wait their turn.
            _queue = _queue.concat([[kind, args]]);
            return;
        }
        runner.kind = kind;
        runner.command = ["python3", Quickshell.shellPath("scripts/gcal.py")].concat(args);
        runner.running = true;
    }

    function _done(kind, text) {
        let r = null;
        try {
            r = JSON.parse(String(text).trim().split("\n").pop() || "null");
        } catch (e) {
            r = {
                error: "Unexpected answer from gcal.py"
            };
        }
        const err = r && !Array.isArray(r) && r.error ? r.error : "";
        if (kind === "status" && !err) {
            hasClient = r.client;
            connected = r.connected;
            if (connected && calendars.length === 0)
                loadCalendars();
        } else if (kind === "calendars") {
            if (err)
                error = err;
            else
                calendars = r;
        } else if (kind === "add") {
            if (err) {
                error = err;
                added(false, err);
            } else {
                Calendar.addPending(_pendingEvent, colorOf(_pendingEvent.color) || (calendars.find(c => c.id === _pendingEvent.calendar)?.color ?? ""));
                added(true, `Added "${_pendingEvent.title}" to Google Calendar`);
            }
        } else if (kind === "get") {
            if (err)
                error = err;
            loaded(err ? null : r);
        } else if (kind === "update" || kind === "delete") {
            if (err) {
                error = err;
                changed(false, err);
            } else {
                // The old version goes away at once; an edited one shows with its changes.
                Calendar.hideEvent(_target.uid, _target.scope === "all" ? "" : _target.originalStart);
                if (kind === "update")
                    Calendar.addPending(_pendingEvent, colorOf(_pendingEvent.color) || (calendars.find(c => c.id === _target.calendar)?.color ?? ""));
                else
                    Calendar.refresh(true);
                changed(true, kind === "update" ? `Saved "${_pendingEvent.title}"` : "Deleted");
            }
        } else if (err) {
            error = err;
        }
        if (kind === "connect" || kind === "disconnect" || kind === "setClient") {
            if (kind === "disconnect")
                calendars = [];
            refreshStatus();
        }
        if (_queue.length > 0) {
            const next = _queue[0];
            _queue = _queue.slice(1);
            Qt.callLater(_run, next[0], next[1]);
        }
    }

    Component.onCompleted: refreshStatus()

    Process {
        id: runner
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: root._done(runner.kind, text)
        }
    }

    Process {
        id: picker
        command: ["python3", Quickshell.shellPath("scripts/pick_file.py"), "Google OAuth client file (client_secret_….json)", "JSON:*.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root._run("setClient", ["set-client", path]);
            }
        }
    }
}
