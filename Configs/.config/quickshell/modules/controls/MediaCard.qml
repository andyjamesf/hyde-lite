import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.services

// Media player: cover, title, progress (with seeking) and controls. With more than one player,
// shows shortcuts to switch between them.
ColumnLayout {
    id: root

    readonly property MprisPlayer player: Media.active

    width: 320
    spacing: 12

    // MPRIS doesn't signal when the position advances; an update is requested every second, and only
    // while this card is visible and playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && Media.playing
        onTriggered: root.player?.positionChanged()
    }

    StyledText {
        visible: !root.player
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Nothing playing"
        color: Theme.textDim
        padding: 12
    }

    RowLayout {
        visible: !!root.player
        Layout.fillWidth: true
        spacing: 14

        ClippingRectangle {
            implicitWidth: 76
            implicitHeight: 76
            radius: Theme.shapeMedium
            color: Theme.surfaceContainerHighest

            MaterialIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                icon: "music_note"
                size: 34
                fill: 1
                color: Theme.primary
            }

            Image {
                id: art
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 152
                sourceSize.height: 152
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: Media.title || "Untitled"
                font.pixelSize: Theme.titleMedium
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: Media.artist
                color: Theme.textDim
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                font.pixelSize: Theme.labelSmall
                color: Theme.textFaint
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.identity ?? ""
                font.pixelSize: Theme.labelSmall
                color: Theme.primary
            }
        }
    }

    ColumnLayout {
        visible: !!root.player && (root.player.lengthSupported ?? false) && root.player.length > 0
        Layout.fillWidth: true
        spacing: 4

        Item {
            Layout.fillWidth: true
            implicitHeight: 14

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 5
                radius: 3
                color: Theme.surfaceContainerHighest

                Rectangle {
                    width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                    height: parent.height
                    radius: 3
                    color: Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canSeek ?? false
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => root.player.position = mouse.x / width * root.player.length
            }
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                text: root.fmt(root.player?.position ?? 0)
                font.pixelSize: Theme.labelSmall
                color: Theme.textDim
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                text: root.fmt(root.player?.length ?? 0)
                font.pixelSize: Theme.labelSmall
                color: Theme.textDim
            }
        }
    }

    RowLayout {
        visible: !!root.player
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        IconButton {
            visible: root.player?.shuffleSupported ?? false
            icon: "shuffle"
            checked: root.player?.shuffle ?? false
            size: 34
            onClicked: root.player.shuffle = !root.player.shuffle
        }

        IconButton {
            icon: "skip_previous"
            size: 40
            enabled: root.player?.canGoPrevious ?? false
            onClicked: Media.previous()
        }

        IconButton {
            icon: Media.playing ? "pause" : "play_arrow"
            size: 52
            checked: true
            onClicked: Media.togglePlaying()
        }

        IconButton {
            icon: "skip_next"
            size: 40
            enabled: root.player?.canGoNext ?? false
            onClicked: Media.next()
        }

        IconButton {
            visible: root.player?.loopSupported ?? false
            icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
            checked: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
            size: 34
            onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
    }

    Flow {
        visible: Media.players.length > 1
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: Media.players

            Rectangle {
                id: chip

                required property MprisPlayer modelData
                readonly property bool current: modelData === root.player

                implicitWidth: chipText.implicitWidth + 20
                implicitHeight: 26
                radius: height / 2
                color: current ? Theme.primaryContainer : Theme.surfaceContainerHighest

                StyledText {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.identity
                    font.pixelSize: Theme.labelSmall
                    color: chip.current ? Theme.onPrimaryContainer : Theme.text
                }

                StateLayer {
                    anchors.fill: parent
                    onClicked: Media.lastPlaying = chip.modelData
                }
            }
        }
    }

    function fmt(seconds) {
        const s = Math.floor(seconds);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
}
