pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config
import qs.island.core

// Screenshots taken by the island (config/ScreenshotConfig.qml). take(mode) captures to a temporary
// file with HyDE's grimblast and shows it in the island (mode "screenshot", components/
// ScreenshotView.qml): copy(), save(), edit() or discard(). Leaving it alone applies
// ScreenshotConfig.whenLeft. Modes: "area", "freeze" (area on a frozen screen), "output" (the
// focused monitor), "screen" (all monitors).
Singleton {
    id: root

    // The capture on show (temporary file), "" when none.
    property string file: ""
    // Where it was saved, "" until then.
    property string savedPath: ""
    // Line under the preview: what just happened.
    property string status: ""
    // The capture has not been saved, edited or discarded yet.
    readonly property bool pending: file !== "" && savedPath === "" && !_handled
    property bool _handled: false

    readonly property string dir: Paths.expand(ScreenshotConfig.saveDir.replace("{pictures}", Paths.picturesDir))
    // HyDE's grimblast (the one in PATH when it is missing).
    readonly property string grimblast: `${Paths.home}/.local/lib/hyde/screenshot/grimblast`

    function _name() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return `${String(d.getFullYear()).slice(2)}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}h${p(d.getMinutes())}m${p(d.getSeconds())}s_screenshot.png`;
    }

    function take(mode) {
        if (capture.running)
            return;
        // A capture still on show is settled first (as if left alone).
        _settle();
        const m = mode === "freeze" ? "area" : (["area", "output", "screen"].includes(mode) ? mode : "area");
        capture.target = `${Paths.runtimeDir}/island-screenshot-${Date.now()}.png`;
        capture.name = _name();
        const tool = ["sh", "-c", `g="$1"; shift; command -v "$g" >/dev/null 2>&1 || g=grimblast; exec "$g" "$@"`, "sh", grimblast];
        capture.command = tool.concat(mode === "freeze" ? ["--freeze"] : []).concat(["save", m, capture.target]);
        capture.running = true;
    }

    function copy() {
        if (file === "")
            return;
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", savedPath || file]);
        status = "Copied to the clipboard";
        IslandController.resetCountdown(1600);
    }

    function save() {
        if (!pending)
            return;
        _handled = true;
        const dest = `${dir}/${capture.name}`;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && mv "$2" "$3"', "sh", dir, file, dest]);
        savedPath = dest;
        file = dest;
        status = `Saved to ${dir.replace(Paths.home, "~")}`;
        IslandController.resetCountdown(1600);
    }

    function edit() {
        if (file === "")
            return;
        const src = file;
        const dest = savedPath || `${dir}/${capture.name}`;
        _handled = true;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1"', "sh", dir]);
        Launch.run(ScreenshotConfig.editor.concat([src, ScreenshotConfig.outputFlag, dest]));
        _clear();
        IslandController.close();
    }

    function discard() {
        if (file === "")
            return;
        Quickshell.execDetached(["rm", "-f", file]);
        _handled = true;
        _clear();
        IslandController.close();
    }

    // Opens the capture in the image viewer (saving it first if needed).
    function open() {
        if (pending)
            save();
        Launch.open(savedPath);
    }

    function _settle() {
        if (pending) {
            if (ScreenshotConfig.whenLeft === "discard")
                Quickshell.execDetached(["rm", "-f", file]);
            else
                save();
        }
        _clear();
    }
    function _clear() {
        file = "";
        savedPath = "";
        status = "";
        _handled = false;
    }

    // The preview went away (time out, Esc, another mode): apply whenLeft.
    Connections {
        target: IslandController
        function onModeChanged() {
            if (IslandController.mode !== IslandState.screenshot && root.file !== "")
                root._settle();
        }
    }

    Process {
        id: capture
        property string target: ""
        property string name: ""
        onExited: code => {
            if (code !== 0) {
                // Any other non-zero code is also Esc in the selection, which is not a failure, so
                // only a missing tool is worth saying out loud.
                if (code === 127)
                    Errors.report("screenshot", "grimblast is not installed");
                return;
            }
            root._handled = false;
            root.savedPath = "";
            root.file = target;
            if (ScreenshotConfig.copyAtOnce) {
                Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", target]);
                root.status = "Copied to the clipboard";
            } else {
                root.status = "";
            }
            // Another surface is open (the preview cannot show): settle it at once.
            if (!IslandController.showTransient(IslandState.screenshot, null, ScreenshotConfig.previewMs))
                root._settle();
        }
    }
}
