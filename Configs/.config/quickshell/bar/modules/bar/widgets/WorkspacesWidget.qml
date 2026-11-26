import QtQuick
import Quickshell.Widgets
import qs.bar.components
import qs.bar.services
import qs.shared.services

// Hyprland workspaces: always at least `shown` visible, the occupied ones with their apps' icons,
// and an indicator that slides to this screen's active workspace. Scroll switches workspace.
Item {
    id: root

    property var bar
    property bool shown: true

    readonly property var cfg: Config.widgets.workspaces
    readonly property int activeId: bar?.monitor?.activeWorkspace?.id ?? 1
    readonly property int count: Math.max(cfg.shown, activeId, ...Workspaces.workspaces.map(w => w.id))
    // Ids shown, in order: all of 1..count, or with `hideEmpty` only the ones with windows, the active
    // one and the first `shown` (so a fresh session still shows something to click).
    readonly property var ids: {
        const all = Array.from({
            length: count
        }, (_, i) => i + 1);
        return cfg.hideEmpty ? all.filter(id => id <= cfg.shown || id === activeId || Workspaces.toplevelsOn(id).length > 0) : all;
    }

    implicitWidth: row.implicitWidth + 8
    implicitHeight: BarLayout.height
    // Height of the active workspace indicator; the app icons sit 3 px inside it.
    readonly property int indicatorHeight: Math.round(height * 0.72)

    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y;
            if (Math.abs(acc) >= 120) {
                Workspaces.focus(acc > 0 ? "e-1" : "e+1");
                acc = 0;
            }
        }
    }

    Rectangle {
        id: indicator

        readonly property Item target: repeater.itemAt(root.ids.indexOf(root.activeId))

        x: row.x + (target?.x ?? 0)
        width: target?.width ?? 0
        height: root.indicatorHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        // Softened: a fully saturated accent behind the active workspace is too loud.
        color: BarLayout.readable(Theme.blend(BarLayout.pillBase, Theme.primary, 0.6), 1.8)

        Behavior on x {
            NumberAnim {
                duration: Anim.fast
                easing.bezierCurve: Anim.standard
            }
        }
        Behavior on width {
            NumberAnim {
                duration: Anim.fast
                easing.bezierCurve: Anim.standard
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        height: root.height
        spacing: 2

        Repeater {
            id: repeater
            model: root.ids

            Item {
                id: ws

                required property int index
                required property int modelData
                readonly property int wsId: modelData
                readonly property bool isActive: wsId === root.activeId
                readonly property var toplevels: Workspaces.toplevelsOn(wsId)
                readonly property bool occupied: toplevels.length > 0
                readonly property int maxIcons: root.cfg.maxIcons
                readonly property bool showIcons: root.cfg.appIcons && occupied

                width: Math.max(root.indicatorHeight, content.implicitWidth + Math.round(row.height * 0.5))
                height: row.height

                StateLayer {
                    anchors.fill: parent
                    anchors.topMargin: Math.round((row.height - root.indicatorHeight) / 2)
                    anchors.bottomMargin: Math.round((row.height - root.indicatorHeight) / 2)
                    highlight: ws.isActive ? "transparent" : Theme.hover
                    onClicked: Workspaces.focus(ws.wsId)
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 3

                    // The number of every workspace, next to its apps (two identical icons still tell which
                    // workspace is which). Always there, so switching workspace does not change any width.
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ws.wsId
                        font.pixelSize: BarLayout.fontSize
                        font.weight: Font.DemiBold
                        color: ws.isActive ? Theme.onPrimary : ws.occupied ? BarLayout.readableFor(ws, Theme.text, 4.5) : BarLayout.readableFor(ws, Theme.textFaint, 2.6)
                    }

                    // The active workspace's apps at full strength, the others a step back.
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: content.spacing
                        opacity: ws.isActive ? 1 : 0.65

                        Repeater {
                            model: ws.showIcons ? ws.toplevels.slice(0, ws.maxIcons) : []

                            IconImage {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Math.min(Math.round(BarLayout.iconSize * 0.9), root.indicatorHeight - 6)
                                source: Apps.iconFor(Workspaces.appIdOf(modelData))
                            }
                        }
                    }

                    // Windows beyond the icons shown: how many more there are.
                    StyledText {
                        visible: ws.showIcons && ws.toplevels.length > ws.maxIcons
                        anchors.verticalCenter: parent.verticalCenter
                        text: `+${ws.toplevels.length - ws.maxIcons}`
                        font.pixelSize: BarLayout.fontSize - 2
                        color: ws.isActive ? Theme.onPrimary : BarLayout.readableFor(ws, Theme.textDim, 3.5)
                    }

                }
            }
        }
    }
}
