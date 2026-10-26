import QtQuick
import QtQuick.Effects
import qs.shared.icons
import qs.shared.services

// Compact "now playing" row of the control centre: the cover (or a tinted square), title, artist, a
// play/pause button, and an arrow. A click on the row asks for the player page (`pageRequested`);
// the play button toggles. Hidden when nothing is playing.
Rectangle {
    id: root

    signal pageRequested

    width: parent ? parent.width : 300
    height: 56
    visible: Media.active
    radius: 18
    color: mouse.pressed ? CcTheme.pressed : mouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.04)
    border.width: 1
    border.color: CcTheme.border

    Behavior on color {
        ColorAnimation {
            duration: CcTheme.duration(120)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.pageRequested()
    }

    // Cover with rounded corners (mask); without a cover, a tinted square.
    Item {
        id: art
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40

        readonly property bool hasCover: cover.status === Image.Ready

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Qt.alpha(CcTheme.accent, 0.22)
            visible: !art.hasCover

            MediaIcon {
                anchors.centerIn: parent
                kind: "play"
                size: 16
                color: CcTheme.accent
            }
        }

        Image {
            id: cover
            anchors.fill: parent
            source: Media.artUrl || ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 80
            sourceSize.height: 80
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: cover
            visible: art.hasCover
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Item {
            id: artMask
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "black"
            }
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: playButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        CcLabel {
            width: parent.width
            text: Media.title || Media.identity || "Unknown"
            textFormat: Text.PlainText
            font.weight: Font.Medium
        }

        CcLabel {
            width: parent.width
            visible: text !== ""
            text: Media.artist
            textFormat: Text.PlainText
            color: CcTheme.dim
            font.pixelSize: CcTheme.fontSize - 2
        }
    }

    CcIconButton {
        id: playButton
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        size: 34
        onClicked: Media.togglePlaying()

        MediaIcon {
            kind: Media.playing ? "pause" : "play"
            size: 16
            color: CcTheme.icon
        }
    }

    Glyph {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        kind: "chevron"
        size: 14
        color: mouse.containsMouse ? CcTheme.foreground : CcTheme.faint
    }
}
