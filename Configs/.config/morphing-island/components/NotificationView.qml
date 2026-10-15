import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.core
import qs.services
import qs.theme

// Notification in the island ("notification" mode): the app icon or an avatar with its initial,
// app name, title, body (up to NotificationsConfig.bodyLines lines), up to maxActions actions and a
// thin countdown line at the bottom. Layout: config/NotificationsConfig.qml.
// Click anywhere (outside the actions): runs the default action, if any, and closes;
// middle click: closes and removes it from the history, without any action.
Item {
    id: root

    readonly property real islandRadius: NotificationsConfig.radius
    readonly property int padding: NotificationsConfig.padding
    readonly property int avatarSize: NotificationsConfig.avatarSize

    // Keeps the last notification shown: when closing, the controller's payload becomes null but the
    // content must stay visible while it fades out.
    readonly property var live: IslandController.mode === IslandState.notification ? IslandController.payload : null
    property var notification: null
    onLiveChanged: if (live)
        notification = live
    Component.onCompleted: notification = live

    // Same for the progress (it goes back to 0 when closing, and the line would refill during the fade).
    property real progress: 0
    readonly property real liveProgress: IslandController.transientProgress
    onLiveProgressChanged: if (live)
        progress = liveProgress

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property color tint: critical ? Theme.danger : Theme.accent
    readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default").slice(0, NotificationsConfig.maxActions)
    readonly property var defaultAction: (notification?.actions ?? []).find(a => a.identifier === "default") ?? null
    readonly property string appName: notification?.appName || "Notification"
    readonly property string body: (notification?.body ?? "").replace(/<img[^>]*>/g, "")

    // Natural width of the text (on one line), so the island is not wider than needed.
    readonly property real textNatural: Math.max(appMetrics.advanceWidth, summaryMetrics.advanceWidth, bodyMetrics.advanceWidth, actionsRow.implicitWidth)
    readonly property real textLeft: padding + (critical ? 8 : 0) + avatarSize + 12

    implicitWidth: Math.round(Math.max(NotificationsConfig.minWidth, Math.min(NotificationsConfig.maxWidth, textLeft + textNatural + padding + 2)))
    implicitHeight: Math.max(avatarSize, column.implicitHeight) + 2 * padding

    TextMetrics {
        id: appMetrics
        font: appLabel.font
        text: root.appName
    }
    TextMetrics {
        id: summaryMetrics
        font: summaryLabel.font
        text: root.notification?.summary ?? ""
    }
    TextMetrics {
        id: bodyMetrics
        font: bodyLabel.font
        // Only for measuring: no markup.
        text: root.body.replace(/<[^>]*>/g, "")
    }

    // Under everything: takes the clicks that miss the actions (so a click never reaches the island's
    // "empty space" MouseArea, which toggles the pin).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            const n = root.notification;
            if (mouse.button === Qt.LeftButton && root.defaultAction)
                root.defaultAction.invoke();
            // First the notification, then the island (closing the island may expire the transient ones).
            if (n && (mouse.button === Qt.MiddleButton || root.defaultAction))
                n.dismiss();
            Notifications.hideCurrent();
        }
    }

    // Critical: red bar on the left.
    Rectangle {
        visible: root.critical
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: parent.height - 2 * root.padding
        radius: width / 2
        color: Theme.danger
    }

    // App icon/image, or an avatar with the initial if there is none (or it fails to load).
    ClippingRectangle {
        id: avatar
        anchors.left: parent.left
        anchors.leftMargin: root.padding + (root.critical ? 8 : 0)
        anchors.top: parent.top
        anchors.topMargin: root.padding
        width: root.avatarSize
        height: root.avatarSize
        radius: img.status === Image.Ready ? 10 : width / 2
        color: Qt.alpha(root.tint, 0.18)

        Label {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: root.appName.charAt(0).toUpperCase()
            color: root.tint
            font.pixelSize: Math.round(root.avatarSize * 0.45)
            font.weight: Font.Bold
        }

        Image {
            id: img
            anchors.fill: parent
            source: Notifications.imageOf(root.notification)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: root.avatarSize * 2
            sourceSize.height: root.avatarSize * 2
        }
    }

    Column {
        id: column
        anchors.left: parent.left
        anchors.leftMargin: root.textLeft
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.top: parent.top
        anchors.topMargin: root.padding
        spacing: 2

        Label {
            id: appLabel
            width: parent.width
            text: root.appName
            color: root.critical ? Theme.danger : Theme.dim
            font.pixelSize: Appearance.fontSize - 2
        }

        Label {
            id: summaryLabel
            width: parent.width
            visible: text !== ""
            text: root.notification?.summary ?? ""
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: NotificationsConfig.summaryLines
        }

        Label {
            id: bodyLabel
            width: parent.width
            visible: text !== ""
            text: root.body
            textFormat: Text.StyledText
            color: Theme.dim
            wrapMode: Text.Wrap
            maximumLineCount: NotificationsConfig.bodyLines
            linkColor: root.tint
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        // Actions (max. NotificationsConfig.maxActions): run and close.
        Row {
            id: actionsRow
            visible: root.actions.length > 0
            topPadding: 6
            spacing: 6

            Repeater {
                model: root.actions

                Rectangle {
                    id: chip

                    required property var modelData

                    implicitWidth: chipLabel.implicitWidth + 24
                    implicitHeight: Pill.height - 8
                    radius: height / 2
                    color: chipMouse.pressed ? Theme.pressed : chipMouse.containsMouse ? Theme.hover : Theme.surface
                    border.width: 1
                    border.color: Theme.border

                    Label {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.text
                        font.pixelSize: Appearance.fontSize - 1
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const n = root.notification;
                            chip.modelData.invoke();
                            if (n && !n.resident)
                                n.dismiss();
                            Notifications.hideCurrent();
                        }
                    }
                }
            }
        }
    }

    // Countdown: a thin line that shrinks until closing.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.left: parent.left
        anchors.leftMargin: root.islandRadius
        width: Math.max(0, (parent.width - 2 * root.islandRadius) * (1 - root.progress))
        height: 2
        radius: 1
        color: root.tint
        opacity: IslandController.held ? 0.45 : 0.9

        // The controller ticks every 100 ms: the linear animation smooths the steps.
        Behavior on width {
            NumberAnimation {
                duration: Animations.duration(100)
            }
        }
    }
}
