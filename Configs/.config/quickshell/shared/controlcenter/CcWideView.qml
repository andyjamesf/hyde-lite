import QtQuick
import Quickshell.Widgets
import qs.shared.icons
import qs.shared.services

// The control centre's main page in two panes: the header across the top, Quick Settings (tiles,
// sliders, shortcuts) on the left, Now Playing and the notification centre on the right. It uses the
// same pieces as CcMainView (CcMainHeader, CcToggleTile, BigSlider, NotificationCentre), so the host
// only decides the width and what a click leads to, through the same signals.
//
// The cards are translucent veils over whatever the host draws behind the page, so the host's
// opacity setting shows through them.
Column {
    id: root

    property var tiles: ["wifi", "bluetooth", "mic", "dnd", "nightlight", "caffeine", "powerProfile", "colors"]
    property var shortcuts: ["nextwallpaper", "wallpaper", "animations", "keybindings", "syncshell", "barlayout"]
    // Name next to the "Quick Settings" title (the desktop's).
    property string badge: ""
    property int visibleRows: 3
    property int notificationRowHeight: 46

    // Tabs under the header: [{id, glyph, label}], the one shown, and what draws the ones that are not
    // "home" (the host's: the shell has the launcher, the notes…). No tabs, no bar.
    property var tabs: []
    property string tab: "home"
    property Component tabContent: null
    // A tab that needs more room than the Home panes asks for it here; 0 keeps their height.
    property int tabMinHeight: 0
    signal tabRequested(string id)

    signal pageRequested(string page)
    signal headerAction(string id)
    signal menuRequested(string id, Item item)
    signal hintRequested(bool on, string id, Item item)

    spacing: 12

    component Card: Rectangle {
        radius: 20
        color: Qt.alpha(CcTheme.foreground, 0.045)
        border.width: 1
        border.color: CcTheme.border
    }

    // A card's title row: icon glyph, title and something small on the right.
    component CardTitle: Item {
        property string glyph
        property string title
        property string trailing

        height: 26

        CcLabel {
            id: glyphLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.glyph
            font.family: CcTheme.nerdFont
            font.pixelSize: CcTheme.fontSize + 3
            elide: Text.ElideNone
            color: CcTheme.icon
        }
        CcLabel {
            anchors.left: glyphLabel.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: parent.title
            font.pixelSize: CcTheme.fontSize + 2
            font.weight: Font.DemiBold
        }
        CcLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.trailing
            color: CcTheme.dim
        }
    }

    CcMainHeader {
        width: parent.width
        onPageRequested: page => root.pageRequested(page)
        onHeaderAction: id => root.headerAction(id)
        onMenuRequested: (id, item) => root.menuRequested(id, item)
        onHintRequested: (on, id, item) => root.hintRequested(on, id, item)
    }

    Rectangle {
        width: parent.width
        height: 1
        color: CcTheme.border
    }

    // Tab bar: Home plus the host's tabs, as chips; the pointer on one shows its name only when it is
    // icon-only, so here the label is always shown.
    // The tab in use stays in the middle of the bar, with its name; the others slide past on either side.
    Item {
        id: tabBar
        visible: root.tabs.length > 0
        width: parent.width
        height: 32
        clip: true

        Row {
            id: tabRow
            spacing: 6
            height: parent.height

            // The chip of the open tab (the Repeater is a child too, and has no `current`).
            readonly property Item open: {
                for (let i = 0; i < children.length; i++)
                    if (children[i].current === true)
                        return children[i];
                return null;
            }
            // Fixed when every tab fits; it only slides to keep the open tab centred when they do not.
            x: open && childrenRect.width > tabBar.width ? Math.min(0, Math.max(tabBar.width - childrenRect.width, tabBar.width / 2 - (open.x + open.width / 2))) : 0

            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

        Repeater {
            model: root.tabs

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool current: modelData.id === root.tab

                width: chipRow.implicitWidth + (current ? 28 : 22)
                height: 32
                radius: height / 2
                color: current ? CcTheme.accent : chipMouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.05)
                border.width: current ? 0 : 1
                border.color: CcTheme.border

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 7

                    CcLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.glyph
                        font.family: CcTheme.nerdFont
                        font.pixelSize: CcTheme.fontSize + 1
                        elide: Text.ElideNone
                        color: chip.current ? CcTheme.accentContent : CcTheme.icon
                    }
                    // Only the tab in use keeps its name; the others are icons with a hint.
                    CcLabel {
                        visible: chip.current
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.label
                        font.weight: chip.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideNone
                        color: chip.current ? CcTheme.accentContent : CcTheme.foreground
                    }
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tabRequested(chip.modelData.id)
                    onContainsMouseChanged: root.hintRequested(containsMouse && !chip.current, `tab:${chip.modelData.label}`, chip)
                }
            }
        }
        }
    }

    // A tab other than Home: as tall as the Home panes, so the panel does not jump when it changes.
    Card {
        visible: root.tab !== "home" && root.tabContent !== null
        width: parent.width
        height: Math.max(panes.paneHeight, root.tabMinHeight)

        Loader {
            anchors.fill: parent
            sourceComponent: root.tab !== "home" ? root.tabContent : null
        }
    }

    Row {
        id: panes
        width: parent.width
        spacing: 12
        visible: root.tab === "home" || root.tabContent === null

        readonly property real paneWidth: (width - spacing) / 2
        // Both panes are as tall as the taller one wants to be.
        readonly property real paneHeight: Math.max(leftColumn.implicitHeight + 24, nowPlaying.height + rightColumn.spacing + notifCentre.implicitHeight + 24)

        // ── Left: Quick Settings ────────────────────────────────────────────
        Card {
            id: left
            width: panes.paneWidth
            height: panes.paneHeight

            Column {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                CardTitle {
                    width: parent.width
                    glyph: "\u{F0570}"
                    title: "Quick Settings"
                    trailing: root.badge
                }

                Flow {
                    id: tileFlow
                    width: parent.width
                    spacing: 8

                    readonly property real cell: (width - spacing) / 2
                    readonly property var ids: root.tiles.filter(t => CcToggles.shown.some(x => x.id === t))

                    Repeater {
                        model: tileFlow.ids

                        CcToggleTile {
                            required property string modelData
                            required property int index

                            toggleId: modelData
                            width: index === tileFlow.ids.length - 1 && tileFlow.ids.length % 2 !== 0 ? tileFlow.width : tileFlow.cell
                            onPageRequested: page => root.pageRequested(page)
                            onMenuRequested: root.menuRequested(modelData, this)
                        }
                    }
                }

                // Sliders in one inset card.
                Rectangle {
                    width: parent.width
                    height: sliders.implicitHeight + 20
                    radius: 16
                    color: Qt.alpha(CcTheme.foreground, 0.04)
                    border.width: 1
                    border.color: CcTheme.border

                    Column {
                        id: sliders
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        BigSlider {
                            id: volumeSlider
                            width: parent.width
                            value: Audio.volume
                            muted: Audio.muted
                            label: Audio.muted ? "Muted" : `${Math.round(Audio.volume * 100)}%`
                            iconClickable: true
                            onMoved: v => Audio.setVolume(v)
                            onIconClicked: Audio.toggleMute()

                            VolumeIcon {
                                size: 16
                                color: volumeSlider.iconColor
                                level: Audio.volume
                                muted: Audio.muted
                            }
                        }

                        BigSlider {
                            id: micSlider
                            width: parent.width
                            visible: Audio.source !== null && Audio.source !== undefined
                            value: Audio.micVolume
                            muted: Audio.micMuted
                            label: Audio.micMuted ? "Mic off" : `${Math.round(Audio.micVolume * 100)}%`
                            iconClickable: true
                            onMoved: v => Audio.setMicVolume(v)
                            onIconClicked: Audio.toggleMicMute()

                            CcLabel {
                                text: Audio.micMuted ? "\u{F036D}" : "\u{F036C}"
                                font.family: CcTheme.nerdFont
                                font.pixelSize: 16
                                elide: Text.ElideNone
                                color: micSlider.iconColor
                            }
                        }

                        BigSlider {
                            id: brightnessSlider
                            width: parent.width
                            visible: Brightness.available
                            value: Brightness.percent / 100
                            label: `${Brightness.percent}%`
                            throttle: CcTheme.sliderThrottleMs
                            onMoved: v => Brightness.set(v * 100)

                            BrightnessIcon {
                                size: 16
                                color: brightnessSlider.iconColor
                                level: Brightness.percent / 100
                            }
                        }
                    }
                }

                Row {
                    id: shortcutRow
                    width: parent.width

                    readonly property var ids: root.shortcuts.filter(id => CcShortcuts.shown.some(x => x.id === id))
                    visible: ids.length > 0

                    Repeater {
                        model: shortcutRow.ids

                        Item {
                            id: shortcutCell
                            required property string modelData
                            width: shortcutRow.width / Math.max(1, shortcutRow.ids.length)
                            height: 40

                            Rectangle {
                                anchors.centerIn: parent
                                width: 44
                                height: 36
                                radius: 14
                                color: shortcutMouse.pressed ? CcTheme.pressed : shortcutMouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.05)
                                border.width: 1
                                border.color: CcTheme.border

                                CcLabel {
                                    anchors.centerIn: parent
                                    text: CcShortcuts.get(shortcutCell.modelData)?.glyph ?? ""
                                    font.family: CcTheme.nerdFont
                                    font.pixelSize: 18
                                    elide: Text.ElideNone
                                    color: CcTheme.icon
                                }
                                MouseArea {
                                    id: shortcutMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: event => event.button === Qt.RightButton ? root.menuRequested(shortcutCell.modelData, parent) : CcShortcuts.run(shortcutCell.modelData)
                                    onContainsMouseChanged: root.hintRequested(containsMouse, shortcutCell.modelData, parent)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Right: Now Playing and Notifications ────────────────────────────
        Column {
            id: rightColumn
            width: panes.paneWidth
            spacing: 12

            Card {
                id: nowPlaying
                width: parent.width
                height: Media.active ? playerColumn.implicitHeight + 24 : 48

                readonly property var player: Media.player

                // MPRIS doesn't signal when the position advances.
                Timer {
                    interval: 1000
                    repeat: true
                    running: nowPlaying.visible && Media.playing
                    onTriggered: nowPlaying.player?.positionChanged()
                }

                Column {
                    id: playerColumn
                    visible: Media.active
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    CardTitle {
                        width: parent.width
                        glyph: "\u{F0387}"
                        title: "Now Playing"
                    }

                    Row {
                        width: parent.width
                        spacing: 12

                        ClippingRectangle {
                            width: 76
                            height: 76
                            radius: 14
                            color: Qt.alpha(CcTheme.accent, 0.2)

                            CcLabel {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "\u{F075A}"
                                font.family: CcTheme.nerdFont
                                font.pixelSize: 28
                                elide: Text.ElideNone
                                color: CcTheme.accent
                            }
                            Image {
                                id: art
                                anchors.fill: parent
                                source: Media.artUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 160
                                sourceSize.height: 160
                            }
                        }

                        Column {
                            width: parent.width - 76 - parent.spacing
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Column {
                                width: parent.width

                                CcLabel {
                                    width: parent.width
                                    text: Media.active ? (Media.title || "Untitled") : "Nothing playing"
                                    font.pixelSize: CcTheme.fontSize + 3
                                    font.weight: Font.DemiBold
                                }
                                CcLabel {
                                    width: parent.width
                                    text: Media.artist || Media.identity
                                    color: CcTheme.dim
                                }
                            }

                            Rectangle {
                                id: progress
                                width: parent.width
                                height: 5
                                radius: 3
                                color: CcTheme.hover
                                visible: Media.lengthSupported && Media.length > 0

                                Rectangle {
                                    width: Media.length > 0 ? parent.width * Math.min(1, Media.position / Media.length) : 0
                                    height: parent.height
                                    radius: 3
                                    color: CcTheme.accent
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.topMargin: -6
                                    anchors.bottomMargin: -6
                                    enabled: Media.canSeek
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => Media.seek(mouse.x / width)
                                }
                            }

                            CcLabel {
                                width: parent.width
                                visible: progress.visible
                                horizontalAlignment: Text.AlignRight
                                color: CcTheme.dim
                                font.pixelSize: CcTheme.fontSize - 2
                                text: {
                                    const f = s => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
                                    return `${f(Media.position)} / ${f(Media.length)}`;
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            model: [
                                {
                                    glyph: "\u{F04AE}",
                                    act: "prev",
                                    big: false
                                },
                                {
                                    glyph: "",
                                    act: "play",
                                    big: true
                                },
                                {
                                    glyph: "\u{F04AD}",
                                    act: "next",
                                    big: false
                                }
                            ]

                            Rectangle {
                                id: ctl
                                required property var modelData
                                readonly property bool usable: modelData.act === "prev" ? Media.canPrevious : modelData.act === "next" ? Media.canNext : Media.active
                                width: modelData.big ? 48 : 40
                                height: width
                                radius: width / 2
                                color: modelData.big ? CcTheme.accent : ctlMouse.pressed ? CcTheme.pressed : ctlMouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.05)
                                border.width: modelData.big ? 0 : 1
                                border.color: CcTheme.border
                                opacity: usable ? 1 : 0.4

                                CcLabel {
                                    anchors.centerIn: parent
                                    text: ctl.modelData.big ? (Media.playing ? "\u{F03E4}" : "\u{F040A}") : ctl.modelData.glyph
                                    font.family: CcTheme.nerdFont
                                    font.pixelSize: ctl.modelData.big ? 22 : 18
                                    elide: Text.ElideNone
                                    color: ctl.modelData.big ? CcTheme.accentContent : CcTheme.icon
                                }
                                MouseArea {
                                    id: ctlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: ctl.usable
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: root.hintRequested(containsMouse, `media-${ctl.modelData.act}`, ctl)
                                    onClicked: ctl.modelData.act === "prev" ? Media.previous() : ctl.modelData.act === "next" ? Media.next() : Media.togglePlaying()
                                }
                            }
                        }
                    }
                }

                CcLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !Media.active
                    text: "Now Playing · Nothing playing"
                    color: CcTheme.dim
                }
            }

            Card {
                width: parent.width
                height: panes.paneHeight - nowPlaying.height - rightColumn.spacing

                NotificationCentre {
                    id: notifCentre
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    rowHeight: root.notificationRowHeight
                    visibleRows: root.visibleRows
                }
            }
        }
    }
}
