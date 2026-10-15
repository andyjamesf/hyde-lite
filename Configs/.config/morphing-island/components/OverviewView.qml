// Delegates reach `root` from inside the Repeaters, so the scope is bound explicitly: with it
// every delegate declares what it takes with `required property` and nothing resolves by accident.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.core
import qs.services
import qs.theme

// Workspace overview: the workspaces of this screen as a grid of tiles, each window drawn where it
// really sits on the screen, from a capture of the window itself.
//
// Why the windows are placed by their real geometry instead of being listed: the point of an
// overview is to recognise a window by where it is, which a list throws away. A tile is the monitor
// scaled down, so the shape of your layout is the thing you navigate.
//
// Left click a window to go to it, middle click to close it, click the empty part of a tile to go to
// that workspace. Arrows or hjkl move the selection, 1-9 jump straight to a workspace, Enter goes to
// the selection. Esc is the island's own (IslandController.back).
//
// Sizes, how many columns, which workspaces always show and whether the captures are live:
// config/OverviewConfig.qml.
FocusScope {
    id: root

    // Screen this island is on, so the overview shows that screen's workspaces.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""
    readonly property var monitor: {
        const list = Hyprland.monitors?.values ?? [];
        return list.find(m => m.name === root.screenName) ?? Hyprland.focusedMonitor ?? null;
    }
    // Logical size of the monitor: what one tile is a miniature of.
    readonly property real monWidth: Math.max(1, (monitor?.width ?? 1920) / (monitor?.scale ?? 1))
    readonly property real monHeight: Math.max(1, (monitor?.height ?? 1080) / (monitor?.scale ?? 1))

    readonly property real tileW: Math.max(160, OverviewConfig.tileWidth)
    readonly property real tileH: Math.round(root.tileW * root.monHeight / root.monWidth)
    readonly property real scaleToTile: root.tileW / root.monWidth

    // [{ id, name, active, windows: [{ toplevel, x, y, w, h, cls, title }] }], sorted by id.
    // Special workspaces (negative ids) are left out: they are a different thing and the strip for
    // them is not built yet.
    readonly property var tiles: {
        const byId = {};
        for (const id of OverviewConfig.alwaysShow)
            byId[id] = {
                "id": id,
                "name": String(id),
                "windows": []
            };
        const activeId = root.monitor?.activeWorkspace?.id ?? -1;
        for (const t of Hyprland.toplevels?.values ?? []) {
            const ws = t.workspace;
            if (!ws || ws.id < 0)
                continue;
            if (OverviewConfig.perScreen && root.monitor && ws.monitor && ws.monitor.name !== root.monitor.name)
                continue;
            const cell = byId[ws.id] ?? (byId[ws.id] = {
                    "id": ws.id,
                    "name": ws.name || String(ws.id),
                    "windows": []
                });
            const o = t.lastIpcObject ?? {};
            const at = o.at ?? [0, 0];
            const size = o.size ?? [0, 0];
            cell.windows.push({
                "toplevel": t,
                // Window position relative to the monitor, in logical pixels.
                "x": (at[0] ?? 0) - (root.monitor?.x ?? 0),
                "y": (at[1] ?? 0) - (root.monitor?.y ?? 0),
                "w": Math.max(1, size[0] ?? 1),
                "h": Math.max(1, size[1] ?? 1),
                "cls": String(o.class ?? ""),
                "title": String(o.title ?? ""),
                // Canonical "0x..." form, which the dispatcher wants. Toplevel.address has no 0x.
                "address": String(o.address ?? "")
            });
        }
        const out = Object.values(byId).sort((a, b) => a.id - b.id);
        for (const cell of out)
            cell.active = cell.id === activeId;
        return out;
    }

    // Special workspaces (scratchpads), which the grid leaves out: [{ name, label, windows }].
    // `name` is without the "special:" prefix, which is what toggleSpecial takes.
    readonly property var specials: {
        if (!OverviewConfig.showSpecials)
            return [];
        const counts = {};
        for (const t of Hyprland.toplevels?.values ?? []) {
            const id = t.workspace?.id ?? 0;
            if (id < 0)
                counts[id] = (counts[id] ?? 0) + 1;
        }
        const out = [];
        for (const w of Hyprland.workspaces?.values ?? []) {
            if (w.id >= 0)
                continue;
            const label = String(w.name ?? "").replace(/^special:/, "");
            out.push({
                "name": label,
                "label": label,
                "windows": counts[w.id] ?? 0
            });
        }
        return out.sort((a, b) => a.label.localeCompare(b.label));
    }

    // First free name for a scratchpad made from a dropped window: stash, stash-2, stash-3...
    function freeSpecialName() {
        const base = OverviewConfig.newSpecialName;
        const taken = root.specials.map(s => s.name);
        if (!taken.includes(base))
            return base;
        for (let i = 2; i < 100; ++i)
            if (!taken.includes(`${base}-${i}`))
                return `${base}-${i}`;
        return `${base}-${Date.now()}`;
    }

    // Address of the window being dragged, "" when none. The drop handlers read this instead of
    // `drop.source`, which Qt types as a plain QObject: there is nothing on that type to reach the
    // window through, so going via the source means an unchecked hop through an untyped object.
    property string draggingAddress: ""

    readonly property bool stripShown: OverviewConfig.showSpecials

    // Breathing room between the content and the island's own rounded edge, and between the three
    // bands (heading, grid, scratchpads). Without them the tiles sat against the corners.
    readonly property int pad: 16
    readonly property int bandGap: 12
    readonly property real gridWidth: root.columns * root.tileW + (root.columns - 1) * OverviewConfig.gap

    readonly property int columns: Math.max(1, Math.min(8, OverviewConfig.columns))
    readonly property int rows: Math.max(1, Math.ceil(root.tiles.length / root.columns))

    // Index into `tiles` of the selected tile, for the keyboard.
    property int current: 0
    // Set once the selection has been moved by hand. Until then the selection follows the active
    // workspace, so opening the overview straight after a workspace switch still starts on the right
    // tile -- Hyprland's state takes a moment to settle and a one-shot read at creation caught it
    // stale. After the first key or hover it stops following, so nothing moves under the next press.
    property bool chosen: false
    onTilesChanged: if (!root.chosen)
        root.current = Math.max(0, root.tiles.findIndex(t => t.active))

    function select(i) {
        root.chosen = true;
        root.current = i;
    }

    implicitWidth: root.gridWidth + 2 * root.pad
    // From the column, so a hidden scratchpad row takes no height and nothing has to be added up
    // twice in two places.
    implicitHeight: body.implicitHeight + 2 * root.pad

    focus: true

    // The island does not hand the focus to its keyboard modes (core/Island.qml onModeChanged skips
    // them), so the view takes it itself, the way components/CalendarView.qml does.
    Component.onCompleted: {
        // Hyprland.workspaces stays empty until asked, the same way toplevels do.
        Hyprland.refreshWorkspaces();
        root.current = Math.max(0, root.tiles.findIndex(t => t.active));
        root.forceActiveFocus();
    }

    // Through closeThen, not close-and-dispatch: switching while the island still held the keyboard
    // was undone the moment it let go. core/IslandController.qml says why.
    function go(id) {
        IslandController.closeThen(() => Workspaces.focus(id));
    }

    function move(dx, dy) {
        const n = root.tiles.length;
        if (n === 0)
            return;
        let i = root.current + dx + dy * root.columns;
        if (dx !== 0) {
            // Left and right stay inside the row, so the selection never jumps a line sideways.
            const row = Math.floor(root.current / root.columns);
            const lo = row * root.columns, hi = Math.min(n, lo + root.columns) - 1;
            i = Math.max(lo, Math.min(hi, i));
        }
        root.select(Math.max(0, Math.min(n - 1, i)));
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
            root.move(-1, 0);
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
            root.move(1, 0);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
            root.move(0, -1);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
            root.move(0, 1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.go(root.tiles[root.current]?.id ?? 1);
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9)
            root.go(event.key - Qt.Key_0);
        else
            return;
        event.accepted = true;
    }

    // Under everything: keeps the focus on the view when a click lands on empty space.
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    Column {
        id: body

        x: root.pad
        y: root.pad
        width: root.gridWidth
        spacing: root.bandGap

    Text {
        id: heading
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.tiles[root.current]?.windows.length > 0 ? `Workspace ${root.tiles[root.current].name} · ${root.tiles[root.current].windows.length} window${root.tiles[root.current].windows.length === 1 ? "" : "s"}` : `Workspace ${root.tiles[root.current]?.name ?? ""} · empty`
        color: Theme.dim
        font.family: Appearance.font
        font.pixelSize: Appearance.fontSize - 1
    }

    Grid {
        id: grid
        anchors.horizontalCenter: parent.horizontalCenter
        columns: root.columns
        spacing: OverviewConfig.gap

        Repeater {
            model: root.tiles

            // One workspace: the monitor in miniature.
            Rectangle {
                id: tile

                required property int index
                required property var modelData

                readonly property bool selected: tile.index === root.current

                width: root.tileW
                height: root.tileH
                radius: 12
                color: Qt.alpha(Theme.surface, tile.modelData.active ? 0.9 : 0.55)
                border.width: tile.selected ? 2 : 1
                border.color: tile.selected ? Theme.accent : tile.modelData.active ? Theme.dim : Theme.border

                Behavior on border.color {
                    ColorAnimation {
                        duration: Animations.duration(120)
                    }
                }

                // Takes a window dragged from any tile, including this one.
                DropArea {
                    anchors.fill: parent
                    onEntered: root.select(tile.index)
                    onDropped: {
                        if (root.draggingAddress !== "")
                            Workspaces.moveWindow(root.draggingAddress, tile.modelData.id);
                    }
                }

                // Click on the empty part: go to this workspace.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.go(tile.modelData.id)
                    onEntered: root.select(tile.index)
                    hoverEnabled: true
                }

                // The workspace number, behind the windows.
                Text {
                    anchors.centerIn: parent
                    text: tile.modelData.name
                    color: Qt.alpha(Theme.foreground, tile.modelData.windows.length > 0 ? 0.07 : 0.22)
                    font.family: Appearance.font
                    font.pixelSize: Math.round(tile.height * 0.5)
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: tile.modelData.windows

                    // One window, where it really is on the screen.
                    Item {
                        id: win

                        required property var modelData

                        // Where it sits when it is not being dragged.
                        readonly property real homeX: Math.round(win.modelData.x * root.scaleToTile)
                        readonly property real homeY: Math.round(win.modelData.y * root.scaleToTile)

                        Drag.active: hover.drag.active
                        Drag.source: win
                        Drag.hotSpot.x: win.width / 2
                        Drag.hotSpot.y: win.height / 2
                        // Over the other tiles while it is being carried.
                        z: win.Drag.active ? 1000 : 0
                        opacity: win.Drag.active ? 0.75 : 1

                        readonly property real side: Math.min(win.width, win.height)
                        // A sliver of a screenshot says nothing, so below this a window is just a
                        // labelled rectangle.
                        readonly property bool previewable: win.side >= OverviewConfig.minPreviewSide

                        x: win.homeX
                        y: win.homeY
                        width: Math.max(6, Math.round(win.modelData.w * root.scaleToTile))
                        height: Math.max(6, Math.round(win.modelData.h * root.scaleToTile))

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Qt.alpha(Theme.background, 0.85)
                            border.width: 1
                            border.color: Qt.alpha(Theme.foreground, hover.containsMouse ? 0.5 : 0.18)
                            clip: true

                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: win.previewable && hasContent
                                captureSource: win.previewable ? win.modelData.toplevel.wayland : null
                                live: OverviewConfig.livePreviews
                                paintCursor: OverviewConfig.paintCursor
                            }

                            // While the first frame has not arrived, and for windows too small to
                            // preview: the app's icon.
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: Math.max(10, Math.round(win.side * 0.5))
                                source: Workspaces.iconFor(win.modelData.cls)
                                visible: !win.previewable
                            }
                        }

                        MouseArea {
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            // Drag a window onto another tile to send it to that workspace. The
                            // platform's drag threshold keeps a plain click a click.
                            drag.target: win
                            onEntered: root.select(tile.index)
                            // Marked here rather than from Drag.active: that is an attached
                            // property and takes no change handler of its own.
                            onPressed: root.draggingAddress = win.modelData.address ?? ""
                            onReleased: {
                                // Dragging assigns x and y, which breaks their bindings; put them
                                // back so the window returns home when it was dropped nowhere, and
                                // keeps following its real geometry afterwards.
                                win.x = Qt.binding(() => win.homeX);
                                win.y = Qt.binding(() => win.homeY);
                                // The drop is delivered while this release is still being handled,
                                // so the handlers must still see the address: clear it after.
                                Qt.callLater(() => root.draggingAddress = "");
                            }
                            onClicked: mouse => {
                                const wl = win.modelData.toplevel.wayland;
                                if (mouse.button === Qt.MiddleButton) {
                                    if (wl)
                                        wl.close();
                                    return;
                                }
                                if (wl)
                                    IslandController.closeThen(() => wl.activate());
                            }
                        }
                    }
                }
            }
        }
    }

    // Scratchpads: the special workspaces that exist, plus a tile that makes a new one out of the
    // window dropped on it. They are not part of the grid on purpose -- a special workspace has no
    // number and shows over whatever is already there -- so they get their own row under it.
    Row {
        id: strip

        visible: root.stripShown
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: OverviewConfig.gap

        Repeater {
            model: root.specials

            // One scratchpad: click shows or hides it, a dropped window goes into it.
            Rectangle {
                id: special

                required property var modelData

                width: Math.round(root.tileW * 0.62)
                height: OverviewConfig.specialHeight
                radius: 10
                color: Qt.alpha(Theme.surface, specialDrop.containsDrag ? 0.95 : 0.5)
                border.width: 1
                border.color: specialDrop.containsDrag ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: special.modelData.windows === 1 ? `${special.modelData.label} · 1 window` : `${special.modelData.label} · ${special.modelData.windows} windows`
                    color: Theme.dim
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSize - 2
                }

                DropArea {
                    id: specialDrop
                    anchors.fill: parent
                    onDropped: {
                        if (root.draggingAddress !== "")
                            Workspaces.moveWindow(root.draggingAddress, `special:${special.modelData.name}`);
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: IslandController.closeThen(() => Workspaces.toggleSpecial(special.modelData.name))
                }
            }
        }

        // Drop a window here to put it in a scratchpad of its own. With no scratchpads yet it says
        // so in words: a lone "+" square that does nothing when clicked reads as debris rather than
        // as somewhere to drop something.
        Rectangle {
            id: newSpecial

            width: root.specials.length > 0 ? Math.round(root.tileW * 0.4) : Math.round(root.tileW * 0.78)
            height: OverviewConfig.specialHeight
            radius: 10
            color: Qt.alpha(Theme.surface, newDrop.containsDrag ? 0.95 : 0.3)
            border.width: 1
            border.color: newDrop.containsDrag ? Theme.accent : Qt.alpha(Theme.border, 0.6)

            Text {
                anchors.centerIn: parent
                text: newDrop.containsDrag ? `new ${OverviewConfig.newSpecialName}` : root.specials.length > 0 ? "+" : "+  drop a window for a scratchpad"
                color: newDrop.containsDrag ? Theme.accent : Qt.alpha(Theme.foreground, 0.35)
                font.family: Appearance.font
                font.pixelSize: root.specials.length > 0 && !newDrop.containsDrag ? Appearance.fontSize + 4 : Appearance.fontSize - 2
            }

            DropArea {
                id: newDrop
                anchors.fill: parent
                onDropped: {
                    if (root.draggingAddress !== "")
                        Workspaces.moveWindow(root.draggingAddress, `special:${root.freeSpecialName()}`);
                }
            }
        }
    }
    }
}
