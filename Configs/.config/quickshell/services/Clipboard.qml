pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist (the same one HyDE already records with wl-paste --watch).
// There is no native API: the list is read with `cliphist list` only when the launcher opens in clipboard mode.
Singleton {
    id: root

    property var entries: []   // [{ id, text, image }]
    property bool loading: false

    function refresh() {
        loading = true;
        lister.running = true;
    }

    // Copies the chosen entry to the clipboard (cliphist returns the original content).
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", `cliphist decode '${entry.id}' | wl-copy`]);
    }

    function remove(entry) {
        Quickshell.execDetached(["sh", "-c", `printf '%s\\t%s' '${entry.id}' '' | cliphist delete`]);
        entries = entries.filter(e => e.id !== entry.id);
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l !== "").map(l => {
                    const tab = l.indexOf("\t");
                    const body = l.slice(tab + 1);
                    return {
                        id: l.slice(0, tab),
                        text: body,
                        image: /^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) /i.test(body)
                    };
                });
                root.loading = false;
            }
        }
    }
}
