pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam

import qs.shared.services

// The session lock (ext-session-lock) with PAM authentication, shared by every UI of this
// configuration. It uses hyprlock's PAM configuration (/etc/pam.d/hyprlock by default), the same as
// HyDE's lock, so it accepts the same password.
//
// This is the island's service, kept as it was. It is the one that actually locks this machine —
// hypridle and $mod+L both go through `island lock`, which runs the island's lock screen whichever
// shell is up — so the code that takes a password was not the place to be clever. The bar's own was
// the same flow with fewer features (no release animation, no card screen, no crash recovery, no
// real name) and one thing of its own, the fallback to HyDE's hyprlock when the shell's lock is
// switched off in config.json; that is `enabled` and `fallbackCommand` below.
//
// Everything the bar's lock screen reads — locked, authenticating, error, failures, lock(),
// unlock(), submit() — is here under the same names, so its surface did not have to change.
//
// Entry points (IPC in shell.qml): `lock lock` (hypridle, `loginctl lock-session`) and `lock unlock`
// (`loginctl unlock-session`; it is the emergency exit and has the same trust level: any process of
// the user can already request unlock-session).
//
// The password only exists in the card's TextInput and, during authentication, in `_pending` until
// PAM asks for it (it is cleared right after). It is never logged nor written anywhere.
Singleton {
    id: root

    // What a shell configures. A shared service has no settings file of its own: the island binds
    // these from config/LockScreenConfig.qml and config/Animations.qml, the bar `enabled` from
    // config.json (widgets.lock.enabled).
    property string pamService: "hyprlock"
    property int releaseMs: 560
    property int errorMs: 3500
    property bool animated: true
    // false: this lock is not used at all and lock() hands over to the command below.
    property bool enabled: true
    property string fallbackCommand: "hyde-shell lockscreen.sh"
    // Take the lock back after a crash (see lockMarker below). Only the process that owns the lock
    // screen may: the island and lock.qml set it. The bar shell must not — it reads the same
    // service now, and on a reload it would find the marker of a lock it does not own and lock the
    // session again, which is exactly what happened the first time this service was shared.
    property bool recoverLock: false

    // The state survives a shell reload: the new WlSessionLock resumes the lock. Without this, a
    // reload with the screen locked dropped the lock and Hyprland showed "lockscreen app died".
    readonly property bool locked: persist.locked
    // Authenticated: the card turns back into the clock pill and the background loses its blur; the
    // lock is only released at the end (releaseTimer).
    property bool unlocking: false
    readonly property bool authenticating: pam.active
    property string error: ""
    property int failures: 0

    // Screen holding the password card (the others only show the clock pill). Chosen when locking
    // (focused monitor), then it follows the keyboard focus of the surfaces.
    readonly property string cardScreen: persist.cardScreen || (Hyprland.focusedMonitor?.name ?? "") || (Quickshell.screens[0]?.name ?? "")

    // Name to show: the real name (GECOS) if any, otherwise the login.
    readonly property string user: Quickshell.env("USER") ?? ""
    property string userName: user

    // Password waiting to be requested by PAM (only exists during authentication).
    property string _pending: ""
    // What PAM said during the current attempt (e.g. pam_faillock's "account locked" notice).
    property var _pamMessages: []

    function lock() {
        if (!enabled) {
            Quickshell.execDetached(["sh", "-c", fallbackCommand]);
            return;
        }
        if (persist.locked)
            return;
        releaseTimer.stop();
        unlocking = false;
        error = "";
        failures = 0;
        persist.cardScreen = Hyprland.focusedMonitor?.name ?? "";
        persist.locked = true;
    }

    // Authorized unlock (PAM success or IPC): animates the exit and only then releases the lock.
    function unlock() {
        _pending = "";
        if (pam.active)
            pam.abort();
        if (!persist.locked || unlocking)
            return;
        error = "";
        failures = 0;
        unlocking = true;
        releaseTimer.interval = animated ? releaseMs : 0;
        releaseTimer.restart();
    }

    function submit(password) {
        if (!persist.locked || unlocking || pam.active || password === "")
            return;
        error = "";
        errorTimer.stop();
        _pamMessages = [];
        _pending = password;
        if (!pam.start()) {
            _pending = "";
            error = "Authentication unavailable";
        }
    }

    // This screen's surface got the keyboard (or was clicked): the card moves there.
    function focusScreen(name) {
        if (!persist.locked || unlocking || pam.active || !name || name === persist.cardScreen)
            return;
        persist.cardScreen = name;
    }

    function clearError() {
        errorTimer.stop();
        error = "";
    }

    function _release() {
        _pending = "";
        unlocking = false;
        persist.cardScreen = "";
        persist.locked = false;
    }

    PersistentProperties {
        id: persist
        reloadableId: "islandLockState"

        property bool locked: false
        property string cardScreen: ""

        // Mirrored in a file (lockMarker) so a new island process knows the screen was locked.
        onLockedChanged: Quickshell.execDetached(locked ? ["touch", root.lockMarker] : ["rm", "-f", root.lockMarker])
    }

    // Crash recovery. If the island dies while the screen is locked (e.g. a monitor unplugged at
    // the moment of locking), Hyprland keeps the session locked ("lockscreen app died") and, with
    // misc:allow_session_lock_restore, lets a new client take the lock over. `island run` starts
    // the island again; this file tells the new process to lock at once. It lives in the runtime
    // directory, so a logout or reboot clears it.
    readonly property string lockMarker: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/morphing-island-locked`
    FileView {
        path: root.lockMarker
        printErrors: false
        onLoaded: if (root.recoverLock && !persist.locked) {
            console.warn("lock: the shell restarted while the screen was locked; locking again");
            root.lock();
        }
    }

    Timer {
        id: releaseTimer
        onTriggered: root._release()
    }

    // The error message disappears by itself after a while.
    Timer {
        id: errorTimer
        interval: root.errorMs
        onTriggered: root.error = ""
    }

    PamContext {
        id: pam
        config: root.pamService

        onPamMessage: {
            if (responseRequired) {
                respond(root._pending);
                root._pending = "";
            } else if (message !== "") {
                root._pamMessages = root._pamMessages.concat([message]);
                if (messageIsError)
                    root.error = PamText.friendly(message);
            }
        }

        onCompleted: result => {
            root._pending = "";
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.failures++;
                // PAM's own explanation wins (a locked account refuses even the right password).
                const said = PamText.friendly(root._pamMessages.join(" "));
                root.error = said !== "" ? said : result === PamResult.MaxTries ? "Too many attempts, wait a moment" : "Wrong password";
                errorTimer.restart();
            }
        }

        onError: err => {
            root._pending = "";
            root.error = `Authentication error (${PamError.toString(err)})`;
            errorTimer.restart();
        }
    }

    // The user's real name (GECOS field of passwd, up to the first comma).
    Process {
        running: root.user !== ""
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (gecos !== "")
                    root.userName = gecos;
            }
        }
    }
}
