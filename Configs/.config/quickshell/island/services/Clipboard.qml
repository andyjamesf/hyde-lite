pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history via cliphist (HyDE already records it with `wl-paste --watch cliphist store`).
// There is no native API: the list is read with `cliphist list` only when refresh() is called (no
// polling).
//
// NOTE: paste() sends Ctrl+V to the focused window (Launch.pasteWith) ON PURPOSE — it is the
// launcher's "paste directly" feature, not a testing shortcut.
Singleton {
    id: root

    property var entries: []   // [{ id, text, image }], most recent first
    property bool loading: false

    function refresh() {
        loading = true;
        lister.running = false;
        lister.running = true;
    }

    // Copy snippet for Launch.pasteWith / sh -c: cliphist returns the original content; images
    // carry their MIME type. The id is passed as a positional argument ($1), never interpolated.
    function _copyScript(entry) {
        const m = entry.text.match(/^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) /i);
        const mime = m ? `image/${m[1].toLowerCase().replace("jpg", "jpeg")}` : "";
        return mime ? `cliphist decode "$1" | wl-copy --type '${mime}'` : `cliphist decode "$1" | wl-copy`;
    }

    function copy(entry) {
        if (!entry)
            return;
        Quickshell.execDetached(["sh", "-c", _copyScript(entry), "sh", String(entry.id)]);
    }

    // Copies, then (once the launcher has closed and focus is back) pastes; see Launch.pasteWith.
    function paste(entry) {
        if (!entry)
            return;
        Launch.pasteWith(_copyScript(entry), String(entry.id));
    }

    function remove(entry) {
        if (!entry)
            return;
        // `cliphist delete` reads the line "id\tcontent" on stdin; the id is enough.
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t\\n' \"$1\" | cliphist delete", "sh", String(entry.id)]);
        entries = entries.filter(e => e.id !== entry.id);
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.indexOf("\t") > 0).map(l => {
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
        onExited: root.loading = false
        Component.onCompleted: Errors.watch(lister, "clipboard", "cliphist")
    }
}
