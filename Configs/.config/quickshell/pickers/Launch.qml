pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The single place that starts programs from the shell (apps, files, URLs, picker actions) and
// pastes text into the focused window.
//
// Programs must not die with the shell. The shell runs in a systemd unit (ExitType=cgroup): a
// plain execDetached stays in the shell's cgroup and is killed when it restarts. With
// `hyde-shell app` (app2unit) each program gets its own unit, like HyDE's rofi launcher; without
// hyde-shell the command runs as is.
Singleton {
    id: root

    // Checked once at startup (no polling).
    property bool hasHydeShell: false

    // Runs a command (argument list) in its own unit.
    function run(argv) {
        if (!argv || argv.length === 0)
            return;
        Quickshell.execDetached(hasHydeShell ? ["hyde-shell", "app", "--"].concat(argv) : argv);
    }

    // Opens a file or URL with the default application.
    function open(target) {
        const t = String(target ?? "");
        if (t !== "")
            run(["xdg-open", t]);
    }

    // Launches an app by its .desktop id (with or without the extension). Without hyde-shell, uses
    // `entry.execute()` when the DesktopEntry is given, else `gtk-launch`.
    function desktop(id, entry) {
        const d = String(id ?? "").replace(/\.desktop$/, "");
        if (d === "")
            return;
        if (hasHydeShell)
            Quickshell.execDetached(["hyde-shell", "app", "--", `${d}.desktop`]);
        else if (entry)
            entry.execute();
        else
            Quickshell.execDetached(["gtk-launch", d]);
    }

    // Copies `text` and pastes it into the focused window (see pasteWith).
    function pasteText(text) {
        const t = String(text ?? "");
        if (t !== "")
            pasteWith('wl-copy -- "$1"', t);
    }

    // Direct paste, like HyDE's paste_string (globalcontrol.sh): runs `copyScript` (a shell snippet
    // that fills the clipboard; `arg` is available to it as "$1", never interpolated), waits
    // Config.pickers.pasteDelayMs for the launcher to close and focus to return to the previous window,
    // then sends Ctrl+V with wtype — except for the window classes listed in
    // ${HYDE_STATE_HOME}/ignore.paste (terminals by default, where Ctrl+V does not paste).
    //
    // NOTE: sending Ctrl+V is ON PURPOSE: it is the "paste directly" feature of the emoji, glyph and
    // clipboard pickers, not a testing shortcut.
    function pasteWith(copyScript, arg) {
        const delay = Math.max(0, Config.pickers.pasteDelayMs) / 1000;
        Quickshell.execDetached(["sh", "-c", `${copyScript} || exit 0\n` + "command -v wtype >/dev/null || exit 0\n" + `sleep ${delay}\n` + "f=\"${HYDE_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyde}/ignore.paste\"\n" + "if [ -f \"$f\" ]; then ign=$(cat \"$f\"); else ign='kitty\norg.kde.konsole\nterminator\nXTerm\nAlacritty\nxterm-256color'; fi\n" + "c=$(hyprctl -j activewindow 2>/dev/null | jq -r '.initialClass // empty')\n" + "[ -n \"$c\" ] && printf '%b\\n' \"$ign\" | grep -qF -- \"$c\" && exit 0\n" + "wtype -M ctrl -k v -m ctrl\n", "sh", String(arg ?? "")]);
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyde-shell >/dev/null"]
        onExited: code => root.hasHydeShell = code === 0
    }
}
