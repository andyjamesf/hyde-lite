import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.services

// Tray: click activates, right click opens the app's menu, middle click runs the secondary action.
// "Passive" items are hidden, as in Waybar, and so are the apps listed in config.json
// (widgets.tray.hidden: by default the network, Bluetooth and disk applets, which the bar already
// covers). Monochrome icons are painted with the text color, so they are visible with any theme.
Row {
    id: root

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive && !(Config.widgets.tray.hidden ?? []).includes(i.id))
    property bool shown: items.length > 0

    spacing: 2
    leftPadding: 4
    rightPadding: 4

    Repeater {
        model: root.items

        StateLayer {
            id: item

            required property SystemTrayItem modelData
            // Icon name in the theme (apps send "image://icon/<name>" or their own image).
            readonly property string iconName: (/^image:\/\/icon\/([^?]+)/.exec(modelData.icon) ?? [])[1] ?? ""
            // Apps whose status icon is colored but that have a generic symbolic equivalent.
            readonly property var symbolicAliases: ({
                    "blueman-active": "bluetooth-active-symbolic",
                    "blueman-disabled": "bluetooth-disabled-symbolic",
                    "blueman-tray": "bluetooth-symbolic",
                    "blueman": "bluetooth-symbolic"
                })
            // Explicit symbolic version (we can't ask the theme for "<name>-symbolic": Qt
            // shortens names that don't exist and would return the colored icon).
            readonly property string symbolicName: {
                const alias = symbolicAliases[iconName] ?? "";
                return alias !== "" && Quickshell.hasThemeIcon(alias) ? alias : "";
            }
            readonly property bool hasSymbolic: symbolicName !== ""
            readonly property string source: hasSymbolic ? Quickshell.iconPath(symbolicName) : modelData.icon
            // Monochrome ones (symbolic, …-panel, nm-applet network, disks) are painted with the text
            // color; colored ones keep their original colors.
            readonly property bool mono: hasSymbolic || /symbolic|-panel|indicator|icon\/nm-|drive-removable|audio-volume|battery-/i.test(modelData.icon)

            width: Math.round(BarLayout.height * 0.9)
            height: Math.round(root.height * 0.72)
            anchors.verticalCenter: parent.verticalCenter

            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton)
                    modelData.secondaryActivate();
                else if (mouse.button === Qt.RightButton || modelData.onlyMenu)
                    modelData.hasMenu && menuAnchor.open();
                else
                    modelData.activate();
            }
            onScrolled: direction => modelData.scroll(direction * 120, false)

            IconImage {
                id: trayIcon
                anchors.centerIn: parent
                // Generic symbols (e.g. Bluetooth) fill the whole square, without the margin that
                // panel icons have; they are scaled down to match the size of the others.
                implicitSize: Math.round((BarLayout.iconSize - 1) * (item.hasSymbolic ? 0.78 : 1))
                source: item.source
                visible: !item.mono
            }

            // Monochrome icons painted with the text color. MultiEffect's colorization
            // multiplies by the icon's luminance, so the icon is first pushed to the right
            // extreme: white for light colors, black for dark colors (light themes).
            MultiEffect {
                readonly property color target: BarLayout.readable(Theme.text, 3)
                visible: item.mono
                anchors.fill: trayIcon
                source: trayIcon
                brightness: Theme.luminance(target) > 0.5 ? 1 : -1
                colorization: 1
                colorizationColor: target
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: item.modelData.menu
                anchor.item: item
                anchor.edges: BarLayout.atTop ? Edges.Bottom : Edges.Top
                anchor.gravity: BarLayout.atTop ? Edges.Bottom : Edges.Top
            }
        }
    }
}
