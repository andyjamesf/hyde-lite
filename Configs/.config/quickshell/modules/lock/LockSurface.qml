import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Lock screen contents (one per monitor): HyDE's blurred wallpaper, clock, user,
// password and, at the bottom, battery and what's playing.
Item {
    id: root

    anchors.fill: parent

    // Fades in (the compositor has already covered the screen in black at the moment of locking).
    opacity: 0
    Component.onCompleted: {
        opacity = 1;
        focusTimer.restart();
    }
    Behavior on opacity {
        NumberAnim {
            duration: Anim.slow
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: input.forceActiveFocus()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Image {
        anchors.fill: parent
        source: `file://${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/hyde/wall.blur`
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.surface, 0.45)
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        spacing: 6

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Utils.formatDate(clock.date, "HH:mm")
            font.pixelSize: Theme.display * 2
            font.weight: Font.Light
            color: Theme.text
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            // Only the first letter capitalized (e.g. Portuguese "Quarta-feira, 23 de setembro").
            text: Utils.formatDate(clock.date, "dddd, d MMMM").replace(/^./, c => c.toUpperCase())
            font.pixelSize: Theme.titleLarge
            color: Theme.textDim
        }

        Item {
            implicitHeight: 40
        }

        ClippingRectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 84
            implicitHeight: 84
            radius: height / 2
            color: Theme.primaryContainer

            MaterialIcon {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                icon: "person"
                size: 44
                fill: 1
                color: Theme.onPrimaryContainer
            }

            Image {
                id: avatar
                anchors.fill: parent
                source: SysInfo.avatar
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 168
                sourceSize.height: 168
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 8
            text: SysInfo.user
            font.pixelSize: Theme.titleLarge
            font.weight: Font.DemiBold
        }

        // Password
        Rectangle {
            id: field

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 320
            implicitHeight: 52
            radius: height / 2
            color: Theme.alpha(Theme.surfaceContainerHigh, 0.9)
            border.width: 2
            border.color: Lock.error !== "" ? Theme.error : input.activeFocus ? Theme.primary : Theme.outlineVariant

            // Shakes when the password is wrong.
            transform: Translate {
                id: shakeX
            }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 14
                    duration: 50
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: -14
                    duration: 100
                }
                NumberAnimation {
                    target: shakeX
                    property: "x"
                    to: 0
                    duration: 50
                }
            }

            Connections {
                target: Lock
                function onFailuresChanged() {
                    if (Lock.failures > 0) {
                        input.text = "";
                        shake.restart();
                    }
                }
            }

            MaterialIcon {
                id: keyIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                icon: Lock.authenticating ? "hourglass_top" : "lock"
                size: 20
                color: Theme.primary
            }

            TextInput {
                id: input
                anchors.left: keyIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: Theme.text
                font.family: Config.appearance.font
                font.pixelSize: Theme.titleMedium
                font.letterSpacing: 2
                clip: true
                enabled: !Lock.authenticating
                focus: true

                onAccepted: Lock.submit(text)
                Keys.onEscapePressed: text = ""

                StyledText {
                    visible: input.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: Lock.authenticating ? "Checking…" : "Password"
                    color: Theme.textFaint
                    font.pixelSize: Theme.titleMedium
                    font.letterSpacing: 0
                }
            }
        }

        // Up to two lines: PAM's notices ("Account locked after failed attempts. Try again in 10 min")
        // are longer than "Wrong password".
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Math.max(20, implicitHeight)
            Layout.maximumWidth: 340
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            text: Lock.error
            color: Theme.error
            font.pixelSize: Theme.bodyMedium
        }
    }

    // Footer: battery and media
    RowLayout {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        Rectangle {
            visible: Battery.available
            implicitWidth: battRow.implicitWidth + 28
            implicitHeight: 44
            radius: height / 2
            color: Theme.alpha(Theme.surfaceContainer, 0.85)

            RowLayout {
                id: battRow
                anchors.centerIn: parent
                spacing: 6

                MaterialIcon {
                    icon: Battery.icon
                    fill: 1
                    size: 20
                    color: Battery.low ? Theme.error : Theme.text
                }

                StyledText {
                    text: `${Battery.percent}%`
                }
            }
        }

        Rectangle {
            visible: Media.active !== null && Media.title !== ""
            implicitWidth: Math.min(420, mediaRow.implicitWidth + 28)
            implicitHeight: 44
            radius: height / 2
            color: Theme.alpha(Theme.surfaceContainer, 0.85)

            RowLayout {
                id: mediaRow
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 6

                MaterialIcon {
                    icon: "music_note"
                    fill: 1
                    size: 18
                    color: Theme.primary
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 280
                    text: Media.artist ? `${Media.title} · ${Media.artist}` : Media.title
                }

                IconButton {
                    icon: "skip_previous"
                    size: 30
                    onClicked: Media.previous()
                }

                IconButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 30
                    onClicked: Media.togglePlaying()
                }

                IconButton {
                    icon: "skip_next"
                    size: 30
                    onClicked: Media.next()
                }
            }
        }
    }
}
