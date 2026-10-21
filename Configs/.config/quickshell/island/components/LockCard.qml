import QtQuick
import Quickshell.Widgets
import qs.island.config
import qs.island.theme
import qs.island.services

// Content of the lock card (the island open at the centre of the screen): large time and date,
// avatar (LockScreenConfig.avatarPath, circular, or the name's initial), user name, password field
// and the error line. Sizes: config/LockScreenConfig.qml.
Item {
    id: root

    // Island radius while showing this content.
    readonly property real islandRadius: LockScreenConfig.cardRadius

    function focusField() {
        field.focusField();
    }

    implicitWidth: LockScreenConfig.cardWidth
    implicitHeight: column.implicitHeight + 2 * LockScreenConfig.cardPadding

    // Wrong password: the field shakes and is emptied.
    Connections {
        target: Lock
        function onFailuresChanged() {
            if (Lock.failures > 0) {
                field.clear();
                field.shake();
            }
        }
    }

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 0

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.time
            font.pixelSize: LockScreenConfig.clockSize
            font.weight: Font.Light
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.longDate
            color: Theme.dim
            font.pixelSize: Appearance.fontSize + 2
        }

        Item {
            width: 1
            height: 26
        }

        // Avatar
        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: LockScreenConfig.avatarSize
            height: LockScreenConfig.avatarSize
            radius: width / 2
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            Label {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: (Lock.userName || "?").charAt(0).toUpperCase()
                color: Theme.accent
                font.pixelSize: Math.round(LockScreenConfig.avatarSize * 0.42)
                font.weight: Font.DemiBold
            }

            Image {
                id: avatar
                anchors.fill: parent
                source: `file://${Paths.expand(LockScreenConfig.avatarPath)}`
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: LockScreenConfig.avatarSize * 2
                sourceSize.height: LockScreenConfig.avatarSize * 2
                asynchronous: true
                cache: false
            }
        }

        Item {
            width: 1
            height: 10
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, 320)
            horizontalAlignment: Text.AlignHCenter
            text: Lock.userName
            font.pixelSize: Appearance.fontSize + 3
            font.weight: Font.DemiBold
        }

        Item {
            width: 1
            height: 18
        }

        PasswordField {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: LockScreenConfig.fieldWidth
            implicitHeight: LockScreenConfig.fieldHeight
            sidePadding: 20
            horizontalAlignment: TextInput.AlignHCenter
            escapeClears: true
            acceptsInput: !Lock.authenticating && !Lock.unlocking
            busy: Lock.authenticating
            hasError: Lock.error !== ""
            // The secret goes straight to PAM; the field is already empty.
            onSubmitted: secret => Lock.submit(secret)
            // Typing again clears the previous error.
            onEdited: if (hasError)
                Lock.clearError()
        }

        // Up to two lines: PAM's notices ("Account locked after failed attempts. Try again in 10 min")
        // are longer than "Wrong password".
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            height: Math.max(26, implicitHeight)
            width: Math.min(implicitWidth, 320)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignBottom
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            text: Lock.error
            color: Theme.danger
            opacity: Lock.error !== "" ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(150)
                }
            }
        }
    }
}
