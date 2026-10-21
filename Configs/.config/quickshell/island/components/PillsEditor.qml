import QtQuick
import qs.island.config
import qs.island.services
import qs.island.theme

// Settings: the extra pills beside the clock (config/PillsConfig.qml, Prefs key pills.extra). One card per
// pill, and "Add a pill" while there is room. Every change is saved at once; "Default" removes them all.
// Takes part in SettingsView's keyboard ring only as a row to stop on (the editing is by mouse).
Item {
    id: root

    property bool focused: false
    readonly property var pills: PillsConfig.extra

    signal triggered
    signal adjustRequested(int direction)
    signal entered

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 8

    function save(list) {
        if (list.length === 0)
            Prefs.reset("pills.extra");
        else
            Prefs.set("pills.extra", list);
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "transparent"
        border.width: 1.5
        border.color: Qt.alpha(Theme.foreground, 0.75)
        opacity: root.focused ? 1 : 0
        visible: opacity > 0
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            width: parent.width
            spacing: 8

            Label {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - addButton.width - defaultButton.width - 16
                text: root.pills.length === 0 ? "No extra pills" : `${root.pills.length} extra pill${root.pills.length === 1 ? "" : "s"}`
                color: Theme.dim
                elide: Text.ElideRight
            }
            CcTextButton {
                id: addButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Add a pill"
                primary: true
                enabled: root.pills.length < PillsConfig.maxPills
                onClicked: {
                    root.entered();
                    root.save(PillsConfig.withPill(root.pills, "right"));
                }
            }
            CcTextButton {
                id: defaultButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Default"
                enabled: root.pills.length > 0
                onClicked: root.save([])
            }
        }

        Repeater {
            model: root.pills
            onItemAdded: (i, item) => {
                item.sideChosen.connect(s => root.save(PillsConfig.withSide(root.pills, item.number - 1, s)));
                item.widgetsEdited.connect(w => root.save(PillsConfig.withWidgets(root.pills, item.number - 1, w)));
                item.removed.connect(() => root.save(PillsConfig.withoutPill(root.pills, item.number - 1)));
            }

            PillCard {
                id: card

                required property var modelData
                required property int index

                width: parent.width
                pill: card.modelData
                number: card.index + 1
            }
        }
    }
}
