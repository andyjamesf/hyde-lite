pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.island.config
import qs.island.theme
import qs.shared.services

// Lock screen background. At the bottom is the sharp wallpaper (the same as the desktop); on top,
// HyDE's blurred version (~/.cache/hyde/wall.blur, or wall.set blurred here if it does not exist)
// with a veil in the background colour. `blurred` controls the top layer: on unlock, the blur fades
// and the screen looks like the desktop before the lock is released.
// E-ink: only the background colour. Blur and veil: config/LockScreenConfig.qml.
Item {
    id: root

    property bool blurred: true
    readonly property string cacheDir: `${Paths.cacheHome}/hyde`

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Image {
        id: sharp
        anchors.fill: parent
        visible: !Theme.eink
        source: Theme.eink ? "" : `file://${root.cacheDir}/wall.set`
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
        sourceSize.height: root.height
        asynchronous: true
        cache: false
    }

    Item {
        anchors.fill: parent
        opacity: root.blurred ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(LockScreenConfig.blurFadeMs)
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: blur
            anchors.fill: parent
            visible: !Theme.eink && status === Image.Ready
            source: Theme.eink ? "" : `file://${root.cacheDir}/wall.blur`
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        // Without wall.blur: blur the sharp wallpaper.
        Loader {
            anchors.fill: parent
            active: !Theme.eink && blur.status === Image.Error && sharp.status === Image.Ready
            sourceComponent: MultiEffect {
                source: sharp
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: LockScreenConfig.blurMax
            }
        }

        // Veil: gives contrast to the card and the text.
        Rectangle {
            anchors.fill: parent
            color: Theme.eink ? Theme.background : Qt.alpha(Theme.background, LockScreenConfig.veil)
        }
    }
}
