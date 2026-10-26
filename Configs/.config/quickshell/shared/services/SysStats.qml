pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PC statistics, from shared/scripts/sysstats.py: load, memory, temperature, disks, network and
// the processes using the most of each. Shared by every UI of this configuration that shows them
// — the control centre's System page in either shell, and the island's detached window.
//
// The script only runs while something is showing the numbers, every `interval` seconds, so a
// control centre that is closed costs nothing. A shell that can detach the view into its own
// window keeps it alive through `keepRunning`; where the settings of such a window live is that
// shell's business, not this one's.
Singleton {
    id: root

    // The System page is on screen (set by it).
    property bool pageShown: false
    // The last reading (see scripts/sysstats.py), null until the first arrives.
    property var data: null
    // Process list order, shared by the page and the window: "cpu" or "memory".
    property string sortBy: "cpu"

    // Set by a shell that is showing the numbers somewhere of its own (the island's detached
    // window), so the script keeps running with the control centre closed.
    property bool keepRunning: false

    // Seconds between readings.
    property int interval: 2

    // A reading that could not be taken or could not be read; the shell says where it goes.
    signal readFailed(string message)

    // 1.2 GB, 850 MB…
    function bytes(n) {
        if (!(n > 0))
            return "0 B";
        const u = ["B", "KB", "MB", "GB", "TB"];
        const i = Math.min(u.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
        const v = n / Math.pow(1024, i);
        return `${v >= 100 || i === 0 ? Math.round(v) : v.toFixed(1)} ${u[i]}`;
    }

    Process {
        id: stats
        command: ["python3", Quickshell.shellPath("shared/scripts/sysstats.py"), String(root.interval)]
        running: root.pageShown || root.keepRunning
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.data = JSON.parse(line);
                } catch (e) {
                    root.readFailed("sysstats.py sent a line that could not be read");
                }
            }
        }

        onExited: code => {
            if (code !== 0)
                root.readFailed(`sysstats.py stopped with code ${code}`);
        }
    }
}
