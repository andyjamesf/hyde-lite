import QtQuick
import qs.config

// Gives keyboard focus to `target` now and once more after Behaviour.focusRetryMs: the window's
// focus arrives a moment after a view opens, and the island reclaims it when the mode changes.
// `when` (default true) is checked again before the retry (e.g. bind it to the view's `open`).
//
//   FocusRetry { id: focusRetry; target: input; when: root.open }
//   function reset() { focusRetry.start(); }
QtObject {
    id: retry

    property Item target: null
    property bool when: true

    // Focuses now and schedules the retry.
    function start() {
        if (target)
            target.forceActiveFocus();
        timer.restart();
    }

    function stop() {
        timer.stop();
    }

    property Timer timer: Timer {
        interval: Behaviour.focusRetryMs
        onTriggered: if (retry.when && retry.target)
            retry.target.forceActiveFocus()
    }
}
