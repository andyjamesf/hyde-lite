import QtQuick
import QtQuick.Effects
import qs.config
import qs.icons
import qs.services
import qs.theme

// Left zone of the expanded island: album art + previous / play-pause / next.
// No titles (they do not fit in the zone). Without a player: nothing (the zone takes no width).
Item {
    id: root

    // Width assigned by ExpandedView (the content is left-aligned inside it).
    property int zoneWidth: implicitWidth

    readonly property real artSize: Pill.height - Expanded.mediaArtInset
    readonly property real iconSize: Math.round(Pill.height * Expanded.mediaIconFactor)

    width: zoneWidth
    // Natural width (ExpandedView uses it to make sure the zone is wide enough).
    implicitWidth: Media.active ? player.implicitWidth : 0
    implicitHeight: Pill.height

    Row {
        id: player
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        opacity: Media.active ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(160)
            }
        }

        // Cover: image clipped with rounded corners (mask); without a cover, a tinted square.
        Item {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: root.artSize
            height: root.artSize

            readonly property real radius: Math.round(root.artSize * Expanded.mediaArtRadiusFactor)
            readonly property bool hasCover: cover.status === Image.Ready

            Rectangle {
                anchors.fill: parent
                radius: art.radius
                color: Qt.alpha(Theme.accent, 0.22)
                visible: !art.hasCover

                MediaIcon {
                    anchors.centerIn: parent
                    kind: "play"
                    size: Math.round(root.artSize * 0.36)
                    color: Theme.accent
                }
            }

            Image {
                id: cover
                anchors.fill: parent
                source: Media.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.artSize * 2
                sourceSize.height: root.artSize * 2
                asynchronous: true
                smooth: true
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
                    radius: art.radius
                    color: "black"
                }
            }
        }

        // A small breather between the cover and the buttons.
        Item {
            width: 4
            height: 1
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Media.canPrevious
            onClicked: Media.previous()

            MediaIcon {
                kind: "prev"
                size: root.iconSize
                color: Theme.icon
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Media.togglePlaying()

            MediaIcon {
                kind: Media.playing ? "pause" : "play"
                size: root.iconSize
                color: Theme.icon
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            enabled: Media.canNext
            onClicked: Media.next()

            MediaIcon {
                kind: "next"
                size: root.iconSize
                color: Theme.icon
            }
        }
    }
}
