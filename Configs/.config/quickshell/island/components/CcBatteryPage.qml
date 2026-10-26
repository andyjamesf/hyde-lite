import QtQuick
import qs.island.config
import qs.shared.icons
import qs.island.theme
import qs.shared.services

// Battery page of the control center ("battery" mode; a click on the battery in the header or the
// status pill): charge and time left, battery health and the power profile (Power saver ·
// Balanced · Performance), with a note when the system holds performance back.
Item {
    id: root

    property bool shown: false

    readonly property int pad: ControlCenter.padding

    function duration(seconds) {
        const m = Math.round(seconds / 60);
        if (!(m > 0))
            return "";
        const h = Math.floor(m / 60);
        return h > 0 ? `${h} h ${String(m % 60).padStart(2, "0")} min` : `${m} min`;
    }
    readonly property string charge: {
        if (!Battery.available)
            return "No battery";
        if (Battery.charging) {
            const t = duration(Battery.timeToFull);
            return t ? `Charging · full in ${t}` : "Charging";
        }
        if (Battery.plugged)
            return "Plugged in";
        const t = duration(Battery.timeToEmpty);
        return t ? `${t} left` : "On battery";
    }

    implicitWidth: ControlCenter.width
    implicitHeight: header.y + header.height + 6 + body.implicitHeight + pad

    CcHeader {
        id: header
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        title: "Battery"
    }

    Column {
        id: body
        x: root.pad
        y: header.y + header.height + 6
        width: root.width - 2 * root.pad
        spacing: 14

        // Charge: big percentage, the state under it, the icon on the right.
        Item {
            visible: Battery.available
            width: parent.width
            height: 56

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Label {
                    text: `${Math.round(Battery.percent)}%`
                    font.pixelSize: Appearance.fontSize + 15
                    font.weight: Font.Light
                }
                Label {
                    text: root.charge
                    color: Theme.dim
                }
            }

            BatteryIcon {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                size: 34
                showPercent: false
                present: Battery.available
                percent: Battery.percent
                charging: Battery.charging
            }
        }

        Label {
            visible: Battery.health >= 0
            leftPadding: 4
            text: `Battery health: ${Math.round(Battery.health)}%`
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        // Power profile: one button each.
        Column {
            width: parent.width
            spacing: 8

            Label {
                leftPadding: 4
                text: "Power profile"
                font.weight: Font.DemiBold
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 1
            }

            Row {
                id: profiles
                width: parent.width
                spacing: 8

                readonly property var items: [
                    {
                        value: 0,
                        name: "Power saver",
                        glyph: "\u{F032A}"
                    },
                    {
                        value: 1,
                        name: "Balanced",
                        glyph: "\u{F05D1}"
                    },
                    {
                        value: 2,
                        name: "Performance",
                        glyph: "\u{F14DE}"
                    }
                ].filter(p => p.value < 2 || Battery.hasPerformance)

                Repeater {
                    model: profiles.items

                    Rectangle {
                        id: profileButton
                        required property var modelData
                        readonly property bool chosen: Battery.profile === modelData.value
                        width: (profiles.width - profiles.spacing * (profiles.items.length - 1)) / profiles.items.length
                        height: 64
                        radius: 18
                        color: chosen ? Theme.accent : profileMouse.pressed ? Theme.pressed : profileMouse.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.04)
                        border.width: chosen ? 0 : 1
                        border.color: Theme.border

                        Behavior on color {
                            ColorAnimation {
                                duration: Animations.duration(120)
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: profileButton.modelData.glyph
                                font.family: Appearance.nerdFont
                                font.pixelSize: 18
                                elide: Text.ElideNone
                                color: profileButton.chosen ? Theme.accentContent : Theme.icon
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: profileButton.modelData.name
                                font.pixelSize: Appearance.fontSize - 1
                                color: profileButton.chosen ? Theme.accentContent : Theme.foreground
                            }
                        }

                        MouseArea {
                            id: profileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Battery.setProfile(profileButton.modelData.value)
                        }
                    }
                }
            }

            Label {
                visible: Battery.degraded
                width: parent.width
                leftPadding: 4
                wrapMode: Text.WordWrap
                text: "Performance is held back by the system (temperature, or the laptop on a lap)."
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 2
            }
        }
    }
}
