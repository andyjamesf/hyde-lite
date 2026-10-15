pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config as Config

// Window picker (HyDE's `rofi -show window`): every Hyprland window, in focus-history order. The
// window that had focus goes last, so Enter right away jumps to the previous one (like Alt+Tab).
// The live list comes from Hyprland.toplevels (windows open, close and change title while the picker
// is open); class, workspace and focus history come from `hyprctl clients -j`, read on every opening.
Singleton {
    id: root

    readonly property string name: "windows"
    readonly property string title: "Windows"
    readonly property string placeholder: "Search windows…"
    readonly property string glyph: "windows"
    readonly property bool loading: proc.running && clients.length === 0
    readonly property bool grid: false
    readonly property bool keepOpen: false

    // Result of the last `hyprctl clients -j`.
    property var clients: []
    // A read that came back empty or unparsable is retried once (hyprctl sometimes returns an
    // empty or truncated reply while windows are being mapped).
    property bool _retried: false

    // Address without "0x", to compare what Quickshell and hyprctl report.
    function normAddr(a) {
        return String(a ?? "").toLowerCase().replace(/^0x/, "");
    }

    // Never interrupts a read in progress (truncated text would not be valid JSON).
    function refresh() {
        if (!proc.running) {
            _retried = false;
            proc.running = true;
        }
    }

    function _parse(text) {
        const t = String(text ?? "").trim();
        let list = null;
        if (t.startsWith("[") && t.endsWith("]")) {
            try {
                list = JSON.parse(t);
            } catch (e) {
                list = null;
            }
        }
        if (Array.isArray(list)) {
            clients = list;
        } else if (!_retried) {
            _retried = true;
            retry.restart();
        } else {
            // Still no valid reply: keep the previous data (the live toplevels still list every window).
            console.info("pick windows: no valid reply from `hyprctl clients -j`, using live toplevels only");
        }
    }

    // One row per window: joins the live toplevel with the hyprctl data (if already there).
    function windows() {
        const byAddr = {};
        for (const c of clients)
            byAddr[normAddr(c.address)] = c;
        const out = [];
        const tops = Hyprland.toplevels?.values ?? [];
        for (const t of tops) {
            const addr = normAddr(t.address);
            if (addr === "")
                continue;
            const c = byAddr[addr];
            const ipc = t.lastIpcObject ?? {};
            // Hidden by the compositor (groups, minimised by plugins…): left out.
            if (c !== undefined && (c.mapped === false || c.hidden === true))
                continue;
            const ws = t.workspace;
            out.push({
                "addr": addr,
                "title": t.title || c?.title || "",
                "cls": c?.class || ipc.class || "",
                "wsId": ws?.id ?? c?.workspace?.id ?? 0,
                "wsName": ws?.name ?? c?.workspace?.name ?? "",
                "history": c?.focusHistoryID ?? ipc.focusHistoryID ?? 1000
            });
        }
        // Focus history (the focused one last); without history, workspace then title.
        const rank = w => w.history === 0 ? 100000 : w.history;
        return out.sort((a, b) => rank(a) - rank(b) || a.wsId - b.wsId || a.title.localeCompare(b.title));
    }

    function workspaceLabel(w) {
        if (w.wsId < 0)
            return w.wsName.replace(/^special:/, "special ");
        return `workspace ${w.wsName || w.wsId}`;
    }

    function iconFor(cls) {
        if (!cls)
            return "";
        const entry = DesktopEntries.heuristicLookup(cls);
        return entry?.icon || cls.toLowerCase();
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const list = windows();
        const scored = [];
        for (let i = 0; i < list.length; ++i) {
            const w = list[i];
            const s = q === "" ? 1 : Math.max(Fuzzy.score(q, w.title), Fuzzy.score(q, w.cls) * 0.9, Fuzzy.score(q, workspaceLabel(w)) * 0.5);
            if (s > 0)
                scored.push({
                    w,
                    s,
                    i
                });
        }
        return scored.sort((a, b) => b.s - a.s || a.i - b.i).slice(0, Config.PickersConfig.maxResults.windows ?? 200).map(x => ({
                    "key": x.w.addr,
                    "title": x.w.title || x.w.cls || "Untitled",
                    "subtitle": [x.w.cls, workspaceLabel(x.w)].filter(s => s !== "").join(" · "),
                    "icon": iconFor(x.w.cls),
                    "text": "",
                    "badge": x.w.history === 0 ? "current" : "",
                    "address": x.w.addr
                }));
    }

    // Focuses the window by address (Hyprland 0.56 Lua dispatcher, like HyDE's altab).
    function activate(item) {
        const addr = normAddr(item?.address);
        if (!/^[0-9a-f]+$/.test(addr))
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.focus({ window = "address:0x${addr}" })`]);
    }

    Process {
        id: proc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    // Short pause before the single retry.
    Timer {
        id: retry
        interval: 150
        onTriggered: if (!proc.running)
            proc.running = true
    }
}
