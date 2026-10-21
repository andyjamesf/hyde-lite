import QtQuick
import Quickshell
import qs.island.config
import qs.island.core
import qs.island.icons
import qs.island.services
import qs.island.theme

// Wallpaper picker in the island ("wallpaper" mode): title + count + refresh at the top and, below,
// a grid of 16:10 cards (up to 3 rows visible; the rest scrolls). Folders: config/WallpapersConfig.qml.
// The active one has the accent ring and the check mark; a click applies it through HyDE
// (Wallpapers.set) and the card shows a wheel until wall.set changes.
// Keyboard: arrows move the focus ring · Enter applies · Home/End · Esc is left to the island.
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through ModeSlot).
    property bool open: false

    readonly property real islandRadius: 26
    readonly property int sidePad: 16
    readonly property int headerHeight: Pill.height + 8
    readonly property int columns: 3
    readonly property int maxRows: 3
    readonly property int gap: 12
    readonly property real cellWidth: (implicitWidth - 2 * sidePad) / columns
    readonly property real cardWidth: cellWidth - gap
    readonly property real cardHeight: Math.round(cardWidth * 10 / 16)
    readonly property real cellHeight: cardHeight + gap

    readonly property var items: Wallpapers.list
    readonly property int count: items.length
    readonly property int rows: Math.ceil(count / columns)
    readonly property int visibleRows: Math.min(rows, maxRows)
    readonly property int currentIndex: indexOf(Wallpapers.current)
    readonly property string emptyText: Wallpapers.loading ? "Loading…" : "No wallpapers found"
    readonly property int bodyHeight: count > 0 ? visibleRows * cellHeight : 56

    // Card with the focus ring, and whether the keyboard was used (only then the ring shows).
    property int focusIndex: 0
    property bool keyboardUsed: false

    focus: true
    implicitWidth: 640
    implicitHeight: headerHeight + bodyHeight + sidePad - gap / 2

    onOpenChanged: if (open)
        reset()
    Component.onCompleted: if (open)
        reset()

    // The list arrived or changed: without keyboard navigation, the focus follows the current one.
    onItemsChanged: {
        if (!keyboardUsed)
            focusIndex = Math.max(0, currentIndex);
        else
            focusIndex = Math.max(0, Math.min(focusIndex, count - 1));
        if (open)
            Qt.callLater(scrollTo, focusIndex);
    }
    onCurrentIndexChanged: {
        if (!keyboardUsed && currentIndex >= 0) {
            focusIndex = currentIndex;
            Qt.callLater(scrollTo, focusIndex);
        }
    }

    // While open, the service watches wall.set.
    Binding {
        target: Wallpapers
        property: "active"
        value: true
        when: root.open
    }

    function reset() {
        keyboardUsed = false;
        Wallpapers.refresh();
        focusIndex = Math.max(0, currentIndex);
        Qt.callLater(scrollTo, focusIndex);
        // The window's keyboard focus only arrives a moment later: try again once.
        focusRetry.start();
    }

    function indexOf(path) {
        if (!path)
            return -1;
        for (let i = 0; i < items.length; ++i) {
            if (items[i].path === path)
                return i;
        }
        return -1;
    }

    function scrollTo(i) {
        if (i >= 0 && i < grid.count)
            grid.positionViewAtIndex(i, GridView.Contain);
    }

    function move(delta) {
        if (count === 0)
            return;
        if (!keyboardUsed) {
            // The first press only shows the ring where it is.
            keyboardUsed = true;
            return;
        }
        focusIndex = Math.max(0, Math.min(count - 1, focusIndex + delta));
        scrollTo(focusIndex);
    }

    function apply(i) {
        const e = items[i];
        if (!e)
            return;
        focusIndex = i;
        Wallpapers.set(e.path);
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left:
            move(-1);
            break;
        case Qt.Key_Right:
            move(1);
            break;
        case Qt.Key_Up:
            move(-columns);
            break;
        case Qt.Key_Down:
            move(columns);
            break;
        case Qt.Key_Home:
            keyboardUsed = true;
            focusIndex = 0;
            scrollTo(0);
            break;
        case Qt.Key_End:
            keyboardUsed = true;
            focusIndex = Math.max(0, count - 1);
            scrollTo(focusIndex);
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            apply(focusIndex);
            break;
        default:
            // Esc and the rest go on to the island.
            return;
        }
        event.accepted = true;
    }

    FocusRetry {
        id: focusRetry
        target: root
        when: root.open
    }

    // Under everything: swallows clicks outside the cards (they do not reach the island's "empty
    // space") and gives the focus back to the view.
    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    // Header: title, count, refresh.
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.sidePad + root.gap / 2
        anchors.rightMargin: root.sidePad
        height: root.headerHeight

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Label {
                anchors.baseline: countLabel.baseline
                text: "Wallpapers"
                font.pixelSize: Appearance.fontSize + 2
                font.weight: Font.DemiBold
            }
            Label {
                id: countLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.count > 0 ? String(root.count) : ""
                color: Theme.dim
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallpapers.theme !== ""
                text: "· " + Wallpapers.theme
                color: Theme.faint
            }
        }

        IconButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onClicked: {
                Wallpapers.refresh();
                root.forceActiveFocus();
            }

            RefreshIcon {
                size: 16
                color: Theme.dim
                spinning: Wallpapers.loading && Animations.enabled
            }
        }
    }

    Label {
        anchors.top: headerRow.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.bodyHeight
        visible: root.count === 0
        text: root.emptyText
        color: Theme.dim
    }

    GridView {
        id: grid
        anchors.top: headerRow.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.columns * root.cellWidth
        height: root.visibleRows * root.cellHeight
        visible: root.count > 0
        clip: true
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        boundsBehavior: Flickable.StopAtBounds
        interactive: root.rows > root.maxRows
        // Outside the bounds only one spare row: few images decoded at once.
        cacheBuffer: root.cellHeight
        highlightFollowsCurrentItem: false

        model: ScriptModel {
            values: root.items
            objectProp: "key"
        }

        delegate: Item {
            id: cell
            required property var modelData
            required property int index

            width: grid.cellWidth
            height: grid.cellHeight

            WallpaperCard {
                anchors.fill: parent
                anchors.margins: root.gap / 2
                entry: cell.modelData
                active: cell.modelData.path === Wallpapers.current
                focused: root.keyboardUsed && root.focusIndex === cell.index
                working: Wallpapers.busy && Wallpapers.pending === cell.modelData.path
                onClicked: {
                    root.forceActiveFocus();
                    root.apply(cell.index);
                }
            }
        }
    }
}
