import QtQuick
import QtQuick.Effects
import qs.config
import qs.icons
import qs.services
import qs.theme

// Media subview: a card with the blurred cover as background (a dark veil on top so the text reads;
// without a cover, a theme background), a thumbnail cover, title, artist, previous/play/next, a
// progress bar with seek (click or drag → Media.seek) and times, the current audio output and the
// player selector when there are several. The position is only requested (every
// MediaConfig.tickMs) while the page is visible. Sizes: config/MediaConfig.qml.
Item {
    id: root

    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int cardPad: MediaConfig.padding
    readonly property int artSize: MediaConfig.artSize
    readonly property real cardRadius: MediaConfig.cardRadius

    readonly property string outputName: (Audio.sinks ?? []).find(s => s.isDefault)?.name ?? ""
    readonly property var players: Media.players ?? []
    readonly property bool hasLength: (Media.lengthSupported ?? true) && (Media.length ?? 0) > 0
    readonly property real fraction: hasLength ? Math.max(0, Math.min(1, (Media.position ?? 0) / Media.length)) : 0

    implicitWidth: ControlCenter.width
    implicitHeight: card.y + card.height + pad

    // 75 → "1:15"; 3725 → "1:02:05".
    function formatTime(s) {
        s = Math.max(0, Math.floor(s || 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    // The MPRIS position does not advance by itself: it is requested regularly while visible.
    Timer {
        interval: MediaConfig.tickMs
        repeat: true
        triggeredOnStart: true
        running: root.shown && Media.active
        onTriggered: Media.tickPosition()
    }

    CcHeader {
        id: header
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        title: "Now Playing"
    }

    Item {
        id: card
        x: 12
        y: header.y + header.height + 6
        width: root.width - 24
        height: cardColumn.implicitHeight + 2 * root.cardPad

        // Background: blurred cover (or the theme background), clipped with the card's corners.
        Item {
            id: backdrop
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Theme.accent, 0.28)
                    }
                    GradientStop {
                        position: 1
                        color: Theme.surface
                    }
                }
            }

            Image {
                id: blurSource
                anchors.fill: parent
                source: Media.artUrl || ""
                fillMode: Image.PreserveAspectCrop
                // Small on purpose: it will be blurred, no point decoding it large.
                sourceSize.width: 160
                sourceSize.height: 160
                asynchronous: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: blurSource
                visible: blurSource.status === Image.Ready
                blurEnabled: true
                blur: 1
                blurMax: 64
                saturation: 0.15
                autoPaddingEnabled: false
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Animations.duration(300)
                    }
                }
            }

            // Veil for text contrast (stronger with a cover, because the cover may be light).
            Rectangle {
                anchors.fill: parent
                color: Theme.background
                opacity: blurSource.status === Image.Ready ? 0.55 : 0.25
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: "transparent"
            border.width: 1
            border.color: Theme.border
        }

        Item {
            id: cardMask
            anchors.fill: parent
            layer.enabled: true
            visible: false

            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "black"
            }
        }

        // Clicks that miss the controls stay here (they do not go to the "empty space").
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cardColumn
            x: root.cardPad
            y: root.cardPad
            width: parent.width - 2 * root.cardPad
            spacing: 14

            // Cover + texts
            Item {
                width: parent.width
                height: root.artSize

                Item {
                    id: art
                    width: root.artSize
                    height: root.artSize

                    readonly property bool hasCover: cover.status === Image.Ready

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.alpha(Theme.accent, 0.22)
                        visible: !art.hasCover

                        MediaIcon {
                            anchors.centerIn: parent
                            kind: "play"
                            size: 28
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
                            radius: 16
                            color: "black"
                        }
                    }
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Label {
                        width: parent.width
                        text: Media.title || "Unknown title"
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        font.pixelSize: Appearance.fontSize + 3
                        font.weight: Font.DemiBold
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: Media.artist
                        textFormat: Text.PlainText
                        color: Theme.dim
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: Media.identity ?? ""
                        textFormat: Text.PlainText
                        color: Theme.faint
                        font.pixelSize: Appearance.fontSize - 2
                    }
                }
            }

            // Progress + times
            Column {
                width: parent.width
                spacing: 2
                visible: root.hasLength

                Item {
                    id: seekBar
                    width: parent.width
                    height: 18

                    readonly property bool dragging: seekMouse.pressed
                    property real dragFraction: 0
                    readonly property real shown: dragging ? dragFraction : root.fraction

                    function fractionAt(x) {
                        return Math.max(0, Math.min(1, x / width));
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: seekMouse.containsMouse || seekBar.dragging ? 8 : 6
                        radius: height / 2
                        color: Qt.alpha(Theme.foreground, 0.16)

                        Behavior on height {
                            NumberAnimation {
                                duration: Animations.duration(120)
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: seekBar.shown <= 0 ? 0 : Math.max(height, parent.width * seekBar.shown)
                            radius: height / 2
                            color: Theme.accent

                            // Ticks are MediaConfig.tickMs apart: the linear animation smooths the jumps.
                            Behavior on width {
                                enabled: !seekBar.dragging
                                NumberAnimation {
                                    duration: Animations.duration(250)
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        enabled: Media.canSeek ?? false
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => seekBar.dragFraction = seekBar.fractionAt(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed)
                                seekBar.dragFraction = seekBar.fractionAt(mouse.x);
                        }
                        // Seek is only requested on release (dragging does not flood the player with requests).
                        onReleased: Media.seek(seekBar.dragFraction)
                    }
                }

                Item {
                    width: parent.width
                    height: 16

                    Label {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(seekBar.dragging ? seekBar.dragFraction * Media.length : Media.position)
                        color: Theme.dim
                        font.pixelSize: Appearance.fontSize - 2
                    }

                    Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.formatTime(Media.length)
                        color: Theme.dim
                        font.pixelSize: Appearance.fontSize - 2
                    }
                }
            }

            // Controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    enabled: Media.canPrevious
                    onClicked: Media.previous()

                    MediaIcon {
                        kind: "prev"
                        size: 20
                        color: Theme.icon
                    }
                }

                // Play/pause: a filled button in the accent colour.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 26
                    color: Theme.accent
                    scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.04 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Animations.duration(140)
                            easing.type: Easing.OutCubic
                        }
                    }

                    MediaIcon {
                        anchors.centerIn: parent
                        kind: Media.playing ? "pause" : "play"
                        size: 22
                        color: Theme.accentContent
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.togglePlaying()
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    enabled: Media.canNext
                    onClicked: Media.next()

                    MediaIcon {
                        kind: "next"
                        size: 20
                        color: Theme.icon
                    }
                }
            }

            // Current audio output
            Row {
                visible: root.outputName !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                VolumeIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 14
                    color: Theme.dim
                    level: Audio.volume
                    muted: Audio.muted
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, cardColumn.width - 40)
                    text: root.outputName
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font.pixelSize: Appearance.fontSize - 2
                }
            }

            // Player selector (only with more than one).
            Flow {
                width: parent.width
                visible: root.players.length > 1
                spacing: 6

                Repeater {
                    model: root.players

                    CcTextButton {
                        required property var modelData

                        text: modelData?.identity || "Player"
                        primary: modelData === Media.player
                        onClicked: Media.selectPlayer(modelData)
                    }
                }
            }
        }
    }
}
