import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.bar.components
import qs.bar.services

// Bar layout editor (docs/bar-builder.md, PLAN 3.4): the three zones as rows of pills, each pill a list of
// widgets. Click a widget to select it, then move it, split its pill, merge the pill with the one before,
// send it to another zone or remove it; click a widget from "Not in this layout" to add it next to the
// selection (or as a new pill in the highlighted zone). Save writes the owner's layouts file, which the
// shell validates and applies like a hand edit. No drag and drop (later).
// Open with `qs ipc call bar edit`. Esc closes without saving.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property bool open: ShellState.barEditorOpen && (ShellState.barEditorScreen === "" || ShellState.barEditorScreen === modelData.name)
    readonly property var zones: ["left", "center", "right"]

    // The layout being edited: a copy of the current one, changed only by edit().
    property var draft: ({})
    property string layoutName: ""
    // Selected widget (zone, pill index, widget index in the pill); selW < 0 means none.
    property string selZone: ""
    property int selG: -1
    property int selW: -1
    // Zone that receives a widget added with nothing selected.
    property string targetZone: "right"
    readonly property bool hasSel: selZone !== "" && selW >= 0

    readonly property var used: {
        const out = [];
        for (const z of zones)
            for (const g of draft[z] ?? [])
                for (const w of g)
                    out.push(w);
        return out;
    }
    readonly property var available: BarWidgets.ids.filter(id => !used.includes(id))

    screen: modelData
    visible: true
    implicitWidth: 820
    implicitHeight: 600
    exclusiveZone: 0
    color: "transparent"
    mask: Region {
        item: win.open ? card : null
    }

    WlrLayershell.namespace: "quickshell:bareditor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Same as the power menu: the grab only starts once the window is open.
    property bool grabReady: false

    function init() {
        grabReady = false;
        if (open) {
            load();
            focusTimer.restart();
        }
    }
    Component.onCompleted: init()
    onOpenChanged: init()

    Timer {
        running: win.open && !win.grabReady
        interval: 60
        onTriggered: win.grabReady = true
    }
    Timer {
        id: focusTimer
        interval: 10
        onTriggered: card.forceActiveFocus()
    }
    HyprlandFocusGrab {
        windows: [win]
        active: win.open && win.grabReady
        onCleared: win.close()
    }

    function close() {
        ShellState.barEditorOpen = false;
    }

    function load() {
        layoutName = BarLayout.current;
        draft = JSON.parse(JSON.stringify(BarLayout.preset));
        deselect();
    }

    function deselect() {
        selZone = "";
        selG = -1;
        selW = -1;
    }

    function select(zone, g, w) {
        selZone = zone;
        selG = g;
        selW = w;
        targetZone = zone;
    }

    // Applies fn to a copy of the draft; pills left empty disappear.
    function edit(fn) {
        const d = JSON.parse(JSON.stringify(draft));
        fn(d);
        for (const z of zones)
            d[z] = (d[z] ?? []).filter(g => g.length > 0);
        draft = d;
    }

    function removeSel() {
        const z = selZone, g = selG, w = selW;
        edit(d => d[z][g].splice(w, 1));
        deselect();
    }

    // dir -1: towards the start, +1: towards the end. At the end of a pill the widget joins the next one.
    function moveSel(dir) {
        const z = selZone;
        let g = selG, w = selW;
        edit(d => {
            const groups = d[z], grp = groups[g], nw = w + dir;
            if (nw >= 0 && nw < grp.length) {
                [grp[w], grp[nw]] = [grp[nw], grp[w]];
                w = nw;
                return;
            }
            const ng = g + dir;
            if (ng < 0 || ng >= groups.length)
                return;
            const id = grp.splice(w, 1)[0];
            if (dir < 0) {
                groups[ng].push(id);
                w = groups[ng].length - 1;
                g = ng;
            } else {
                groups[ng].unshift(id);
                w = 0;
                // The pill we left disappears when empty, which shifts the one we joined down.
                g = grp.length === 0 ? ng - 1 : ng;
            }
        });
        selG = g;
        selW = w;
    }

    // The selected widget and the ones after it become a new pill.
    function splitSel() {
        if (selW <= 0)
            return;
        const z = selZone, g = selG, w = selW;
        edit(d => d[z].splice(g + 1, 0, d[z][g].splice(w)));
        selG = g + 1;
        selW = 0;
    }

    // The selected widget's pill joins the one before it.
    function mergeSel() {
        if (selG <= 0)
            return;
        const z = selZone, g = selG;
        let w = selW;
        edit(d => {
            w += d[z][g - 1].length;
            d[z][g - 1] = d[z][g - 1].concat(d[z][g]);
            d[z].splice(g, 1);
        });
        selG = g - 1;
        selW = w;
    }

    // The widget leaves its pill and becomes a pill of its own in another zone.
    function sendSel(zone) {
        if (zone === selZone)
            return;
        const z = selZone, g = selG, w = selW;
        let ng = 0;
        edit(d => {
            const id = d[z][g].splice(w, 1)[0];
            d[zone] = d[zone] ?? [];
            d[zone].push([id]);
            ng = d[zone].length - 1;
        });
        select(zone, ng, 0);
    }

    // After the selection, or as a new pill in the highlighted zone.
    function addWidget(id) {
        if (hasSel) {
            const z = selZone, g = selG, w = selW + 1;
            edit(d => d[z][g].splice(w, 0, id));
            selW = w;
            return;
        }
        const z = targetZone;
        let ng = 0;
        edit(d => {
            d[z] = d[z] ?? [];
            d[z].push([id]);
            ng = d[z].length - 1;
        });
        select(z, ng, 0);
    }

    function setHeight(step) {
        edit(d => d.height = Math.max(BarLayout.minHeight, Math.min(BarLayout.maxHeight, (d.height ?? BarLayout.layoutHeight) + step)));
    }

    function setStyle(style) {
        edit(d => d.style = style);
    }

    function nextPillStyle() {
        const ids = BarLayout.pillStyles.map(s => s.id);
        const i = ids.indexOf(draft.pillStyle ?? BarLayout.pillStyle);
        edit(d => d.pillStyle = ids[(i + 1) % ids.length]);
    }

    function save() {
        BarLayout.saveUserPreset(layoutName, draft);
        close();
    }

    function reset() {
        BarLayout.removeUserPreset(layoutName);
        close();
    }

    component Chip: Rectangle {
        id: chip

        property string text
        property bool selected: false
        property bool active: true
        signal clicked

        implicitWidth: label.implicitWidth + 22
        implicitHeight: 28
        radius: 14
        opacity: active ? 1 : 0.5
        // The theme's surface steps can be almost the same dark; a veil of the text colour lifts the chip
        // off whatever it sits on (card or pill) in any theme, light or dark.
        color: selected ? Theme.primary : Theme.blend(Theme.surfaceContainer, Theme.text, 0.14)
        border.width: selected ? 0 : 1
        border.color: Theme.alpha(Theme.text, 0.12)

        StyledText {
            id: label
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Theme.onPrimary : Theme.text
        }
        MouseArea {
            anchors.fill: parent
            enabled: chip.active
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: Theme.shapeXL
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.border
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        visible: win.open || opacity > 0
        focus: win.open

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
        Behavior on scale {
            NumberAnim {
                easing.bezierCurve: Anim.emphasized
            }
        }

        Keys.onEscapePressed: win.close()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    text: `Edit bar: ${win.draft.label ?? win.layoutName}`
                    font.pixelSize: Config.appearance.fontSize + 4
                    font.weight: Font.DemiBold
                }
                Item {
                    Layout.fillWidth: true
                }
                Chip {
                    text: "Back to shipped"
                    onClicked: win.reset()
                }
                Chip {
                    text: "Cancel"
                    onClicked: win.close()
                }
                Chip {
                    text: "Save"
                    selected: true
                    onClicked: win.save()
                }
            }

            // Style of the whole bar.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: "Height"
                }
                Chip {
                    text: "−"
                    onClicked: win.setHeight(-1)
                }
                StyledText {
                    text: `${win.draft.height ?? BarLayout.layoutHeight} px`
                    Layout.minimumWidth: 46
                    horizontalAlignment: Text.AlignHCenter
                }
                Chip {
                    text: "+"
                    onClicked: win.setHeight(1)
                }
                Item {
                    Layout.preferredWidth: 14
                }
                Chip {
                    text: "Islands"
                    selected: (win.draft.style ?? "islands") === "islands"
                    onClicked: win.setStyle("islands")
                }
                Chip {
                    text: "One strip"
                    selected: win.draft.style === "continuous"
                    onClicked: win.setStyle("continuous")
                }
                Item {
                    Layout.preferredWidth: 14
                }
                Chip {
                    text: `Pill: ${win.draft.pillStyle ?? BarLayout.pillStyle}`
                    onClicked: win.nextPillStyle()
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            // Zones.
            Repeater {
                model: win.zones

                ColumnLayout {
                    id: zoneCol

                    required property string modelData

                    Layout.fillWidth: true
                    spacing: 6

                    MouseArea {
                        Layout.preferredHeight: zoneLabel.implicitHeight + 4
                        Layout.preferredWidth: zoneLabel.implicitWidth
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.deselect();
                            win.targetZone = zoneCol.modelData;
                        }

                        StyledText {
                            id: zoneLabel
                            text: zoneCol.modelData.charAt(0).toUpperCase() + zoneCol.modelData.slice(1) + (win.targetZone === zoneCol.modelData && !win.hasSel ? "  (new widgets go here)" : "")
                            color: win.targetZone === zoneCol.modelData ? Theme.primary : Theme.textDim
                            font.weight: Font.DemiBold
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: win.draft[zoneCol.modelData] ?? []

                            Rectangle {
                                id: pill

                                required property var modelData
                                required property int index

                                implicitWidth: pillRow.implicitWidth + 16
                                implicitHeight: 40
                                radius: 20
                                color: Theme.blend(Theme.surfaceContainer, Theme.text, 0.05)
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.22)

                                Row {
                                    id: pillRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Repeater {
                                        model: pill.modelData

                                        Item {
                                            id: slot

                                            required property string modelData
                                            required property int index

                                            implicitWidth: widgetChip.implicitWidth
                                            implicitHeight: widgetChip.implicitHeight

                                            Chip {
                                                id: widgetChip
                                                text: BarWidgets.label(slot.modelData)
                                                selected: win.selZone === zoneCol.modelData && win.selG === pill.index && win.selW === slot.index
                                                onClicked: win.select(zoneCol.modelData, pill.index, slot.index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Actions on the selected widget.
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: win.hasSel ? 1 : 0.55

                StyledText {
                    text: win.hasSel ? `${BarWidgets.label(win.draft[win.selZone]?.[win.selG]?.[win.selW] ?? "")}:` : "Select a widget"
                    Layout.minimumWidth: 110
                }
                Chip {
                    text: "◀ Earlier"
                    active: win.hasSel
                    onClicked: win.moveSel(-1)
                }
                Chip {
                    text: "Later ▶"
                    active: win.hasSel
                    onClicked: win.moveSel(1)
                }
                Chip {
                    text: "Split pill here"
                    active: win.hasSel && win.selW > 0
                    onClicked: win.splitSel()
                }
                Chip {
                    text: "Join previous pill"
                    active: win.hasSel && win.selG > 0
                    onClicked: win.mergeSel()
                }
                Chip {
                    text: "Remove"
                    active: win.hasSel
                    onClicked: win.removeSel()
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: win.hasSel ? 1 : 0.55

                StyledText {
                    text: "Send to"
                    Layout.minimumWidth: 110
                }
                Repeater {
                    model: win.zones

                    Item {
                        id: sendSlot

                        required property string modelData

                        implicitWidth: sendChip.implicitWidth
                        implicitHeight: sendChip.implicitHeight

                        Chip {
                            id: sendChip
                            text: sendSlot.modelData.charAt(0).toUpperCase() + sendSlot.modelData.slice(1)
                            active: win.hasSel && sendSlot.modelData !== win.selZone
                            onClicked: win.sendSel(sendSlot.modelData)
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            StyledText {
                text: win.available.length > 0 ? "Not in this layout (click to add)" : "Every widget is in this layout"
                color: Theme.textDim
                font.weight: Font.DemiBold
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: win.available

                    Item {
                        id: availSlot

                        required property string modelData

                        implicitWidth: availChip.implicitWidth
                        implicitHeight: availChip.implicitHeight

                        Chip {
                            id: availChip
                            text: BarWidgets.label(availSlot.modelData)
                            onClicked: win.addWidget(availSlot.modelData)
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
