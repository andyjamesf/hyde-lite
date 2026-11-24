import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.bar.components
import qs.bar.services
import qs.shared.services

// The calendar filling a tab of the control centre: the month as a big grid (each day shows its
// events as little coloured pills) on the left, and on the right the clock and the agenda of the
// selected day. Arrows or the wheel change the month; a click on a day selects it. The small
// CalendarView stays for the bar's popout.
Item {
    id: root

    property int shift: 0
    property date selected: new Date()
    readonly property var selectedEvents: Calendar.eventsOn(selected)
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

    Component.onCompleted: Calendar.refresh()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    WheelHandler {
        onWheel: event => root.shift += event.angleDelta.y > 0 ? -1 : 1
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 16

        // ── The month ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Utils.formatDate(root.month, "MMMM yyyy")
                    font.pixelSize: Theme.titleLarge
                    font.weight: Font.DemiBold
                    font.capitalization: Font.Capitalize
                }

                IconButton {
                    visible: root.shift !== 0
                    size: 32
                    icon: "today"
                    onClicked: {
                        root.shift = 0;
                        root.selected = new Date();
                    }
                }
                IconButton {
                    size: 32
                    icon: "chevron_left"
                    onClicked: root.shift--
                }
                IconButton {
                    size: 32
                    icon: "chevron_right"
                    onClicked: root.shift++
                }
            }

            Row {
                Layout.fillWidth: true

                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 0]

                    StyledText {
                        required property int modelData
                        width: grid.cellW
                        horizontalAlignment: Text.AlignHCenter
                        text: Utils.dayName(modelData, Locale.ShortFormat).slice(0, 3)
                        font.pixelSize: Theme.labelMedium
                        font.weight: Font.Bold
                        color: modelData === 0 || modelData === 6 ? Theme.tertiary : Theme.textDim
                    }
                }
            }

            Grid {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                spacing: 0

                readonly property real cellW: width / 7
                readonly property real cellH: height / 6

                Repeater {
                    model: root.days

                    Item {
                        id: day

                        required property date modelData
                        readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                        readonly property bool today: modelData.toDateString() === root.now.toDateString()
                        readonly property bool isSelected: modelData.toDateString() === root.selected.toDateString()
                        readonly property var dayEvents: Calendar.eventsOn(modelData)

                        width: grid.cellW
                        height: grid.cellH

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Theme.shapeSmall
                            color: day.isSelected ? Theme.alpha(Theme.primary, 0.16) : day.today ? Theme.alpha(Theme.primary, 0.08) : Theme.alpha(Theme.text, day.inMonth ? 0.04 : 0.015)
                            border.width: day.isSelected ? 2 : day.today ? 1 : 0
                            border.color: Theme.primary
                        }

                        Rectangle {
                            x: 8
                            y: 6
                            width: 24
                            height: 24
                            radius: 12
                            color: day.today ? Theme.primary : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: day.modelData.getDate()
                                font.pixelSize: Theme.labelMedium
                                font.weight: day.today ? Font.Bold : Font.Normal
                                color: day.today ? Theme.onPrimary : day.inMonth ? Theme.text : Theme.textFaint
                            }
                        }

                        // The day's events: pills with the title, as many as fit, and "+n" for the rest.
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            spacing: 2
                            opacity: day.inMonth ? 1 : 0.5

                            Repeater {
                                model: day.dayEvents.slice(0, day.dayEvents.length > 2 ? 1 : 2)

                                Rectangle {
                                    id: pill
                                    required property var modelData
                                    width: parent.width
                                    height: 15
                                    radius: 4
                                    color: Theme.alpha(modelData.color || Theme.tertiary, 0.35)

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 4
                                        anchors.rightMargin: 4
                                        text: pill.modelData.title
                                        font.pixelSize: Theme.labelSmall - 1
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            StyledText {
                                visible: day.dayEvents.length > 2
                                text: `+${day.dayEvents.length - 1} more`
                                font.pixelSize: Theme.labelSmall - 1
                                color: Theme.textDim
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
        }

        // ── The day ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            radius: Theme.shapeMedium
            color: Theme.alpha(Theme.text, 0.04)
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

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

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: root.selected.toDateString() === root.now.toDateString() ? "Today" : Utils.formatDate(root.selected, "dddd, d MMMM")
                        font.pixelSize: Theme.titleSmall
                        font.weight: Font.DemiBold
                    }
                    IconButton {
                        visible: Calendar.configured
                        icon: "open_in_new"
                        size: 28
                        onClicked: Calendar.openInBrowser(root.selected)
                    }
                }

                StyledText {
                    visible: !Calendar.configured
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.labelSmall
                    color: Theme.textFaint
                    text: "To see your Google Calendar events, add the calendar's private iCal address to ~/.local/share/quickshell/calendars.json."
                }

                StyledText {
                    visible: Calendar.configured && root.selectedEvents.length === 0
                    text: "No events"
                    color: Theme.textFaint
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.selectedEvents

                    delegate: Rectangle {
                        id: ev

                        required property var modelData

                        width: ListView.view.width
                        implicitHeight: evText.implicitHeight + 16
                        height: implicitHeight
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
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: (ev.modelData.allDay ? "All day" : `${Utils.formatDate(ev.modelData.start, "HH:mm")} – ${Utils.formatDate(ev.modelData.end, "HH:mm")}`) + (ev.modelData.location ? `  ·  ${ev.modelData.location}` : "")
                                font.pixelSize: Theme.labelSmall
                                color: Theme.textDim
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                            }
                        }

                        StateLayer {
                            anchors.fill: parent
                            radius: ev.radius
                            onClicked: Calendar.openInBrowser(ev.modelData.start)
                        }
                    }
                }

                StyledText {
                    visible: Calendar.errors.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.labelSmall
                    color: Theme.warning
                    text: "Could not update: " + Calendar.errors.join("; ")
                }
            }
        }
    }
}
