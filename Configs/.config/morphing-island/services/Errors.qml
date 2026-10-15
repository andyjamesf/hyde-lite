pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// One place for the failures that used to be silent. The shell runs about 35 external commands and
// only a third of them ever looked at an exit code, so when `cliphist`, `grimblast` or one of the
// scripts/ helpers was missing or broke, the key simply did nothing: no notification, no log, and
// no way to tell "not installed, which is fine" from "installed and broken".
//
// Call `report(source, what)` from a catch block, or `reportExit(source, code, tool)` straight from
// an `onExited` handler. Each source speaks once per session, so a command that fails on a timer
// does not turn into a stream of notifications, and failures that arrive together are collected
// into a single one.
//
// Capability probes are NOT failures: services/Launch.qml and services/NightLight.qml run a command
// to find out whether a tool is there at all, and a non-zero exit is their normal answer. Those are
// left alone on purpose.
Singleton {
    id: root

    // Everything reported this session, newest first: { source, what, at }. Kept so a settings or
    // debug view can list it later; nothing reads it yet.
    property var entries: []
    readonly property int count: entries.length

    // Sources already announced, so each one only notifies once.
    property var _seen: ({})
    // Reported but not yet announced.
    property var _pending: []

    // `source`: the service or tool as the user would name it ("clipboard", "screenshot").
    // `what`: one line, already readable, saying what went wrong.
    function report(source, what) {
        const s = String(source || "shell");
        const w = String(what || "failed");
        entries = [
            {
                source: s,
                what: w,
                at: new Date()
            }
        ].concat(entries).slice(0, 50);
        console.warn(`${s}: ${w}`);
        if (_seen[s])
            return;
        // QML only notices a property change when the object itself changes.
        const seen = _seen;
        seen[s] = true;
        _seen = seen;
        _pending = _pending.concat([`${s}: ${w}`]);
        announce.restart();
    }

    // For an `onExited` handler. Exit 127 is the shell's "command not found", which is worth its
    // own wording: it means something is missing, not broken.
    function reportExit(source, code, tool) {
        if (code === 0)
            return;
        report(source, code === 127 ? `${tool} is not installed` : `${tool} failed (exit ${code})`);
    }

    // Watches a Process for both ways it can go wrong, so a call site needs one line:
    //     Component.onCompleted: Errors.watch(lister, "clipboard", "cliphist")
    // A program that is not installed never reaches `exited` at all -- QProcess reports
    // failedToStart instead and `finished` is never emitted -- so an exit code alone misses the
    // commonest failure of the lot. `started` not having fired by the time `running` goes false is
    // what catches it. Do not use this where a non-zero exit is a normal answer: a capability probe
    // (services/Launch.qml, services/NightLight.qml) or a command the user can cancel, like
    // grimblast in services/Screenshot.qml, which exits non-zero on Esc.
    function watch(proc, source, tool) {
        let started = false;
        proc.started.connect(() => {
            started = true;
        });
        proc.runningChanged.connect(() => {
            if (proc.running)
                return;
            if (!started)
                root.report(source, `${tool} is not installed`);
            started = false;
        });
        proc.exited.connect(code => root.reportExit(source, code, tool));
    }

    function forget() {
        entries = [];
        _seen = ({});
    }

    // Collects the failures of one moment into a single notification instead of one each.
    Timer {
        id: announce
        interval: 1500
        onTriggered: {
            const items = root._pending;
            root._pending = [];
            if (items.length === 0)
                return;
            notifier.command = ["notify-send", "-a", "Morphing Island", "--", items.length > 1 ? "Some things are not working" : "Something is not working", items.join("\n")];
            notifier.running = true;
        }
    }

    Process {
        id: notifier
    }
}
