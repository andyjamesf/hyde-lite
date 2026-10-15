import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.components
import qs.services

// Battery: charge, time remaining, health and power profile.
ColumnLayout {
    id: root

    width: 300
    spacing: 12

    RowLayout {
        spacing: 14

        MaterialIcon {
            icon: Battery.icon
            size: 44
            fill: 1
            color: Battery.low ? Theme.error : Battery.plugged ? Theme.success : Theme.primary
        }

        ColumnLayout {
            spacing: 0

            StyledText {
                text: `${Battery.percent}%`
                font.pixelSize: Theme.headline
                font.weight: Font.Light
            }

            StyledText {
                text: (Battery.charging ? "Charging" : Battery.plugged ? "Plugged in" : "On battery") + (Battery.secondsLeft > 0 ? ` · ${Utils.formatDuration(Battery.secondsLeft)} ${Battery.charging ? "until full" : "left"}` : "")
                color: Theme.textDim
            }
        }
    }

    StyledText {
        visible: Battery.device?.healthSupported ?? false
        text: `Battery health: ${Math.round(Battery.device?.healthPercentage ?? 0)}%`
        font.pixelSize: Theme.labelSmall
        color: Theme.textFaint
    }

    SectionLabel {
        text: "Power profile"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: PowerProfiles.hasPerformanceProfile ? [0, 1, 2] : [0, 1]

            Rectangle {
                id: seg

                required property int modelData
                readonly property bool current: Battery.profile === modelData

                Layout.fillWidth: true
                implicitHeight: 58
                radius: Theme.shapeLarge
                color: current ? Theme.primary : Theme.surfaceContainerHighest

                Behavior on color {
                    ColorAnim {}
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: ["energy_savings_leaf", "balance", "speed"][seg.modelData]
                        size: 20
                        fill: seg.current ? 1 : 0
                        color: seg.current ? Theme.onPrimary : Theme.text
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: ["Power saver", "Balanced", "Performance"][seg.modelData]
                        font.pixelSize: Theme.labelSmall
                        color: seg.current ? Theme.onPrimary : Theme.text
                    }
                }

                StateLayer {
                    anchors.fill: parent
                    radius: seg.radius
                    onClicked: Battery.setProfile(seg.modelData)
                }
            }
        }
    }

    StyledText {
        visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
        Layout.fillWidth: true
        text: "Performance limited by the system (temperature or laptop on lap)."
        font.pixelSize: Theme.labelSmall
        color: Theme.warning
        wrapMode: Text.WordWrap
    }
}
