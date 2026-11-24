import QtQuick
import qs.shared.icons
import qs.shared.services

// The main page of the control centre, drawn by every UI of this configuration: a header (your
// picture and name, time since boot, battery, system, settings, lock and power), the toggle tiles
// (CcToggles) in two columns, the volume, microphone and brightness sliders, the media row, the
// shortcut buttons (CcShortcuts) and the notification centre.
//
// It was the island's page. The bar had its own, with round buttons and a different order, and the
// owner wanted the island's in both shells, so it is shared: what each shell contributes is its look
// (CcTheme) and what a click leads to, as signals — the island opens its own pages and menus, the
// bar its panel's pages. The host puts it in a window and decides the width and the padding.
Column {
    id: root

    // Ids of the tiles and of the shortcut buttons to show, in order. A tile or a button whose
    // entry is not available (no Bluetooth adapter, a picker that is not registered) is left out.
    property var tiles: ["wifi", "bluetooth", "sound", "mic", "dnd", "nightlight", "caffeine", "powerProfile", "colors"]
    property var shortcuts: ["nextwallpaper", "wallpaper", "animations", "keybindings", "syncshell"]

    // Tiles per row (the island has 2; a wide window can take more, so the page is not so tall).
    property int columns: 2
    // What draws the media row. A shell with a player of its own puts it here (the bar's, with
    // progress and controls); the default is the island's compact row.
    property Component media: defaultMedia

    // Notification rows visible before the list scrolls (the host lowers it on a short screen).
    property int visibleRows: Math.min(Notifications.count, 4)
    property int notificationRowHeight: 46

    // A detail page: "wifi", "bluetooth", "audio", "battery", "media".
    signal pageRequested(string page)
    // A header button: "avatar" (choose another picture), "system", "settings", "lock", "power".
    signal headerAction(string id)
    // Right click on a tile, a header button or a shortcut: the host may show a menu.
    signal menuRequested(string id, Item item)
    // The pointer is over (on) or left (off) a header button or a shortcut: the host may show a hint.
    signal hintRequested(bool on, string id, Item item)

    // Where the notification list starts, for a host that fits `visibleRows` to the room it has.
    readonly property real notificationsY: notifCentre.y + notifCentre.listY

    spacing: 12

    CcMainHeader {
        width: parent.width
        onPageRequested: page => root.pageRequested(page)
        onHeaderAction: id => root.headerAction(id)
        onMenuRequested: (id, item) => root.menuRequested(id, item)
        onHintRequested: (on, id, item) => root.hintRequested(on, id, item)
    }

    // Tiles in `columns` columns; a last tile that would be alone in a row takes the rest of it.
    Flow {
        id: tileFlow
        width: parent.width
        spacing: 10

        readonly property real cell: (width - spacing * (root.columns - 1)) / root.columns
        // What is offered is CcToggles', in the order and with the tiles the host asks for; what is
        // not available is left out.
        readonly property var ids: root.tiles.filter(t => CcToggles.shown.some(x => x.id === t))

        Repeater {
            model: tileFlow.ids

            CcToggleTile {
                required property string modelData
                required property int index

                toggleId: modelData
                // In the last, partial row the last tile takes what is left of the row.
                width: index === tileFlow.ids.length - 1 && tileFlow.ids.length % root.columns !== 0 ? tileFlow.width - (tileFlow.ids.length % root.columns - 1) * (tileFlow.cell + tileFlow.spacing) : tileFlow.cell
                onPageRequested: page => root.pageRequested(page)
                onMenuRequested: root.menuRequested(modelData, this)
            }
        }
    }

    // Sliders.
    Column {
        width: parent.width
        spacing: 10

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
            // Every change is a process (brightnessctl): at most one per CcTheme.sliderThrottleMs.
            throttle: CcTheme.sliderThrottleMs
            onMoved: v => Brightness.set(v * 100)

            BrightnessIcon {
                size: 16
                color: brightnessSlider.iconColor
                level: Brightness.percent / 100
            }
        }
    }

    Loader {
        width: parent.width
        visible: Media.active
        sourceComponent: root.media
    }

    Component {
        id: defaultMedia

        CcMediaRow {
            onPageRequested: root.pageRequested("media")
        }
    }

    // Shortcuts: icon buttons spread over the width; the pointer on one shows what it does.
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
                    radius: 18
                    color: shortcutMouse.pressed ? CcTheme.pressed : shortcutMouse.containsMouse ? CcTheme.hover : Qt.alpha(CcTheme.foreground, 0.04)
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

    NotificationCentre {
        id: notifCentre
        width: parent.width
        rowHeight: root.notificationRowHeight
        visibleRows: root.visibleRows
    }
}
