pragma Singleton
import QtQuick
import Quickshell

// Polkit authentication dialog (pkexec, systemctl…). (Named PolkitConfig because
// services/Polkit.qml is the agent.)
Singleton {
    // Password attempts per request before it is cancelled (1 = the first failure closes).
    // 1–5, default 1.
    readonly property int maxAttempts: 1
    // How long "Authentication failed" stays visible (field locked) before the request is
    // cancelled. Milliseconds, default 1500.
    readonly property int failureNoticeMs: 1500
    // Enter/buttons are ignored for this long after the dialog opens, so a keypress meant for
    // another window does not answer it. Milliseconds, default 350.
    readonly property int armDelay: 350
}
