pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The collapsed island (the clock pill) and the space it reserves at the top of each screen.
// `height`, `hoverExpand` and `hidden` can be changed in the Settings screen / by IPC (Prefs keys
// "pill.height", "pill.hoverExpand", "pill.hidden"); the values here are the defaults.
Singleton {
    id: root

    // Height of the pill in pixels; most other sizes scale from it. Range 30–51, default 36.
    readonly property int height: Prefs.get("pill.height", 36)
    // Minimum width of the pill in pixels (it grows with its content). Default 128.
    readonly property int minWidth: 128
    // Distance from the top edge of the screen to the pill, in pixels. 0–24, default 6 (Settings screen).
    readonly property int topMargin: Prefs.get("pill.topMargin", 6)
    // Space left between the bottom of the island's window and the bottom edge of the screen, in
    // pixels. It bounds how tall the island can grow: a surface or a transient taller than the
    // screen less this margin is clipped by the window. A margin, so it stays the same number of
    // pixels on every screen rather than scaling with it. Default 40.
    readonly property int bottomMargin: 40
    // Horizontal padding inside the pill, as a fraction of `height` (0.55 × 36 ≈ 20 px). 0–1,
    // default 0.55.
    readonly property real paddingFactor: 0.55
    // Hovering the pill expands it (workspaces, media, date, status). Default false: the expanded
    // island only opens with a click on the pill (and closes with another), so it never covers
    // the windows by accident. The Settings screen can turn hover back on.
    readonly property bool hoverExpand: Prefs.get("pill.hoverExpand", false)
    // After the pointer leaves, the expanded island waits this long before collapsing (avoids
    // flicker when the pointer brushes the edge). Milliseconds, 0–2000, default 220.
    readonly property int hoverCollapseDelay: 220
    // Hidden pill (Super+, or `island hide`): reserves no space and windows go up to the top edge;
    // surfaces and OSDs still appear. Default false.
    readonly property bool hidden: Prefs.get("pill.hidden", false)

    // Equalizer shown next to the clock while music plays.
    // Width of each bar in pixels. Default 3.
    readonly property real eqBarWidth: 3
    // Space between bars in pixels. Default 2.
    readonly property real eqBarGap: 2
    // Maximum bar height, as a fraction of `height`. 0–1, default 0.42.
    readonly property real eqHeightFactor: 0.42
    // Oscillation period of each bar in milliseconds (one entry per bar; different values keep the
    // bars out of phase). Default [620, 860, 520].
    readonly property var eqPeriods: [620, 860, 520]
    // Space between the clock and the equalizer in pixels. Default 8.
    readonly property real eqLeadingGap: 8

    // Derived (not settings) ----------------------------------------------------------------------

    // Hyprland's gap around windows (general:gaps_out, top side), read at startup.
    property int gapsOut: 5
    // Space each screen reserves for the collapsed pill. Hyprland still adds gaps_out below it,
    // so that is subtracted: the space between the pill and the windows equals the top margin.
    readonly property int reservedHeight: Math.max(0, height + 2 * topMargin - gapsOut)

    function setHidden(on) {
        Prefs.set("pill.hidden", on);
    }

    Process {
        running: true
        command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const css = String(JSON.parse(text).css ?? "").trim().split(/\s+/);
                    const top = parseInt(css[0]);
                    if (!isNaN(top))
                        root.gapsOut = top;
                } catch (e) {}
            }
        }
    }
}
