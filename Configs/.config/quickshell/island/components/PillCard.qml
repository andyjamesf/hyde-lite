import QtQuick
import qs.island.config

// One extra pill in the pills editor: which side it is on, what it holds (an IconListEditor with no pref of its
// own) and a Remove button. It only reports what the person did; PillsEditor saves it.
Item {
    id: card

    // The pill: { side, widgets }.
    property var pill: ({ side: "right", widgets: [] })
    property int number: 1

    signal sideChosen(string side)
    signal widgetsEdited(var widgets)
    signal removed

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 4

        Row {
            spacing: 6
            height: 30

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: `Pill ${card.number}`
                font.weight: Font.DemiBold
            }
            Chips {
                anchors.verticalCenter: parent.verticalCenter
                options: [{ label: "Left", value: "left" }, { label: "Right", value: "right" }]
                value: card.pill.side
                onPicked: v => card.sideChosen(v)
            }
            CcTextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Remove pill"
                onClicked: card.removed()
            }
        }

        IconListEditor {
            id: list
            width: parent.width
            title: "Widgets"
            subtitle: "In this pill, left to right"
            current: card.pill.widgets
            choices: SettingsScreen.pillWidgetChoices
            onEdited: l => card.widgetsEdited(l)
        }
    }
}
