import QtQuick
import Quickshell.Widgets
import qs.config
import qs.core
import qs.services
import qs.theme

// A screenshot just taken ("screenshot" mode, services/Screenshot.qml): the capture, what happened
// to it ("Copied to the clipboard", "Saved to ~/Pictures/Screenshots") and Copy · Save · Edit ·
// Delete. A click on the image opens it in the image viewer. Left alone it goes away after
// ScreenshotConfig.previewMs (the pointer over it holds it) and is saved (or discarded:
// ScreenshotConfig.whenLeft). Also a thin countdown line at the bottom, as on notifications.
Item {
    id: root

    readonly property real islandRadius: 22
    readonly property int padding: 14

    // Keeps the last capture on show while the island fades out (the service clears it on close).
    property string shownFile: ""
    property string shownStatus: ""
    readonly property string liveFile: Screenshot.file
    onLiveFileChanged: if (liveFile !== "")
        shownFile = liveFile
    readonly property string liveStatus: Screenshot.status
    onLiveStatusChanged: if (liveFile !== "")
        shownStatus = liveStatus
    Component.onCompleted: {
        shownFile = liveFile;
        shownStatus = liveStatus;
    }

    property real progress: 0
    readonly property real liveProgress: IslandController.transientProgress
    onLiveProgressChanged: if (IslandController.mode === IslandState.screenshot)
        progress = liveProgress

    readonly property real ratio: preview.implicitHeight > 0 ? preview.implicitWidth / preview.implicitHeight : 16 / 9
    readonly property int imageWidth: ScreenshotConfig.previewWidth
    // At most 60% of the width tall (a tall capture is shown narrower).
    readonly property int imageHeight: Math.round(Math.min(imageWidth / ratio, imageWidth * 0.6))

    implicitWidth: imageWidth + 2 * padding
    implicitHeight: column.implicitHeight + 2 * padding

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 10

        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.imageWidth, Math.round(root.imageHeight * root.ratio))
            height: root.imageHeight
            radius: 12
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            Image {
                id: preview
                anchors.fill: parent
                source: root.shownFile !== "" ? `file://${root.shownFile}` : ""
                fillMode: Image.PreserveAspectFit
                sourceSize.width: root.imageWidth * 2
                asynchronous: true
                cache: false
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Screenshot.open()
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.imageWidth)
            horizontalAlignment: Text.AlignHCenter
            text: root.shownStatus || "Screenshot"
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            CcTextButton {
                text: "Copy"
                onClicked: Screenshot.copy()
            }
            CcTextButton {
                text: Screenshot.savedPath !== "" ? "Saved" : "Save"
                primary: Screenshot.savedPath === ""
                enabled: Screenshot.savedPath === ""
                onClicked: Screenshot.save()
            }
            CcTextButton {
                text: "Edit"
                onClicked: Screenshot.edit()
            }
            CcTextButton {
                text: "Delete"
                onClicked: Screenshot.discard()
            }
        }
    }

    // Countdown until it goes away by itself.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: root.islandRadius / 2
        height: 2
        radius: 1
        width: (parent.width - root.islandRadius) * (1 - root.progress)
        color: Theme.accent
        opacity: 0.6
    }
}
