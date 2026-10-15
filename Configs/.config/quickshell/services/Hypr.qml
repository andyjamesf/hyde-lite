pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland state the widgets need, already filtered and sorted.
Singleton {
    id: root

    // Normal workspaces (special ones have a negative id), in order.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel

    // The Hyprland config is in Lua, where dispatchers are `hl.dsp.*` expressions.
    function dispatchFocusWorkspace(target) {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({workspace="${target}"})` : `workspace ${target}`);
    }

    function toplevelsOn(workspaceId) {
        return Hyprland.toplevels.values.filter(t => t.workspace?.id === workspaceId);
    }

    function appIdOf(toplevel) {
        return toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class || "";
    }
}
