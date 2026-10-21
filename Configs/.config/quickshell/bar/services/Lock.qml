pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pam

// The shell's session lock (ext-session-lock) with PAM authentication — the same configuration as
// hyprlock (/etc/pam.d/hyprlock), so it accepts the same credentials.
//
// Entry points: `qs ipc call lock lock` (used by hypridle and by `loginctl lock-session`) and
// `qs ipc call lock unlock` (used by `loginctl unlock-session`; it is the emergency exit and has the
// same trust level: any user process can already do unlock-session).
// With `lock.enabled: false` in config.json, locking uses HyDE's hyprlock.
Singleton {
    id: root

    // The state survives a shell reload: the new WlSessionLock resumes the lock. Without this, a
    // reload with the screen locked dropped the lock and Hyprland showed "lockscreen app died".
    property alias locked: persist.locked
    property bool authenticating: pam.active
    property string error: ""
    property int failures: 0
    // Password waiting to be requested by PAM (only exists during authentication).
    property string pending: ""
    // What PAM said during the current attempt (e.g. pam_faillock's "account locked" notice).
    property var pamMessages: []

    function lock() {
        if (!Config.widgets.lock.enabled) {
            Utils.run("hyde-shell lockscreen.sh");
            return;
        }
        error = "";
        locked = true;
    }

    function unlock() {
        pending = "";
        error = "";
        failures = 0;
        if (pam.active)
            pam.abort();
        locked = false;
    }

    function submit(password) {
        if (!locked || pam.active || password === "")
            return;
        error = "";
        pamMessages = [];
        pending = password;
        pam.start();
    }

    PersistentProperties {
        id: persist
        reloadableId: "lockState"
        property bool locked: false
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            } else if (message !== "") {
                root.pamMessages = root.pamMessages.concat([message]);
                if (messageIsError)
                    root.error = PamText.friendly(message);
            }
        }

        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.failures++;
                // PAM's own explanation wins (a locked account refuses even the right password).
                const said = PamText.friendly(root.pamMessages.join(" "));
                root.error = said !== "" ? said : result === PamResult.MaxTries ? "Too many attempts, wait a moment" : "Wrong password";
            }
        }

        onError: err => {
            root.pending = "";
            root.error = `Authentication error (${PamError.toString(err)})`;
        }
    }
}
