import QtQuick
import qs.config
import qs.services
import qs.theme

// Editor for an ordered list of icon ids stored in prefs.json (statusPill.icons, expanded.extraButtons).
// Click an icon to select it, then move it earlier or later or remove it; click one under "Add" to put it
// at the end. "Default" drops the override, so the config file's list applies again. Ids that are not in
// `choices` (a plugin's) are shown by their id and can be moved and removed like the others.
// Keyboard (from SettingsView): left/right select the previous/next icon.
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    // Prefs key the list is written to.
    property string prefKey: ""
    // The list in effect (the config singleton, which already follows prefs.json).
    property var current: []
    // [{ id, label }] for every id this list can show.
    property var choices: []
    // Keyboard ring, set by SettingsView.
    property bool focused: false
    // Index of the selected icon, -1 = none.
    property int selected: -1

    signal triggered
    signal adjustRequested(int direction)
    signal entered
    signal edited(var list)

    // List edits, pure so they can be tested on their own (tools/tests/test_icon_list_editor.py).
    function movedItem(list, i, dir) {
        const j = i + dir;
        if (i < 0 || i >= list.length || j < 0 || j >= list.length)
            return list.slice();
        const out = list.slice();
        [out[i], out[j]] = [out[j], out[i]];
        return out;
    }
    function removedItem(list, i) {
        return list.filter((_, k) => k !== i);
    }
    function addedItem(list, id) {
        return list.includes(id) ? list.slice() : list.concat([id]);
    }

    readonly property bool hasSelection: selected >= 0 && selected < current.length
    // What can still be added.
    readonly property var offers: choices.filter(c => !current.includes(c.id))

    // One entry per shown icon, for its pill.
    readonly property var shownModel: current.map((id, i) => ({
                index: i,
                label: labelOf(id),
                chosen: selected === i
            }))

    function labelOf(id) {
        return choices.find(c => c.id === id)?.label ?? id;
    }
    function toggle(i) {
        entered();
        selected = selected === i ? -1 : i;
    }
    function add(id) {
        entered();
        write(addedItem(current, id), current.length);
    }
    // With no prefKey the list belongs to someone else (a pill in the pills editor): it is handed back through
    // edited() instead of being saved here.
    function write(list, sel) {
        if (prefKey === "")
            edited(list);
        else
            Prefs.set(prefKey, list);
        selected = sel;
    }
    function move(dir) {
        const to = selected + dir;
        const next = movedItem(current, selected, dir);
        if (to >= 0 && to < current.length)
            write(next, to);
    }
    function remove() {
        write(removedItem(current, selected), -1);
    }

    onAdjustRequested: direction => selected = Math.max(0, Math.min(current.length - 1, selected + direction))
    // The selection means nothing once the list is shorter (or replaced by a reset).
    onCurrentChanged: if (selected >= current.length)
        selected = -1

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 24

    // A card, so the two editors read as blocks inside the Settings list.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 14
        color: Theme.surface
        border.width: root.focused ? 1.5 : 1
        border.color: root.focused ? Qt.alpha(Theme.foreground, 0.75) : Theme.border
    }

    // Clicks on the empty parts give the row the keyboard ring.
    MouseArea {
        anchors.fill: parent
        onPressed: root.entered()
    }

    component Heading: Label {
        color: Theme.dim
        font.pixelSize: Appearance.fontSize - 2
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    // A pill-shaped choice. `chosen` fills it with the accent colour; `outlined` draws it as an offer.
    component Choice: Rectangle {
        id: choice

        property string text: ""
        property bool chosen: false
        property bool outlined: false
        signal clicked

        width: pillLabel.implicitWidth + 24
        height: 30
        radius: 15
        color: chosen ? Theme.accent : pillMouse.pressed ? Theme.pressed : pillMouse.containsMouse ? Theme.hover : outlined ? "transparent" : Qt.alpha(Theme.foreground, 0.10)
        border.width: chosen ? 0 : 1
        border.color: Theme.border

        Label {
            id: pillLabel
            anchors.centerIn: parent
            text: choice.text
            font.pixelSize: Appearance.fontSize - 1
            color: choice.chosen ? Theme.accentContent : Theme.foreground
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.clicked()
        }
    }

    Column {
        id: col
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 10

        Row {
            width: parent.width
            spacing: 8

            Label {
                id: titleLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.weight: Font.DemiBold
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - titleLabel.implicitWidth - (defaultButton.visible ? defaultButton.width : 0) - 16)
                text: root.subtitle
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 2
                elide: Text.ElideRight
            }
            CcTextButton {
                id: defaultButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Default"
                visible: root.prefKey !== ""
                enabled: Prefs.has(root.prefKey)
                onClicked: {
                    Prefs.reset(root.prefKey);
                    root.selected = -1;
                }
            }
        }

        Heading {
            text: `Shown (${root.current.length})`
        }

        Flow {
            width: parent.width
            spacing: 6

            // The delegates read everything from their model entry and report clicks through the handlers
            // below: qmllint flags the editor's id (`root`) when a delegate uses it.
            Repeater {
                model: root.shownModel
                onItemAdded: (i, item) => item.clicked.connect(() => root.toggle(item.modelData.index))

                Choice {
                    id: shown

                    required property var modelData

                    text: shown.modelData.label
                    chosen: shown.modelData.chosen
                }
            }

            Label {
                visible: root.current.length === 0
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: "Nothing shown. Add something below."
                color: Theme.dim
            }
        }

        // Always there, so the card does not jump when something is selected.
        Row {
            spacing: 6
            height: 28

            CcTextButton {
                visible: root.hasSelection
                text: "\u2190  Earlier"
                enabled: root.selected > 0
                onClicked: root.move(-1)
            }
            CcTextButton {
                visible: root.hasSelection
                text: "Later  \u2192"
                enabled: root.selected < root.current.length - 1
                onClicked: root.move(1)
            }
            CcTextButton {
                visible: root.hasSelection
                text: "Remove"
                onClicked: root.remove()
            }
            Label {
                visible: !root.hasSelection
                anchors.verticalCenter: parent.verticalCenter
                text: root.current.length > 1 ? "Click an icon to move or remove it" : ""
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 2
            }
        }

        Heading {
            visible: root.offers.length > 0
            text: "Add"
        }

        Flow {
            width: parent.width
            spacing: 6
            visible: root.offers.length > 0

            Repeater {
                model: root.offers
                onItemAdded: (i, item) => item.clicked.connect(() => root.add(item.modelData.id))

                Choice {
                    id: offer

                    required property var modelData

                    text: `+  ${offer.modelData.label}`
                    outlined: true
                }
            }
        }
    }
}
