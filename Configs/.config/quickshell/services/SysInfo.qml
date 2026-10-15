pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// User, host and uptime (for the control center header).
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    // User picture (~/.face, the display managers' convention); empty if it doesn't exist.
    property string avatar: ""
    property string host: ""
    property int uptimeSeconds: 0
    readonly property string uptime: {
        const d = Math.floor(uptimeSeconds / 86400);
        const h = Math.floor(uptimeSeconds % 86400 / 3600);
        const m = Math.floor(uptimeSeconds % 3600 / 60);
        return d > 0 ? `${d} d ${h} h` : h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    // Only read when someone shows the value (the control center calls refresh() when opening).
    function refresh() {
        uptimeFile.reload();
    }

    FileView {
        id: face
        path: `${Quickshell.env("HOME")}/.face`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        // The number at the end forces the Image to load the new picture (otherwise it showed the cached one).
        onLoaded: root.avatar = `file://${path}?v=${Date.now()}`
        onLoadFailed: root.avatar = ""
    }

    // Changing the picture: the system file chooser (portal), and the chosen image is copied to
    // ~/.face (where display managers and the lock screen also look for it), after positioning it in the editor.
    function chooseAvatar() {
        if (!picker.running)
            picker.running = true;
    }

    Process {
        id: picker
        command: ["python3", Quickshell.shellPath("scripts/pick_file.py"), "Choose your photo", "Images:*.png;*.jpg;*.jpeg;*.webp;*.bmp", `${Quickshell.env("HOME")}/Pictures`]
        stdout: StdioCollector {
            onStreamFinished: {
                const src = text.trim();
                // The image opens in the editor, to position it in the circle before saving.
                if (src !== "") {
                    ShellState.avatarScreen = Hyprland.focusedMonitor?.name ?? "";
                    ShellState.avatarSource = src;
                }
            }
        }
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = Math.floor(parseFloat(text()))
    }
}
