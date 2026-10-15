pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services
import qs.theme

// The weather page: what it is doing now, the next few hours, then the next few days.
//
// Three time scales because that is how the question is actually asked -- do I need a jacket, will
// it rain before I get back, is the weekend any good -- and each one wants a different shape: one
// big number, a strip, a list.
//
// Place, units and how much to show: config/WeatherConfig.qml.
FocusScope {
    id: root

    readonly property int pad: 16
    readonly property var now: Weather.current

    implicitWidth: 380
    implicitHeight: column.implicitHeight + 2 * root.pad

    focus: true

    function temp(v) {
        return v === undefined || v === null ? "—" : `${Math.round(v)}°`;
    }

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: 14

        // --- now ---
        Item {
            width: parent.width
            height: 62

            Text {
                id: glyph
                anchors.verticalCenter: parent.verticalCenter
                text: root.now ? Weather.glyph(root.now.code, root.now.isDay) : "\u{F0590}"
                color: Theme.accent
                font.family: Appearance.nerdFont
                font.pixelSize: 44
            }

            Column {
                anchors.left: glyph.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: `${root.temp(root.now?.temp)}${Weather.unitSuffix.slice(1)}`
                    color: Theme.foreground
                    font.family: Appearance.font
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.now ? Weather.describe(root.now.code) : Weather.loading ? "Loading…" : "—"
                    color: Theme.dim
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSize - 1
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    anchors.right: parent.right
                    // Said when the place came from the IP: that points at the operator's node, so
                    // the reading can belong to a town some distance away.
                    text: Weather.locatedByIp ? `${Weather.place} · by IP` : Weather.place
                    color: Theme.dim
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSize - 1
                }
                Text {
                    anchors.right: parent.right
                    text: root.now ? `Feels ${root.temp(root.now.feels)} · ${Math.round(root.now.humidity)}%` : ""
                    color: Qt.alpha(Theme.foreground, 0.4)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSize - 3
                }
                Text {
                    anchors.right: parent.right
                    text: root.now ? `${Math.round(root.now.wind)} ${Weather.windSuffix}` : ""
                    color: Qt.alpha(Theme.foreground, 0.4)
                    font.family: Appearance.font
                    font.pixelSize: Appearance.fontSize - 3
                }
            }
        }

        // Said plainly instead of leaving old numbers standing in for current ones.
        Text {
            width: parent.width
            visible: Weather.error !== ""
            text: Weather.error
            color: Theme.danger
            wrapMode: Text.Wrap
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSize - 2
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
            visible: Weather.hours.length > 0
        }

        // --- the next hours ---
        Row {
            width: parent.width
            visible: Weather.hours.length > 0
            spacing: 0

            Repeater {
                model: Weather.hours

                Column {
                    id: hour

                    required property var modelData

                    width: Weather.hours.length > 0 ? Math.floor(column.width / Weather.hours.length) : 0
                    spacing: 3

                    // The hour being lived says so, so the first column is not mistaken for a
                    // forecast of something still to come.
                    readonly property bool isNow: {
                        const n = new Date();
                        return hour.modelData.time.getHours() === n.getHours() && hour.modelData.time.getDate() === n.getDate();
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hour.isNow ? "now" : String(hour.modelData.time.getHours()).padStart(2, "0")
                        color: Qt.alpha(Theme.foreground, hour.isNow ? 0.75 : 0.45)
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize - 4
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.glyph(hour.modelData.code, hour.modelData.time.getHours() >= 7 && hour.modelData.time.getHours() < 20)
                        color: Theme.icon
                        font.family: Appearance.nerdFont
                        font.pixelSize: Appearance.fontSize + 3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.temp(hour.modelData.temp)
                        color: Theme.foreground
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize - 2
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.border
            visible: Weather.days.length > 0
        }

        // --- the next days ---
        Column {
            width: parent.width
            spacing: 7

            Repeater {
                model: Weather.days

                Item {
                    id: day

                    required property int index
                    required property var modelData

                    width: parent.width
                    height: 18

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: day.index === 0 ? "Today" : day.modelData.date.toLocaleDateString(Clock.qtLocale, "ddd")
                        color: day.index === 0 ? Theme.foreground : Theme.dim
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize - 1
                    }

                    Text {
                        anchors.centerIn: parent
                        text: Weather.glyph(day.modelData.code, true)
                        color: Theme.icon
                        font.family: Appearance.nerdFont
                        font.pixelSize: Appearance.fontSize + 2
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${root.temp(day.modelData.min)}  ${root.temp(day.modelData.max)}`
                        color: Theme.foreground
                        font.family: Appearance.font
                        font.pixelSize: Appearance.fontSize - 1
                    }
                }
            }
        }
    }
}
