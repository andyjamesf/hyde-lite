import QtQuick
import qs.config
import qs.components
import qs.services

// Lock screen content on one monitor. The star is the island itself: it starts as the clock pill
// at the top (where it sits on the desktop) and, on the screen with the card, grows with the same
// critical springs into the lock card at the centre (core/IslandSurface.qml). On unlock it goes the
// reverse way and the background blur fades; only then is the lock released (Lock.releaseTimer).
// Other screens only show the clock pill over the wallpaper. Sizes: config/LockScreenConfig.qml.
Item {
    id: root

    required property string screenName

    readonly property bool cardHere: Lock.cardScreen === screenName
    // Becomes true shortly after the surface appears, so the pill is seen before it transforms.
    property bool ready: false
    readonly property bool shown: ready && !Lock.unlocking
    // "fade" entry (config/LockScreenConfig.qml): no pill; the card sits at its place and fades.
    readonly property bool fade: LockScreenConfig.entry === "fade"
    readonly property bool expanded: shown && cardHere
    // Whether the card is laid out at its full size and place (always, with the fade entry).
    readonly property bool open: fade || expanded

    // Keyboard focus of this surface (the compositor gives it to the focused monitor): the card
    // comes here, so typing always happens on the screen being looked at.
    readonly property bool windowActive: Window.active

    function focusCard() {
        focusTimer.restart();
    }

    anchors.fill: parent

    onWindowActiveChanged: {
        if (windowActive) {
            Lock.focusScreen(screenName);
            focusCard();
        }
    }
    onExpandedChanged: {
        if (expanded)
            focusCard();
    }
    Component.onCompleted: introTimer.start()

    Timer {
        id: introTimer
        interval: Animations.duration(120)
        onTriggered: root.ready = true
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            if (root.cardHere && cardLoader.item)
                cardLoader.item.focusField();
        }
    }

    LockBackground {
        anchors.fill: parent
        blurred: root.shown
    }

    // Clicking a screen brings the card to it (and gives the focus back to the field).
    MouseArea {
        anchors.fill: parent
        onClicked: {
            Lock.focusScreen(root.screenName);
            root.focusCard();
        }
    }

    Spring {
        id: ys
        // Slightly above the centre (LockScreenConfig.cardOffset): the status pill fits below.
        target: root.open ? Math.round((root.height - island.targetHeight) / 2 + root.height * LockScreenConfig.cardOffset) : Pill.topMargin
    }

    IslandSurface {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(ys.value)
        // With the fade entry the whole surface fades; with the rise entry it morphs from the pill.
        opacity: root.fade ? (root.expanded ? 1 : 0) : 1
        targetWidth: root.open ? (cardLoader.item?.implicitWidth ?? LockScreenConfig.cardWidth) : clock.implicitWidth
        targetHeight: root.open ? (cardLoader.item?.implicitHeight ?? 420) : Pill.height
        maxRadius: cardLoader.item?.islandRadius ?? LockScreenConfig.cardRadius

        Behavior on opacity {
            NumberAnimation {
                duration: Animations.duration(root.expanded ? Animations.fadeIn : Animations.fadeOut)
                easing.type: Easing.OutCubic
            }
        }

        // Clicks inside the island do not reach the background MouseArea.
        MouseArea {
            anchors.fill: parent
            onClicked: root.focusCard()
        }

        // Collapsed: exactly the island's clock pill.
        ClockView {
            id: clock
            anchors.centerIn: parent
            opacity: root.open ? 0 : 1
            scale: root.open ? Animations.scaleFrom : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(root.expanded ? Animations.fadeOut : Animations.fadeIn)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Animations.duration(Animations.scaleDuration)
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Open: the lock card. It only exists on the card's screen (a single password field) and
        // while it fades out when leaving.
        Loader {
            id: cardLoader
            anchors.centerIn: parent
            active: root.fade ? root.cardHere : (root.cardHere || opacity > 0.01)
            // The fade entry fades the whole surface (island.opacity), not the card inside it.
            opacity: root.fade || root.expanded ? 1 : 0
            scale: root.fade || root.expanded ? 1 : Animations.scaleFrom
            // No `visible: false` while transparent: an invisible item cannot hold the focus and the
            // field must get it right at the start of the transformation.
            focus: true
            sourceComponent: LockCard {}
            onLoaded: root.focusCard()

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(root.expanded ? Animations.fadeIn : Animations.fadeOut)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Animations.duration(Animations.scaleDuration)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // Battery and music, below the card.
    LockStatus {
        anchors.horizontalCenter: parent.horizontalCenter
        y: island.y + island.height + 14
        opacity: root.expanded && !empty ? 1 : 0
    }
}
