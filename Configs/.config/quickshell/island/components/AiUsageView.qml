import QtQuick
import qs.island.config
import qs.island.services
import qs.island.theme

// AI usage popup ("ai" mode: a click on the AI icon): one card per tool (config/AiUsageConfig.qml)
// with its icon and colour, each usage window (5-hour, 7-day, monthly, credits) as a bar with its
// percentage and when it resets, the script's notes, errors, and when it was last read. A click on
// a card fetches that tool again; the button at the top fetches all of them.
Item {
    id: root

    property bool open: false

    readonly property real islandRadius: 26
    readonly property int pad: 16

    // "1h34m" → "resets in 1h34m"; "2026-10-01" → "resets Oct 1".
    function resetText(r) {
        if (!r)
            return "";
        if (/^\d{4}-\d{2}-\d{2}$/.test(r))
            return `resets ${Clock.qtLocale.toString(new Date(r + "T00:00"), "MMM d")}`;
        return `resets in ${r}`;
    }
    function ago(d) {
        if (!d)
            return "";
        const s = Math.max(0, (Time.now.getTime() - d.getTime()) / 1000);
        return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min ago` : `${Math.floor(s / 3600)} h ago`;
    }

    implicitWidth: 420
    implicitHeight: column.implicitHeight + 2 * pad

    // Clicks on empty space stay here (not the island's pin).
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: column
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: 10

        // Title and "refresh all".
        Item {
            width: parent.width
            height: 32
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: "AI usage"
                font.pixelSize: Appearance.fontSize + 3
                font.weight: Font.DemiBold
            }
            CcTextButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Refresh all"
                onClicked: AiUsage.refresh()
            }
        }

        Repeater {
            model: AiUsageConfig.agents

            Rectangle {
                id: card
                required property var modelData
                readonly property var s: AiUsage.states[modelData.name] ?? null
                readonly property bool syncing: (s?.cls ?? "") === "syncing"
                readonly property bool failed: (s?.cls ?? "").includes("critical") || /err|block/i.test(s?.text ?? "")
                readonly property color brand: s?.color || Theme.accent

                width: column.width
                height: cardColumn.implicitHeight + 24
                radius: 18
                color: cardMouse.pressed ? Theme.pressed : cardMouse.containsMouse ? Theme.hover : Qt.alpha(Theme.foreground, 0.04)
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AiUsage.refresh(card.modelData.name)
                }

                Column {
                    id: cardColumn
                    x: 14
                    y: 12
                    width: parent.width - 28
                    spacing: 8

                    // Icon, name, status on the right.
                    Item {
                        width: parent.width
                        height: 26
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                radius: 8
                                color: Qt.alpha(card.brand, 0.18)
                                Label {
                                    anchors.centerIn: parent
                                    text: card.s?.glyph ?? ""
                                    font.family: Appearance.nerdFont
                                    font.pixelSize: 15
                                    elide: Text.ElideNone
                                    color: card.brand
                                }
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.label
                                font.weight: Font.DemiBold
                            }
                        }
                        Label {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: !card.s ? "Waiting…" : card.syncing ? "Syncing…" : card.failed ? card.s.text : root.ago(card.s.updated)
                            color: card.failed ? Theme.danger : Theme.dim
                            font.pixelSize: Appearance.fontSize - 2
                        }
                    }

                    // Usage windows.
                    Repeater {
                        model: card.s?.windows ?? []
                        Column {
                            required property var modelData
                            width: cardColumn.width
                            spacing: 4
                            Item {
                                width: parent.width
                                height: windowLabel.implicitHeight
                                Label {
                                    id: windowLabel
                                    anchors.left: parent.left
                                    text: modelData.detail ? `${modelData.label}  ·  ${modelData.detail}` : modelData.label
                                    font.pixelSize: Appearance.fontSize - 1
                                }
                                Row {
                                    anchors.right: parent.right
                                    spacing: 8
                                    Label {
                                        text: root.resetText(modelData.reset)
                                        color: Theme.dim
                                        font.pixelSize: Appearance.fontSize - 2
                                    }
                                    Label {
                                        text: `${Math.round(modelData.percent)}%`
                                        font.weight: Font.DemiBold
                                        font.pixelSize: Appearance.fontSize - 1
                                        color: modelData.percent >= 90 ? Theme.danger : Theme.foreground
                                    }
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 8
                                radius: 4
                                color: Qt.alpha(Theme.foreground, 0.08)
                                Rectangle {
                                    width: Math.max(parent.height, parent.width * Math.min(1, modelData.percent / 100))
                                    height: parent.height
                                    radius: 4
                                    color: modelData.percent >= 90 ? Theme.danger : modelData.percent >= 70 ? Qt.alpha(card.brand, 1) : card.brand
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Animations.duration(300)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Nothing parsed (an error, or a script with only a value): its text.
                    Label {
                        visible: !!card.s && (card.s.windows ?? []).length === 0 && !card.failed && card.s.text !== ""
                        text: card.s?.text ?? ""
                        color: Theme.dim
                    }

                    Repeater {
                        model: card.s?.notes ?? []
                        Label {
                            required property string modelData
                            width: cardColumn.width
                            wrapMode: Text.WordWrap
                            text: modelData
                            color: Theme.faint
                            font.pixelSize: Appearance.fontSize - 2
                        }
                    }
                }
            }
        }

        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Click a card to read it again"
            color: Theme.faint
            font.pixelSize: Appearance.fontSize - 2
        }
    }
}
