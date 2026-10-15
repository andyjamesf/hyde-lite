pragma Singleton
import QtQuick
import Quickshell

// Workspace overview (IslandState.overview, components/OverviewView.qml): every workspace of the
// focused screen as a tile, each window inside it drawn where it really is, from a live capture.
// Opened with $mod+D or `island open overview`.
Singleton {
    // Tiles per row. The rows follow from how many workspaces there are. 1-8, default 3.
    readonly property int columns: 3
    // Width of one tile in pixels; the height follows the screen's aspect ratio. 160-640,
    // default 300.
    readonly property int tileWidth: 300
    // Gap between tiles in pixels. Default 12.
    readonly property int gap: 12
    // Workspaces always shown, even with nothing on them, so the grid does not jump around as
    // windows come and go. The ones with windows are added to these. Default 1-9, which is what
    // the Hyprland config binds to $mod+1..9.
    readonly property var alwaysShow: [1, 2, 3, 4, 5, 6, 7, 8, 9]
    // Only the workspaces of the screen the overview is on. false shows every workspace.
    // Default true.
    readonly property bool perScreen: true
    // Live captures: the previews move as the windows do. They cost memory while the overview is
    // open, and it is only open while you look at it, so this is on by default. false captures each
    // window once when the overview opens, which is cheaper on a machine with many windows.
    readonly property bool livePreviews: true
    // Draw the mouse cursor inside the previews. Default false.
    readonly property bool paintCursor: false
    // Strip of special workspaces (scratchpads) under the grid: the ones that exist, plus a tile
    // that makes a new one from the window dropped on it. false hides the strip. Default true.
    readonly property bool showSpecials: true
    // Height of a tile in that strip, in pixels. Default 54.
    readonly property int specialHeight: 54
    // Name given to a special workspace made by dropping a window on the "+" tile. The second one
    // becomes "stash-2", the third "stash-3", and so on. Default "stash".
    readonly property string newSpecialName: "stash"
    // Smallest side a window preview may have in a tile, in pixels: below this a window is a plain
    // rectangle with its icon instead of a capture, which a 3 px sliver of a screenshot is not
    // useful at. Default 22.
    readonly property int minPreviewSide: 22
}
