pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Who and how long: the user name, the host, the time since boot and the user picture — what a
// control centre header shows. Shared by every UI of this configuration.
//
// The picture is ~/.face, the convention display managers and lock screens read, and the file is
// watched: whoever writes it (this service, the bar's picture editor, anything else) makes
// `avatarVersion` tick and `avatarUrl` change, so an Image showing it reloads instead of keeping
// the cached one.
//
// Choosing a picture is where the two UIs genuinely differ, so it is split: this service opens the
// file chooser and announces the file with `avatarFilePicked`; what happens next belongs to the
// shell. The bar opens its editor to position the picture in the circle before saving; the island
// calls applyAvatar() and tells the login screen. Neither behaviour had to move here for the data
// to be shared.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    property string host: ""
    property int uptimeSeconds: 0

    // The file itself, and a URL that changes whenever it does.
    readonly property string avatar: `${Quickshell.env("HOME")}/.face`
    readonly property string avatarUrl: avatarExists ? `file://${avatar}?v=${avatarVersion}` : ""
    property bool avatarExists: false
    // Bumped on every change of the file, so images showing it reload.
    property int avatarVersion: 0

    // A file chooser came back with this picture; the shell decides what to do with it.
    signal avatarFilePicked(string path)
    // ~/.face changed, whoever wrote it. Not called avatarChanged: QML already gives every
    // property one of those, and declaring it again stops the whole file from loading.
    signal avatarFileChanged

    // "3 h 12 min", "2 d 4 h", "45 min".
    readonly property string uptime: {
        const m = Math.floor(uptimeSeconds / 60) % 60;
        const h = Math.floor(uptimeSeconds / 3600) % 24;
        const d = Math.floor(uptimeSeconds / 86400);
        if (d > 0)
            return `${d} d ${h} h`;
        if (h > 0)
            return `${h} h ${m} min`;
        return `${m} min`;
    }

    // The uptime refreshes itself every minute; this is for a panel that wants it exact on opening.
    function refresh(): void {
        uptimeFile.reload();
    }

    // Opens the system file chooser (through the portal). The answer arrives as avatarFilePicked.
    function chooseAvatar(): void {
        if (!picker.running)
            picker.running = true;
    }

    // Puts a picture in place as it is. The bar's editor writes ~/.face itself instead, after
    // positioning the image; either way the watcher below notices.
    function applyAvatar(path: string): void {
        if (path !== "")
            copier.exec(["cp", "-f", path, avatar]);
    }

    FileView {
        id: face
        path: root.avatar
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.avatarExists = true;
            root.avatarVersion++;
            root.avatarFileChanged();
        }
        onLoadFailed: root.avatarExists = false
    }

    Process {
        id: picker
        command: ["python3", Quickshell.shellPath("shared/scripts/pick_file.py"), "Choose your photo", "Images:*.png;*.jpg;*.jpeg;*.webp;*.bmp", `${Quickshell.env("HOME")}/Pictures`]
        stdout: StdioCollector {
            onStreamFinished: {
                const src = text.trim();
                if (src !== "")
                    root.avatarFilePicked(src);
            }
        }
    }

    Process {
        id: copier
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.host = text().trim()
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
}
