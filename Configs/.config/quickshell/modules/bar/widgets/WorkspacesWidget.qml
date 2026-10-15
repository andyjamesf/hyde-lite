import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services

// Hyprland workspaces: always at least `shown` visible, the occupied ones with their apps' icons,
// and an indicator that slides to this screen's active workspace. Scroll switches workspace.
Item {
    id: root

    property var bar
    property bool shown: true

    readonly property var cfg: Config.widgets.workspaces
    readonly property int activeId: bar?.monitor?.activeWorkspace?.id ?? 1
    readonly property int count: Math.max(cfg.shown, activeId, ...Hypr.workspaces.map(w => w.id))

    implicitWidth: row.implicitWidth + 8
    implicitHeight: BarLayout.height
    // Height of the active workspace indicator; the app icons sit 3 px inside it.
    readonly property int indicatorHeight: Math.round(height * 0.72)

    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y;
            if (Math.abs(acc) >= 120) {
                Hypr.dispatchFocusWorkspace(acc > 0 ? "e-1" : "e+1");
                acc = 0;
            }
        }
    }

    Rectangle {
        id: indicator

        readonly property Item target: repeater.count >= root.activeId ? repeater.itemAt(root.activeId - 1) : null

        x: row.x + (target?.x ?? 0)
        width: target?.width ?? 0
        height: root.indicatorHeight
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: BarLayout.readable(Theme.primary, 1.8)

        Behavior on x {
            NumberAnim {
                duration: Anim.spatial
                easing.bezierCurve: Anim.expressive
            }
        }
        Behavior on width {
            NumberAnim {
                duration: Anim.spatial
                easing.bezierCurve: Anim.expressive
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
            model: root.count

            Item {
                id: ws

                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property var toplevels: Hypr.toplevelsOn(wsId)
                readonly property bool occupied: toplevels.length > 0
                readonly property bool showIcons: root.cfg.appIcons && occupied

                width: Math.max(root.indicatorHeight, content.implicitWidth + Math.round(row.height * 0.5))
                height: row.height

                StateLayer {
                    anchors.fill: parent
                    anchors.topMargin: Math.round((row.height - root.indicatorHeight) / 2)
                    anchors.bottomMargin: Math.round((row.height - root.indicatorHeight) / 2)
                    highlight: ws.isActive ? "transparent" : Theme.hover
                    onClicked: Hypr.dispatchFocusWorkspace(ws.wsId)
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 3

                    Repeater {
                        model: ws.showIcons ? ws.toplevels.slice(0, root.cfg.maxIcons) : []

                        IconImage {
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Math.min(Math.round(BarLayout.iconSize * 0.9), root.indicatorHeight - 6)
                            source: Apps.iconFor(Hypr.appIdOf(modelData))
                        }
                    }

                    StyledText {
                        visible: !ws.showIcons
                        anchors.verticalCenter: parent.verticalCenter
                        text: ws.wsId
                        font.pixelSize: BarLayout.fontSize
                        font.weight: ws.isActive ? Font.Bold : Font.Normal
                        color: ws.isActive ? Theme.onPrimary : ws.occupied ? BarLayout.readable(Theme.text, 4.5) : BarLayout.readable(Theme.textFaint, 2.6)
                    }
                }
            }
        }
    }
}
