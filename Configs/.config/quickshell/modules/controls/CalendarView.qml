import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Large clock, month calendar (Monday first) and Google Calendar events
// (Agenda service). Arrows or scroll change the month; clicking a day shows that day's events.
ColumnLayout {
    id: root

    property int shift: 0
    property date selected: new Date()
    readonly property var selectedEvents: Agenda.eventsOn(selected)
    readonly property date now: clock.date
    readonly property date month: new Date(now.getFullYear(), now.getMonth() + shift, 1)

    // The 6 weeks shown, starting on the Monday before the 1st.
    readonly property var days: {
        const start = new Date(month);
        start.setDate(1 - (month.getDay() + 6) % 7);
        return Array.from({
            length: 42
        }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    width: 300
    spacing: 12

    Component.onCompleted: Agenda.refresh()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    WheelHandler {
        onWheel: event => root.shift += event.angleDelta.y > 0 ? -1 : 1
    }

    ColumnLayout {
        spacing: 0

        StyledText {
            text: Utils.formatDate(root.now, "HH:mm")
            font.pixelSize: Theme.displaySmall
            font.weight: Font.Light
            color: Theme.primary
        }

        StyledText {
            text: Utils.formatDate(root.now, "dddd, d MMMM yyyy")
            color: Theme.textDim
        }
    }

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: Utils.formatDate(root.month, "MMMM yyyy")
            font.pixelSize: Theme.titleSmall
            font.weight: Font.DemiBold
            font.capitalization: Font.Capitalize
        }

        IconButton {
            visible: root.shift !== 0
            size: 30
            icon: "today"
            onClicked: {
                root.shift = 0;
                root.selected = new Date();
            }
        }

        IconButton {
            size: 30
            icon: "chevron_left"
            onClicked: root.shift--
        }

        IconButton {
            size: 30
            icon: "chevron_right"
            onClicked: root.shift++
        }
    }

    Grid {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: [1, 2, 3, 4, 5, 6, 0]

            StyledText {
                required property int modelData
                width: (root.width - 12) / 7
                horizontalAlignment: Text.AlignHCenter
                text: Utils.dayName(modelData, Locale.ShortFormat).slice(0, 3)
                font.pixelSize: Theme.labelSmall
                font.weight: Font.Bold
                color: modelData === 0 || modelData === 6 ? Theme.tertiary : Theme.textDim
            }
        }

        Repeater {
            model: root.days

            Item {
                id: day

                required property date modelData
                readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                readonly property bool today: modelData.toDateString() === root.now.toDateString()
                readonly property bool isSelected: modelData.toDateString() === root.selected.toDateString()
                readonly property var dayEvents: Agenda.eventsOn(modelData)

                width: (root.width - 12) / 7
                height: 36

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    width: 30
                    height: 30
                    radius: height / 2
                    color: day.today ? Theme.primary : "transparent"
                    border.width: day.isSelected && !day.today ? 2 : 0
                    border.color: Theme.primary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    height: 30
                    text: day.modelData.getDate()
                    color: day.today ? Theme.onPrimary : day.inMonth ? Theme.text : Theme.textFaint
                    font.weight: day.today ? Font.Bold : Font.Normal
                    opacity: day.inMonth ? 1 : 0.5
                }

                // One dot per event (up to 3), in the calendar's color.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: 2

                    Repeater {
                        model: day.dayEvents.slice(0, 3)

                        Rectangle {
                            required property var modelData
                            width: 4
                            height: 4
                            radius: 2
                            color: modelData.color || Theme.tertiary
                        }
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    radius: Theme.shapeSmall
                    onClicked: root.selected = day.modelData
                }
            }
        }
    }

    // Events of the selected day.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            SectionLabel {
                text: root.selected.toDateString() === root.now.toDateString() ? "Today" : Utils.formatDate(root.selected, "dddd, d MMMM")
            }

            IconButton {
                visible: Agenda.configured
                icon: "open_in_new"
                size: 26
                onClicked: Agenda.openInBrowser(root.selected)
            }
        }

        StyledText {
            visible: !Agenda.configured
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.labelSmall
            color: Theme.textFaint
            text: "To see your Google Calendar events, add the calendar's private iCal address to ~/.local/share/quickshell/calendars.json."
        }

        StyledText {
            visible: Agenda.configured && root.selectedEvents.length === 0
            text: "No events"
            font.pixelSize: Theme.labelSmall
            color: Theme.textFaint
        }

        Repeater {
            model: root.selectedEvents.slice(0, 6)

            Rectangle {
                id: ev

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: evText.implicitHeight + 14
                radius: Theme.shapeSmall
                color: Theme.surfaceContainerHigh

                Rectangle {
                    width: 4
                    height: parent.height - 12
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: ev.modelData.color || Theme.tertiary
                }

                ColumnLayout {
                    id: evText
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: ev.modelData.title
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (ev.modelData.allDay ? "All day" : `${Utils.formatDate(ev.modelData.start, "HH:mm")} – ${Utils.formatDate(ev.modelData.end, "HH:mm")}`) + (ev.modelData.location ? `  ·  ${ev.modelData.location}` : "")
                        font.pixelSize: Theme.labelSmall
                        color: Theme.textDim
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    radius: ev.radius
                    onClicked: Agenda.openInBrowser(ev.modelData.start)
                }
            }
        }

        StyledText {
            visible: Agenda.errors.length > 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.labelSmall
            color: Theme.warning
            text: "Could not update: " + Agenda.errors.join("; ")
        }
    }
}
