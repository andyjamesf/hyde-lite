import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.bar.services
import qs.shared.services

// A notification: icon/image, app, time, title, body, actions and close button.
// Clicking the card runs the app's default action (if any) and closes it.
Rectangle {
    id: root

    required property Notification notification
    property bool popup: false
    // Compact version (control center): title and body on one line, no action buttons.
    property bool compact: false
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property var defaultAction: (notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    // Hover reaches every area under the cursor, so this one also covers the buttons.
    readonly property bool hovered: area.containsMouse

    signal closed

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 2 * Theme.space3
    radius: popup ? Theme.shapeLarge : Theme.shapeMedium
    color: popup ? Theme.alpha(Theme.surfaceContainer, 0.97) : Theme.surfaceContainerHigh
    border.width: critical ? 2 : popup ? 1 : 0
    border.color: critical ? Theme.error : Theme.border

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: root.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton && root.defaultAction)
                root.defaultAction.invoke();
            root.closed();
            if (mouse.button === Qt.MiddleButton || root.defaultAction)
                root.notification.dismiss();
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space3
        spacing: Theme.space3

        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            radius: Theme.shapeSmall
            color: Theme.surfaceContainerHighest

            MaterialIcon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                icon: root.critical ? "priority_high" : "notifications"
                size: 20
                fill: 1
                color: root.critical ? Theme.error : Theme.primary
            }

            Image {
                id: img
                anchors.fill: parent
                source: Notifications.imageOf(root.notification)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 80
                sourceSize.height: 80
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                StyledText {
                    Layout.fillWidth: true
                    text: root.notification?.appName || "Notification"
                    font.pixelSize: Theme.labelMedium
                    color: Theme.textDim
                }

                StyledText {
                    text: Utils.relativeTime(Notifications.timeOf(root.notification))
                    font.pixelSize: Theme.labelSmall
                    color: Theme.textFaint
                }

                IconButton {
                    icon: "close"
                    size: 24
                    color: Theme.textDim
                    onClicked: {
                        root.closed();
                        root.notification.dismiss();
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.summary ?? ""
                font.pixelSize: Theme.titleSmall
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
                maximumLineCount: root.compact ? 1 : 2
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: (root.notification?.body ?? "").replace(/<img[^>]*>/g, "")
                textFormat: Text.StyledText
                color: Theme.textDim
                font.pixelSize: Theme.bodyMedium
                wrapMode: Text.WordWrap
                maximumLineCount: root.compact ? 1 : root.popup ? 4 : 6
                elide: Text.ElideRight
                linkColor: Theme.primary
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space2
                visible: root.actions.length > 0 && !root.compact
                spacing: Theme.space2

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: action

                        required property var modelData

                        implicitWidth: actionText.implicitWidth + 2 * Theme.space4
                        implicitHeight: 32
                        radius: height / 2
                        color: Theme.primaryContainer

                        StyledText {
                            id: actionText
                            anchors.centerIn: parent
                            text: action.modelData.text
                            font.pixelSize: Theme.labelLarge
                            font.weight: Font.Medium
                            color: Theme.onPrimaryContainer
                        }

                        StateLayer {
                            anchors.fill: parent
                            onClicked: {
                                action.modelData.invoke();
                                root.closed();
                                if (!root.notification.resident)
                                    root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
