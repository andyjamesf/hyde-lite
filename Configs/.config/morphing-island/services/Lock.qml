pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs.config

// The island's session lock (ext-session-lock) with PAM authentication. Uses hyprlock's PAM
// configuration (/etc/pam.d/hyprlock, see LockScreenConfig.pamService), the same as HyDE's lock, so
// it accepts the same password.
//
// Entry points (IPC in shell.qml): `lock lock` (hypridle, `loginctl lock-session`) and `lock unlock`
// (`loginctl unlock-session`; it is the emergency exit and has the same trust level: any process of
// the user can already request unlock-session).
//
// The password only exists in the card's TextInput and, during authentication, in `_pending` until
// PAM asks for it (it is cleared right after). It is never logged nor written anywhere.
Singleton {
    id: root

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
        releaseTimer.interval = Animations.enabled ? LockScreenConfig.releaseMs : 0;
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
    readonly property string lockMarker: `${Paths.runtimeDir}/morphing-island-locked`
    FileView {
        path: root.lockMarker
        printErrors: false
        onLoaded: if (!persist.locked) {
            console.warn("lock: the island restarted while the screen was locked; locking again");
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
        interval: LockScreenConfig.errorMs
        onTriggered: root.error = ""
    }

    PamContext {
        id: pam
        config: LockScreenConfig.pamService

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
