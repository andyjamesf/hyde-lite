pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Who and how long (the control center header): user name, time since boot and the avatar
// (~/.face, also used by the lock and login screens). chooseAvatar() opens the file chooser and
// copies the picture to ~/.face.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string avatar: `${Paths.home}/.face`
    // Bumped when the avatar changes, so images showing it reload.
    property int avatarVersion: 0

    property int uptimeSeconds: 0
    // "3 h 12 min", "2 d 4 h", "45 min".
    readonly property string uptime: {
        const d = Math.floor(uptimeSeconds / 86400);
        const h = Math.floor(uptimeSeconds % 86400 / 3600);
        const m = Math.floor(uptimeSeconds % 3600 / 60);
        if (d > 0)
            return `${d} d ${h} h`;
        if (h > 0)
            return `${h} h ${m} min`;
        return `${m} min`;
    }

    function chooseAvatar() {
        if (!picker.running)
            picker.running = true;
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = Math.floor(parseFloat(text()))
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    Process {
        id: picker
        command: ["python3", Quickshell.shellPath("scripts/pick_file.py"), "Your picture", "Images:*.png;*.jpg;*.jpeg;*.webp"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path === "")
                    return;
                copier.command = ["cp", "-f", path, root.avatar];
                copier.running = true;
            }
        }
    }
    Process {
        id: copier
        onExited: code => {
            if (code !== 0)
                return;
            root.avatarVersion++;
            // The login screen gets the new picture too.
            SddmTheme.sync();
        }
    }
}
