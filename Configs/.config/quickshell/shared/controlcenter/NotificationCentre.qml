import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.shared.services

// The notification centre of the control centre, drawn by both shells: a header with the count and
// "Clear All", an empty state, and the history as rows (app icon or its initial, title, app name,
// how long ago, a "×" under the pointer). A click on a row dismisses it.
//
// It was the island's own section of CcMainPage; the bar had a different list (cards, and only the
// last one or two on the main page). It is shared so the three UIs (the island, the HyDE bar and the
// minimal bar, which draws the bar's panels) show the same thing. Presentation is what each shell
// binds: the colours, the font and the animation scale are properties, never one shell's Theme.
// What it shows is the shared Notifications service.
Column {
    id: root

    // Style: the shell's, from CcTheme.
    property color foreground: CcTheme.foreground
    property color accent: CcTheme.accent
    property color dim: CcTheme.dim
    property color faint: CcTheme.faint
    property color hover: CcTheme.hover
    property color pressed: CcTheme.pressed
    property string fontFamily: CcTheme.fontFamily
    property real fontSize: CcTheme.fontSize
    // Milliseconds -> milliseconds, so a shell can scale or switch off its animations.
    property var duration: ms => CcTheme.duration(ms)

    // Layout.
    property int rowHeight: 46
    // Rows visible before the list scrolls; the shell lowers it when the screen is short.
    property int visibleRows: Math.min(rows.length, 4)

    // Where the list starts inside this item (below the header and the empty state), for a shell
    // that fits `visibleRows` to the room it has.
    readonly property real listY: list.y

    // Wall clock for "5m", refreshed while the centre exists.
    property date now: new Date()

    width: parent ? parent.width : implicitWidth
    spacing: 4

    // Notifications grouped by app (newest first). One entry stays a plain row; several collapse into a
    // header ("App · 18") that expands, on click, into its notifications.
    property var expanded: ({})
    readonly property var rows: {
        const order = [];
        const by = {};
        for (const n of Notifications.list) {
            const k = n.appName || "Notification";
            if (!by[k]) {
                by[k] = [];
                order.push(k);
            }
            by[k].push(n);
        }
        const out = [];
        for (const k of order) {
            const g = by[k];
            if (g.length === 1) {
                out.push({ kind: "single", n: g[0], app: k, count: 1 });
                continue;
            }
            out.push({ kind: "group", n: g[0], app: k, count: g.length });
            if (root.expanded[k])
                for (const n of g)
                    out.push({ kind: "child", n: n, app: k, count: g.length });
        }
        return out;
    }

    function toggleGroup(app) {
        const e = Object.assign({}, root.expanded);
        e[app] = !e[app];
        root.expanded = e;
    }

    function firstLine(n) {
        return String(n?.body ?? "").replace(/<[^>]*>/g, "").split("\n")[0].trim();
    }

    function ago(d) {
        const s = Math.max(0, (root.now.getTime() - new Date(d).getTime()) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)}m`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}h`;
        return `${Math.floor(s / 86400)}d`;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Header + "Clear All".
    Item {
        width: parent.width
        height: 26

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.count > 0 ? `Notifications  ·  ${Notifications.count}` : "Notifications"
            color: root.dim
            font.family: root.fontFamily
            renderType: CcTheme.textRendering
            topPadding: CcTheme.textPadding
            bottomPadding: CcTheme.textPadding
            font.pixelSize: root.fontSize - 1
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: clearLabel.implicitWidth + 20
            height: 24
            radius: height / 2
            visible: Notifications.count > 0
            color: clearMouse.pressed ? root.pressed : clearMouse.containsMouse ? root.hover : "transparent"

            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear All"
                color: clearMouse.containsMouse ? root.foreground : root.dim
                font.family: root.fontFamily
                renderType: CcTheme.textRendering
                topPadding: CcTheme.textPadding
                bottomPadding: CcTheme.textPadding
                font.pixelSize: root.fontSize - 1
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.clear()
            }
        }
    }

    // No notifications.
    Column {
        width: parent.width
        visible: Notifications.count === 0
        topPadding: 4
        bottomPadding: 8
        spacing: 2

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: root.faint
            font.family: root.fontFamily
            renderType: CcTheme.textRendering
            topPadding: CcTheme.textPadding
            bottomPadding: CcTheme.textPadding
            font.pixelSize: root.fontSize
        }

        Text {
            width: parent.width
            visible: Notifications.peaceMode
            horizontalAlignment: Text.AlignHCenter
            text: "Peace Mode is on"
            color: root.faint
            font.family: root.fontFamily
            renderType: CcTheme.textRendering
            topPadding: CcTheme.textPadding
            bottomPadding: CcTheme.textPadding
            font.pixelSize: root.fontSize - 2
        }
    }

    ListView {
        id: list
        width: parent.width
        height: root.visibleRows * root.rowHeight
        visible: Notifications.count > 0
        clip: true
        interactive: root.rows.length > root.visibleRows
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            values: root.rows
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: root.duration(140)
            }
        }
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: root.duration(180)
            }
        }
        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: root.duration(180)
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                to: 1
                duration: root.duration(120)
            }
        }

        delegate: Item {
            id: row

            required property var modelData
            readonly property var n: modelData.n
            readonly property bool isGroup: modelData.kind === "group"
            readonly property bool isChild: modelData.kind === "child"

            width: ListView.view.width
            height: root.rowHeight

            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.isGroup ? root.toggleGroup(row.modelData.app) : Notifications.dismiss(row.n)
            }

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 2
                anchors.bottomMargin: 2
                radius: 14
                color: rowMouse.pressed ? root.pressed : rowMouse.containsMouse ? root.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: root.duration(120)
                    }
                }
            }

            // App icon (or its initial, if there is none).
            Item {
                id: lead
                anchors.left: parent.left
                anchors.leftMargin: row.isChild ? 28 : 8
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28

                IconImage {
                    id: appIcon
                    anchors.fill: parent
                    source: Notifications.imageOf(row.n)
                    visible: status === Image.Ready
                    asynchronous: true
                    mipmap: true
                }

                Rectangle {
                    anchors.fill: parent
                    visible: appIcon.status !== Image.Ready
                    radius: width / 2
                    color: Qt.alpha(root.accent, 0.18)

                    Text {
                        anchors.centerIn: parent
                        text: (row.n?.appName || "?").charAt(0).toUpperCase()
                        color: root.accent
                        font.family: root.fontFamily
                        renderType: CcTheme.textRendering
                        topPadding: CcTheme.textPadding
                        bottomPadding: CcTheme.textPadding
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }
            }

            Column {
                anchors.left: lead.right
                anchors.leftMargin: 10
                anchors.right: trail.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    width: parent.width
                    text: row.isGroup ? `${row.modelData.app}  ·  ${row.modelData.count}` : (row.n?.summary || row.n?.appName || "")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.foreground
                    font.family: root.fontFamily
                    renderType: CcTheme.textRendering
                    topPadding: CcTheme.textPadding
                    bottomPadding: CcTheme.textPadding
                    font.pixelSize: root.fontSize - 1
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: row.isGroup ? (row.n?.summary || "") : (root.firstLine(row.n) || row.n?.appName || "Notification")
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.dim
                    font.family: root.fontFamily
                    renderType: CcTheme.textRendering
                    topPadding: CcTheme.textPadding
                    bottomPadding: CcTheme.textPadding
                    font.pixelSize: root.fontSize - 3
                }
            }

            // How long ago; with the pointer over the row, a "×" (clicking dismisses).
            Item {
                id: trail
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(timeLabel.implicitWidth, 16)
                height: 20

                Text {
                    id: timeLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isGroup || !rowMouse.containsMouse
                    text: row.isGroup ? (root.expanded[row.modelData.app] ? "▾" : "▸") : root.ago(Notifications.timeOf(row.n))
                    color: root.faint
                    font.family: root.fontFamily
                    renderType: CcTheme.textRendering
                    topPadding: CcTheme.textPadding
                    bottomPadding: CcTheme.textPadding
                    font.pixelSize: root.fontSize - 2
                }

                // The "×", two bars: no icon font needed, so it is the same in every shell.
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rowMouse.containsMouse && !row.isGroup
                    width: 12
                    height: 12

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 1.6
                        radius: 1
                        rotation: 45
                        color: root.dim
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 14
                        height: 1.6
                        radius: 1
                        rotation: -45
                        color: root.dim
                    }
                }
            }
        }
    }
}
