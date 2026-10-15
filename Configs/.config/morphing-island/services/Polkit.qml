pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.core
import qs.config

// The island's polkit authentication agent (pkexec, systemctl, package managers…). Uses Quickshell's
// native agent (Quickshell.Services.Polkit): it registers with polkitd on the default path
// (/org/quickshell/PolkitAgent), and there can be only one agent per session, so HyDE's
// (hyprpolkitagent) must be stopped while the island is running.
//
// Life cycle of a request:
//  • polkitd asks for authentication → the agent creates an AuthFlow (`flow`) and the island opens
//    the "auth" mode, even if another surface is open (authentication has priority). If the screen
//    is locked, it waits for the unlock.
//  • The request ends (success, cancellation or final failure) → the surface closes.
//  • The surface closes for another reason (Esc, click outside, another mode) while the request is
//    still unanswered → the request is cancelled. A request is never left hanging nor hidden.
//
// Failures (safe behaviour): by default (PolkitConfig.maxAttempts = 1) a wrong password shows
// "Authentication failed" for PolkitConfig.failureNoticeMs with the field locked, then the request is
// cancelled and the island closes. The caller (pkexec, etc.) gets "not authorized" and can ask again.
// With maxAttempts > 1 the user can retry within the same request (the AuthFlow asks for the
// password again) until the attempts run out.
//
// Security: the password only goes through `submit(pw)` straight to `flow.submit()`. It is not kept
// in any property, never logged, and nothing about the request is written to the console.
Singleton {
    id: root

    // Current request (null if none). The agent replaces it on every new request (internal queue).
    readonly property var flow: agent.flow
    // There is an unanswered request.
    readonly property bool active: !!flow && !flow.isCompleted
    // The agent is registered with polkitd (false if another agent already owns the session).
    readonly property bool registered: agent.isRegistered

    // Attempts allowed per request before cancelling (1 = the first failure closes).
    readonly property int maxAttempts: PolkitConfig.maxAttempts
    // Failures in the current request.
    property int failures: 0
    // Showing "Authentication failed" (the field is locked if it is the final failure).
    property bool failedNotice: false
    // Final failure: the request will be cancelled at the end of the notice.
    readonly property bool closingAfterFailure: failTimer.running
    // PAM is waiting for an answer and it can still be answered.
    readonly property bool canRespond: active && flow.isResponseRequired && !closingAfterFailure

    // Failed attempt (the view shakes the field).
    signal attemptFailed

    // Sends the answer to PAM. Keeps nothing: the value goes straight to the AuthFlow.
    function submit(pw) {
        if (!canRespond)
            return;
        failedNotice = false;
        flow.submit(pw);
    }

    // Cancels the current request (Esc, Cancel button, surface closed).
    function cancel() {
        failTimer.stop();
        if (active)
            flow.cancelAuthenticationRequest();
        else
            closeSurface();
    }

    // Opens (or keeps open) the authentication surface.
    function showSurface() {
        if (!active || Lock.locked)
            return;
        // open() toggles: if already in "auth" it would close, so it only opens when it is not.
        if (IslandController.mode !== IslandState.auth)
            IslandController.open(IslandState.auth);
    }

    // Closes the surface, unless another queued request is already waiting for an answer.
    function closeSurface() {
        if (active) {
            showSurface();
            return;
        }
        if (IslandController.mode !== IslandState.auth)
            return;
        closingSelf = true;
        IslandController.close();
        closingSelf = false;
    }

    // True while the service itself is closing the surface (not a cancellation).
    property bool closingSelf: false

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: root.showSurface()
        onFlowChanged: {
            if (root.active) {
                // New request: the previous one's count and notices do not carry over.
                failTimer.stop();
                root.failures = 0;
                root.failedNotice = false;
                root.showSurface();
            } else if (!failTimer.running) {
                // No request. (If the failure notice is still showing, the timer closes.)
                root.failures = 0;
                root.failedNotice = false;
                root.closeSurface();
            }
        }
    }

    // Signals of the current request (the target changes by itself when the agent switches requests).
    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onAuthenticationSucceeded() {
            failTimer.stop();
            root.failedNotice = false;
            Qt.callLater(root.closeSurface);
        }
        function onAuthenticationRequestCancelled() {
            failTimer.stop();
            root.failedNotice = false;
            Qt.callLater(root.closeSurface);
        }
        function onAuthenticationFailed() {
            root.failures += 1;
            root.failedNotice = true;
            root.attemptFailed();
            // Final failure: shows the error for a moment and cancels. If the AuthFlow already finished on
            // its own, the timer only closes the surface.
            if (root.failures >= root.maxAttempts)
                failTimer.restart();
        }
        function onIsCompletedChanged() {
            if (root.flow && root.flow.isCompleted && !failTimer.running)
                Qt.callLater(root.closeSurface);
        }
    }

    // Final failure notice → cancels the request (or only closes, if it already finished).
    Timer {
        id: failTimer
        interval: PolkitConfig.failureNoticeMs
        onTriggered: {
            root.failedNotice = false;
            if (root.active)
                root.flow.cancelAuthenticationRequest();
            else
                root.closeSurface();
        }
    }

    // The surface left "auth" without the service doing it (Esc, click outside, another mode): cancel.
    // The "auth" mode without a request (e.g. opened by hand) closes right away.
    Connections {
        target: IslandController

        function onModeChanged() {
            if (IslandController.mode === IslandState.auth) {
                if (!root.active)
                    Qt.callLater(root.closeSurface);
                return;
            }
            if (!root.closingSelf && root.active)
                root.cancel();
        }
    }

    // A request that arrived while the screen was locked: shows up on unlock.
    Connections {
        target: Lock

        function onLockedChanged() {
            if (!Lock.locked)
                root.showSurface();
        }
    }

    // Shell reload/exit with a request open: do not leave it hanging.
    Component.onDestruction: {
        if (active)
            flow.cancelAuthenticationRequest();
    }
}
