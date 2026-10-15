import QtQuick
import qs.config
import qs.theme
import qs.icons
import qs.services

// Small pill below the lock card: battery and, when music is playing, the title with the
// play/pause button. Without battery nor music it has width 0 (and is invisible).
Item {
    id: root

    readonly property bool showBattery: Battery.available
    readonly property bool showMedia: Media.active && Media.title !== ""
    readonly property bool empty: !showBattery && !showMedia

    implicitWidth: empty ? 0 : row.implicitWidth + 2 * 14
    implicitHeight: Pill.height
    opacity: empty ? 0 : 1
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(180)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.background, Theme.islandOpacity)
        border.width: 1
        border.color: Theme.border
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        BatteryIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBattery
            size: 14
            percent: Battery.percent
            charging: Battery.charging
        }

        // Separator between the battery and the music.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showBattery && root.showMedia
            width: 1
            height: 14
            color: Theme.border
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showMedia
            width: Math.min(implicitWidth, 260)
            text: Media.artist ? `${Media.title} · ${Media.artist}` : Media.title
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showMedia
            size: Pill.height - 10
            onClicked: Media.togglePlaying()

            MediaIcon {
                kind: Media.playing ? "pause" : "play"
                size: 14
            }
        }
    }
}
