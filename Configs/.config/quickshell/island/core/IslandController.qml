pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.island.config
import qs.island.services
// Brightness is only read inside a template literal below, which qmllint does not look into,
// so it reports this import as unused. It is not.
// qmllint disable unused-imports
import qs.shared.services
// qmllint enable unused-imports

// The island's state machine. `mode` is what the island on the active screen shows on top of the
// base mode; the base mode (clock or expanded) belongs to each screen and depends on hover and pin.
Singleton {
    id: root

    // Current surface or transient ("" = none: each island shows its base mode).
    property string mode: ""
    // Screen where `mode` appears (the one that had the focus when it opened).
    property string screen: ""
    // Pinned expanded island (click on empty space).
    property bool pinned: false
    // Data of the current transient (OSD value, notification…).
    property var payload: null
    // IPC tests: pretends the pointer is over the island on the active screen.
    property bool forceHover: false
    // Transient paused (hover over the island).
    property bool held: false

    // Countdown of the current transient (ms). Time only advances while it is visible and not
    // hovered, so leaving the hover resumes where it stopped instead of starting over.
    property int transientDuration: 0
    property real transientElapsed: 0
    // 0 → just appeared; 1 → about to close (for the countdown indicator).
    readonly property real transientProgress: transientDuration > 0 ? Math.min(1, transientElapsed / transientDuration) : 0

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""

    // `screen` is a snapshot taken when something opened. A screen can go away while it is still
    // open (a monitor unplugged, a dock pulled), and then no island matches the stale name: the
    // surface is drawn on no screen at all while `mode` stays set, and for the keyboard modes
    // IslandWindow goes on granting it exclusive keyboard focus, so an invisible surface ends up
    // holding the keyboard. Everything that draws matches on this instead: it falls back to the
    // focused screen, so an open surface follows along to a screen that still exists.
    // core/StatsWindow.qml and services/Lock.qml guard their own saved screen names the same way.
    readonly property string effectiveScreen: screen !== "" && Quickshell.screens.some(s => s.name === screen) ? screen : focusedScreen

    // Mode the island of a screen should show.
    function modeFor(screenName, hovered) {
        if (mode !== "" && screenName === effectiveScreen)
            return mode;
        return pinned || (hovered && Pill.hoverExpand) ? IslandState.expanded : IslandState.clock;
    }

    // Hint under a hovered icon (StatusZone): its id (text from Shortcuts.hint), the screen and
    // where to draw it (window coordinates of the icon's bottom centre). "" = none.
    property string hint: ""
    property string hintScreen: ""
    property point hintAt: Qt.point(0, 0)
    // A clicked icon can keep its hint up for a while (the AI usage): shown at once, and not taken
    // away when the pointer leaves.
    property bool hintPinned: false
    property string _pinnedHint: ""
    function pinHint(id, ms) {
        _pinnedHint = id;
        hintPinned = true;
        hint = id;
        hintUnpin.interval = ms;
        hintUnpin.restart();
    }
    Timer {
        id: hintUnpin
        onTriggered: {
            root.hintPinned = false;
            root.hint = "";
        }
    }
    // Right-click menu of a button (services/Menus.qml): its id ("" = none), the screen and where
    // to draw it (window coordinates of the button's bottom centre). Drawn by IslandWindow.
    property string menu: ""
    property string menuScreen: ""
    property point menuAt: Qt.point(0, 0)
    // Opens the menu of `id` under `item` (a button); a second right click on it closes it.
    function openMenu(id, item, screenName) {
        if (menu === id && menuScreen === screenName) {
            menu = "";
            return;
        }
        hint = "";
        menuScreen = screenName;
        menuAt = item.mapToItem(null, item.width / 2, item.height);
        menu = id;
    }
    function closeMenu() {
        menu = "";
    }

    // A click that changes the island (opens a page, closes it) takes the hint and the menu away.
    onModeChanged: {
        hint = "";
        menu = "";
    }
    onPinnedChanged: hint = ""
    // Pointing at another icon ends the pinned one.
    onHintChanged: if (hint !== _pinnedHint)
        hintPinned = false

    // Surface Esc returns to (e.g. theme or wallpaper opened from the settings).
    property string returnMode: ""

    // Hints and clicks of the status widgets that read a service of their own (microphone, brightness, what is
    // playing); services/Shortcuts.qml asks for them here, so IPC still goes through Shortcuts. They are here and
    // not in Shortcuts because qmllint reports a member read of a singleton from a file in the same directory
    // (Audio, Media and Brightness are Shortcuts' neighbours) as "not found"; from another directory it resolves
    // them. (A file of their own would add a qmllint "import" finding of its own, as every singleton file does.)
    function widgetHint(id) {
        switch (id) {
        case "mic":
            return Audio.micMuted ? "Microphone: muted" : `Microphone: ${Math.round(Audio.micVolume * 100)}%`;
        case "brightness":
            return `Brightness: ${Brightness.percent}% (scroll to change)`;
        case "media":
            return Media.active ? `${Media.title}${Media.artist !== "" ? "\n" + Media.artist : ""}` : "Nothing is playing";
        }
        return "";
    }

    // Whether a click on the widget is handled by widgetClick (a brightness click is not: it opens the control center).
    function widgetHandlesClick(id) {
        return id === "mic" || id === "media";
    }

    // A click on the widget. `button` is Qt.LeftButton, Qt.MiddleButton...
    function widgetClick(id, button) {
        if (id === "mic")
            Audio.toggleMicMute();
        else if (id === "media") {
            if (button === Qt.MiddleButton)
                Media.next();
            else
                Media.togglePlaying();
        }
    }

    function open(m) {
        if (mode === m && screen === focusedScreen) {
            close();
            return;
        }
        returnMode = mode === IslandState.settings && (m === IslandState.theme || m === IslandState.wallpaper) ? IslandState.settings : "";
        screen = focusedScreen;
        payload = null;
        resetCountdown(0);
        mode = m;
    }

    // Closes the island and runs `fn` once the compositor has handed the keyboard back.
    //
    // A surface in keyboardModes holds the keyboard exclusively; on close Hyprland gives it back to
    // the window that had it before, and follows that window to its own workspace. So anything that
    // changes the workspace has to run after that handover, which is a Wayland round trip and not a
    // turn of the event loop. It cannot wait inside the view either: ModeSlot unloads it once the
    // fade-out is done (config/Animations.qml fadeOut, 110 ms), which kills any timer living there.
    property var deferred: null
    function closeThen(fn) {
        close();
        deferred = fn;
        handover.restart();
    }

    Timer {
        id: handover
        interval: 180
        onTriggered: {
            const fn = root.deferred;
            root.deferred = null;
            if (fn)
                fn();
        }
    }

    function close() {
        resetCountdown(0);
        payload = null;
        returnMode = "";
        mode = "";
    }

    // Esc: from the subviews back to the control center; from the rest, to the clock.
    function back() {
        if (returnMode !== "") {
            mode = returnMode;
            returnMode = "";
        } else if (IslandState.subviews.includes(mode))
            mode = IslandState.controlCenter;
        else
            close();
    }

    // Storm guard for the three OSDs that something other than a person can trigger (an app moving the
    // microphone gain, a panel flapping its brightness): see OsdConfig.stormGapMs. Notifications and
    // screenshots are never suppressed. `_runs` keeps, per mode, when the current unbroken run of
    // requests started and when the last one came, and whether it is being ignored. A run ends after
    // a pause, which also ends the ignoring. The warning is printed once per run; it is what tells
    // the owner which OSD it was, and it stays in the instance's log.
    // The values of IslandState.volume, .mic and .brightness, written out: qmllint cannot see IslandState's
    // members from a property binding here and counts each one (tools/tests/test_osd_guard.py keeps them equal).
    readonly property var _guarded: ["volume", "mic", "brightness"]
    property var _runs: ({})

    function _stormy(m) {
        const now = Date.now();
        const run = _runs[m] ?? {
            start: now,
            last: now,
            ignoring: false
        };
        if (now - run.last > OsdConfig.stormGapMs) {
            run.start = now;
            run.ignoring = false;
        }
        run.last = now;
        if (!run.ignoring && now - run.start > OsdConfig.stormAfterMs) {
            run.ignoring = true;
            console.warn(`OSD storm: "${m}" has been requested without a ${OsdConfig.stormGapMs / 1000} s pause for ${OsdConfig.stormAfterMs / 1000} s; ignoring it until it stops`);
        }
        _runs[m] = run;
        return run.ignoring;
    }

    // OSD/notification: only appear when no surface opened by the user is showing.
    function showTransient(m, data, timeout) {
        // Counted before the surface check, so a storm is named in the log even while a surface is open.
        if (_guarded.includes(m) && _stormy(m))
            return false;
        if (IslandState.isSurface(mode))
            return false;
        screen = focusedScreen;
        payload = data;
        resetCountdown(timeout ?? OsdConfig.timeout);
        mode = m;
        return true;
    }

    function resetCountdown(duration) {
        transientDuration = duration;
        transientElapsed = 0;
        transientTimer.last = Date.now();
    }

    function togglePin() {
        pinned = !pinned;
    }

    // A single cheap tick (100 ms) while a transient is visible and not hovered. Measures the real
    // elapsed time (Date.now) so the timer's own delay does not accumulate.
    Timer {
        id: transientTimer

        property real last: 0

        interval: 100
        repeat: true
        running: root.transientDuration > 0 && !root.held && IslandState.isTransient(root.mode)
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            root.transientElapsed += now - last;
            last = now;
            if (root.transientElapsed >= root.transientDuration)
                root.close();
        }
    }
}
