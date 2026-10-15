pragma Singleton
import QtQuick
import Quickshell

// Workspace indicator: every workspace of this screen that has windows (plus the one you are on),
// each with its number and the icons of its apps; the current one is highlighted. Click one to go
// there, scroll over it to step through them. (Named WorkspacesConfig because
// services/Workspaces.qml is the service.)
//
// With the clock pill showing, it is a small pill of its own (at the screen's left edge, or next to
// the clock); when the island expands (hover or pin) it slides into it and shows in the expanded
// island's left zone.
Singleton {
    // Show the indicator at all. Default true.
    readonly property bool enabled: true
    // Also show it inside the expanded island. Default true.
    readonly property bool inExpanded: true

    // Where the indicator pill sits: "left" = the screen's left edge, "clock" = just left of the
    // clock pill. Default "left".
    readonly property string placement: "left"
    // Distance from the screen's left edge ("left" placement), in pixels. Default 12.
    readonly property int edgeMargin: 12
    // Space between the indicator pill and the clock pill ("clock" placement), in pixels. Default 8.
    readonly property int gap: 8
    // Inner padding of the indicator pill at each end, in pixels. Default 10.
    readonly property int padding: 10
    // Space between two workspaces, in pixels. Default 4.
    readonly property int spacing: 4

    // App icons shown per workspace; more windows show as "+N". 0–10, default 3.
    readonly property int maxIcons: 3
    // Show one icon per app, however many of its windows are open there. Default true.
    readonly property bool groupApps: true
    // App icon size as a fraction of Pill.height. 0–1, default 0.46.
    readonly property real iconFactor: 0.46

    // Workspaces whose windows are all on another screen are not shown here. Default true (each
    // screen shows its own). false = every screen lists all workspaces.
    readonly property bool perScreen: true
}
