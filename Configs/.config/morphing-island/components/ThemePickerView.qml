import QtQuick
import qs.config
import qs.core
import qs.theme

// Theme picker in the island ("theme" mode): a grid of swatches by section (Dynamic, Dark, Light,
// E-ink). Clicking applies the theme at once (and it is saved as the Prefs key "theme.name"); the
// island follows with Theme's colour transition. New palettes: theme/Palettes.qml.
// Keyboard: arrows move the ring · Enter/Space applies · Home/End · Esc closes (IslandController.back()).
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through ModeSlot).
    property bool open: false

    readonly property real islandRadius: 26
    readonly property int columns: 5
    readonly property int pad: 20
    readonly property int gap: 12
    readonly property real cardWidth: (implicitWidth - 2 * pad - (columns - 1) * gap) / columns

    // Grid sections. They only depend on fixed names (the grid is not rebuilt when the dynamic colours
    // change; the swatches update by themselves).
    readonly property var sections: {
        const defs = [
            {
                title: "Dynamic",
                names: Palettes.dynamicNames
            },
            {
                title: "Dark",
                names: Palettes.list.filter(p => p.kind === "dark").map(p => p.name)
            },
            {
                title: "Light",
                names: Palettes.list.filter(p => p.kind === "light").map(p => p.name)
            },
            {
                title: "E-ink",
                names: Palettes.list.filter(p => p.kind === "eink").map(p => p.name)
            }
        ];
        const out = [];
        let row = 0, index = 0;
        for (const d of defs) {
            if (d.names.length === 0)
                continue;
            out.push({
                title: d.title,
                names: d.names,
                row: row,
                index: index
            });
            row += Math.ceil(d.names.length / columns);
            index += d.names.length;
        }
        return out;
    }
    // All swatches in order, with the (global) row and column of each one, for the arrow keys.
    readonly property var flat: sections.reduce((acc, s) => acc.concat(s.names.map((n, j) => ({
                    name: n,
                    row: s.row + Math.floor(j / columns),
                    col: j % columns
                }))), [])

    // Swatch with the keyboard ring.
    property int current: 0
    // The ring only shows after using the keyboard.
    property bool keyNav: false

    readonly property string currentName: flat[current]?.name ?? ""
    readonly property string detail: {
        const p = Theme.preview(currentName);
        if (currentName === Palettes.dynamicNames[0])
            return p.available ? `from ${Palettes.wallpaperSource}` : "unavailable";
        if (currentName === Palettes.dynamicNames[1])
            return p.available ? "from waybar theme" : "unavailable";
        return p.kind === "eink" ? "e-ink" : p.kind;
    }

    focus: true
    implicitWidth: 560
    implicitHeight: body.y + body.implicitHeight + pad

    onOpenChanged: if (open)
        reset()
    Component.onCompleted: if (open)
        reset()

    // Every opening starts on the active theme, without the keyboard ring.
    function reset() {
        const i = flat.findIndex(e => e.name === ThemeConfig.name);
        current = Math.max(0, i);
        keyNav = false;
        // The window's keyboard focus only arrives a moment later (and the island still reclaims it
        // when changing mode): try again after that.
        focusRetry.start();
    }

    function apply(i) {
        const e = flat[i];
        if (!e || !Theme.preview(e.name).available)
            return;
        ThemeConfig.setTheme(e.name);
    }

    // Arrow up/down: same column in the neighbouring row (or the last one of that row, if short).
    function moveRow(delta) {
        const here = flat[current];
        if (!here)
            return;
        const row = flat.filter(e => e.row === here.row + delta);
        if (row.length === 0)
            return;
        const target = row[Math.min(here.col, row.length - 1)];
        current = flat.indexOf(target);
    }

    function move(delta) {
        current = Math.max(0, Math.min(flat.length - 1, current + delta));
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            break;
        case Qt.Key_Right:
            move(1);
            break;
        case Qt.Key_Up:
            moveRow(-1);
            break;
        case Qt.Key_Down:
            moveRow(1);
            break;
        case Qt.Key_Home:
            current = 0;
            break;
        case Qt.Key_End:
            current = flat.length - 1;
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            apply(current);
            break;
        case Qt.Key_Escape:
            IslandController.back();
            break;
        default:
            return;
        }
        keyNav = event.key !== Qt.Key_Escape;
        event.accepted = true;
    }

    FocusRetry {
        id: focusRetry
        target: root
        when: root.open
    }

    // Under everything: swallows clicks outside the swatches and gives the focus back to the picker.
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    // Header: title on the left, current swatch on the right.
    Item {
        id: header
        x: root.pad
        y: 14
        width: root.implicitWidth - 2 * root.pad
        height: 28

        Label {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Theme"
            font.pixelSize: Appearance.fontSize + 3
            font.weight: Font.DemiBold
        }

        Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.6)
            horizontalAlignment: Text.AlignRight
            text: `${root.currentName} · ${root.detail}`
            color: Theme.dim
        }
    }

    Column {
        id: body
        x: root.pad
        y: header.y + header.height + 8
        width: root.implicitWidth - 2 * root.pad
        spacing: 12

        Repeater {
            model: root.sections

            Column {
                id: section
                required property var modelData
                width: parent.width
                spacing: 6

                Label {
                    text: section.modelData.title
                    color: Theme.faint
                    font.pixelSize: Appearance.fontSize - 2
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.6
                    height: 16
                }

                Grid {
                    columns: root.columns
                    columnSpacing: root.gap
                    rowSpacing: 12

                    Repeater {
                        model: section.modelData.names

                        ThemeSwatch {
                            required property string modelData
                            required property int index
                            readonly property int flatIndex: section.modelData.index + index
                            width: root.cardWidth
                            name: modelData
                            active: ThemeConfig.name === modelData
                            focused: root.keyNav && root.current === flatIndex
                            onEntered: root.current = flatIndex
                            onClicked: {
                                root.current = flatIndex;
                                root.apply(flatIndex);
                            }
                        }
                    }
                }
            }
        }
    }
}
