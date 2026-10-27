pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland


// Workspaces and the windows on them, live from Hyprland's event socket (no polling), shared by
// every UI of this configuration.
//
// The island's service, with what the bar's (called Hypr) had of its own: the plain sorted list of
// workspaces, the active window, the windows on a given workspace, and a focus() that also takes a
// relative target such as "e+1", which is what a scroll on the bar's indicator sends. The island's
// half brought the per-screen grouping, moving a window, the special workspaces and stepping.
//
// Windows come from Hyprland.toplevels. Their class (which gives the app icon) is in lastIpcObject,
// which Quickshell only fills after refreshToplevels(): that is asked for whenever a window opens
// or changes class.
Singleton {
    id: root

    // What a shell configures (the island from config/WorkspacesConfig.qml); the defaults are its.
    property bool perScreen: true
    property bool groupApps: true
    property int maxIcons: 4

    // The plain list the bar's indicator draws: normal workspaces only (special ones have a
    // negative id), in order.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel

    // The windows on one workspace.
    function toplevelsOn(workspaceId) {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === workspaceId);
    }

    // The application id of a window, wherever Hyprland happens to have put it.
    function appIdOf(toplevel) {
        return toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "";
    }

    // Workspaces to show on the screen named `screenName`, sorted by number:
    // [{ id, name, active, apps: [{ cls, icon, count }], extra }]. `extra` = windows beyond
    // Workspaces.maxIcons. The active workspace of that screen is always included.
    function forScreen(screenName) {
        const monitors = Hyprland.monitors?.values ?? [];
        const mon = monitors.find(m => m.name === screenName) ?? Hyprland.focusedMonitor;
        const activeId = mon?.activeWorkspace?.id ?? -1;
        const byId = {};
        const ensure = (id, name) => byId[id] ?? (byId[id] = {
                id: id,
                name: name || String(id),
                active: id === activeId,
                apps: [],
                windows: 0
            });
        for (const t of Hyprland.toplevels?.values ?? []) {
            const ws = t.workspace;
            // Special workspaces (scratchpads) have negative ids.
            if (!ws || ws.id < 0)
                continue;
            if (root.perScreen && mon && ws.monitor && ws.monitor.name !== mon.name)
                continue;
            const w = ensure(ws.id, ws.name);
            const cls = String(t.lastIpcObject?.class ?? "");
            w.windows++;
            const same = root.groupApps ? w.apps.find(a => a.cls === cls) : undefined;
            if (same)
                same.count++;
            else
                w.apps.push({
                    cls: cls,
                    icon: iconFor(cls),
                    count: 1
                });
        }
        if (activeId > 0)
            ensure(activeId, mon?.activeWorkspace?.name);
        const out = Object.values(byId).sort((a, b) => a.id - b.id);
        const max = Math.max(0, root.maxIcons);
        for (const w of out) {
            w.extra = Math.max(0, w.apps.length - max);
            w.apps = w.apps.slice(0, max);
        }
        return out;
    }

    // Goes to workspace `id` (the same dispatcher as HyDE's Super+<number>).
    // Takes a workspace number, or a relative target Hyprland understands ("e+1", "e-1", a name).
    // The configuration here is Lua, where dispatchers are `hl.dsp.*` expressions; the plain form
    // is kept for a configuration that is not.
    function focus(target): void {
        const t = typeof target === "number" ? (target > 0 ? String(target) : "") : String(target ?? "");
        if (t === "")
            return;
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({workspace="${t}"})` : `workspace ${t}`);
    }

    // Moves one window to a workspace without going there with it: `follow = false`. Hyprland's
    // `silent` key is accepted and then ignored by the Lua dispatcher, `follow` is the one that
    // works. `workspace` is a number, or a name such as "special:stash".
    function moveWindow(address, workspace) {
        if (!address)
            return;
        const target = typeof workspace === "number" ? String(workspace) : `"${workspace}"`;
        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${target}, follow = false, window = "address:${address}" })`);
    }

    // Shows or hides a special workspace (a scratchpad). `name` is without the "special:" prefix:
    // the dispatcher takes it positionally, and a table with a `name` key is ignored, which quietly
    // toggles the default "special" one instead.
    function toggleSpecial(name) {
        if (!name)
            return;
        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${name}")`);
    }

    // Next/previous workspace among `list` (forScreen's result), relative to the active one.
    function step(list, delta) {
        if (!list || list.length === 0)
            return;
        const i = Math.max(0, list.findIndex(w => w.active));
        focus(list[(i + delta + list.length) % list.length].id);
    }

    // App icon for a window class: the desktop entry's icon, else the class itself.
    function iconFor(cls) {
        if (!cls)
            return "";
        const entry = DesktopEntries.heuristicLookup(cls);
        const name = entry?.icon || cls.toLowerCase();
        return name.startsWith("/") ? "file://" + name : (Quickshell.iconPath(name, true) ?? "");
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "movewindowv2", "closewindow"].includes(event.name))
                refreshTimer.restart();
        }
    }

    // Several events arrive together (open + move): refresh once. Not on title changes: a terminal
    // that animates its title (a spinner) would trigger a `j/clients` read several times a second,
    // and Quickshell already tracks titles through the toplevel handle.
    Timer {
        id: refreshTimer
        interval: 60
        onTriggered: Hyprland.refreshToplevels()
    }

    Component.onCompleted: Hyprland.refreshToplevels()
}
