import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.core
import qs.icons
import qs.services
import qs.theme

// Bluetooth subview: switch, scan button (starts/stops discovery) and the device list (connected
// first, then paired, then discovered ones). Clicking a paired device connects/disconnects it; the
// others get "Pair". The battery shows when the device reports it.
// Discovery started here stops when leaving the page.
Item {
    id: root

    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int rowHeight: ControlCenter.listRowHeight
    readonly property int maxRows: ControlCenter.maxListRows

    readonly property var devices: {
        const list = (Bluetooth.devices ?? []).slice();
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || String(a.name).localeCompare(String(b.name)));
        return list;
    }
    readonly property var byKey: {
        const m = {};
        for (const d of devices)
            m[d.key] = d;
        return m;
    }

    // Discovery was started by this page (and this page stops it when leaving).
    property bool startedDiscovery: false

    implicitWidth: ControlCenter.width
    implicitHeight: column.implicitHeight + 10 + pad

    function toggleDiscovery() {
        if (Bluetooth.discovering) {
            Bluetooth.stopDiscovery();
            startedDiscovery = false;
        } else {
            Bluetooth.startDiscovery();
            startedDiscovery = true;
        }
    }

    function stopOwnDiscovery() {
        if (startedDiscovery && Bluetooth.discovering)
            Bluetooth.stopDiscovery();
        startedDiscovery = false;
    }

    // Battery in percent, or "" if there is none (−1). Comes in 0..100; a fraction (0..1, not an
    // integer) is accepted too.
    function batteryText(b) {
        if (typeof b !== "number" || !isFinite(b) || b < 0)
            return "";
        return `${Math.round(b < 1 && !Number.isInteger(b) ? b * 100 : b)}%`;
    }

    onShownChanged: {
        if (!shown)
            stopOwnDiscovery();
    }
    Component.onDestruction: stopOwnDiscovery()

    Column {
        id: column
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        spacing: 8

        CcHeader {
            width: parent.width
            title: "Bluetooth"

            IconButton {
                id: scanButton
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                visible: Bluetooth.enabled
                onClicked: root.toggleDiscovery()

                Glyph {
                    id: scanGlyph
                    kind: "refresh"
                    size: 16
                    color: Bluetooth.discovering ? Theme.accent : Theme.dim

                    RotationAnimation on rotation {
                        running: Bluetooth.discovering && Animations.enabled
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                        // When stopping, it goes back upright.
                        onStopped: scanGlyph.rotation = 0
                    }
                }
            }

            CcSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Bluetooth.enabled
                enabled: Bluetooth.available
                onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
            }
        }

        Label {
            width: parent.width
            leftPadding: 6
            text: !Bluetooth.available ? "No Bluetooth adapter" : !Bluetooth.enabled ? "Bluetooth is off" : Bluetooth.discovering ? "Searching for devices…" : Bluetooth.connected ? `Connected: ${Bluetooth.summary}` : "Not connected"
            textFormat: Text.PlainText
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        Label {
            width: parent.width
            height: 44
            visible: Bluetooth.enabled && root.devices.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Bluetooth.discovering ? "Searching…" : "No devices found"
            color: Theme.faint
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, root.maxRows * root.rowHeight)
            visible: Bluetooth.enabled && root.devices.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: root.devices
                objectProp: "key"
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Animations.duration(180)
                }
            }
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Animations.duration(120)
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: Animations.duration(200)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "opacity"
                    to: 1
                    duration: Animations.duration(120)
                }
            }

            delegate: Item {
                id: row

                required property var modelData
                readonly property var dev: root.byKey[modelData.key] ?? modelData
                readonly property bool hovered: rowMouse.containsMouse || actionButton.hovered
                readonly property string battery: root.batteryText(dev.battery)

                width: ListView.view.width
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 16
                    color: rowMouse.pressed ? Theme.pressed : row.hovered ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Animations.duration(120)
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.dev.connecting ? Qt.BusyCursor : Qt.PointingHandCursor
                    onClicked: {
                        const d = row.dev;
                        if (d.connecting)
                            return;
                        if (!d.paired)
                            Bluetooth.pairDevice(d.key);
                        else if (d.connected)
                            Bluetooth.disconnectDevice(d.key);
                        else
                            Bluetooth.connectDevice(d.key);
                    }
                }

                // Theme icon for the device type; without it, the Bluetooth one.
                Item {
                    id: lead
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    IconImage {
                        id: devIcon
                        anchors.fill: parent
                        source: row.dev.icon ? Quickshell.iconPath(row.dev.icon, true) : ""
                        visible: status === Image.Ready
                        asynchronous: true
                        mipmap: true
                        opacity: row.dev.connected ? 1 : 0.7
                    }

                    BluetoothIcon {
                        anchors.centerIn: parent
                        visible: devIcon.status !== Image.Ready
                        size: 18
                        connected: row.dev.connected
                        color: row.dev.connected ? Theme.accent : Theme.icon
                    }
                }

                Column {
                    anchors.left: lead.right
                    anchors.leftMargin: 12
                    anchors.right: actionButton.visible ? actionButton.left : parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Label {
                        width: parent.width
                        text: row.dev.name || "Unknown device"
                        textFormat: Text.PlainText
                        font.weight: row.dev.connected ? Font.DemiBold : Font.Normal
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: {
                            const d = row.dev;
                            const state = d.connecting ? "Connecting…" : d.connected ? "Connected" : d.paired ? "Paired" : "";
                            return [state, row.battery !== "" ? `Battery ${row.battery}` : ""].filter(s => s !== "").join("  ·  ");
                        }
                        color: row.dev.connected ? Theme.accent : Theme.dim
                        font.pixelSize: Appearance.fontSize - 2
                    }
                }

                // Not paired: "Pair"; paired (with the pointer over it): "Forget".
                CcTextButton {
                    id: actionButton
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !row.dev.paired || (row.hovered && !row.dev.connecting)
                    primary: !row.dev.paired
                    enabled: !row.dev.connecting
                    text: row.dev.paired ? "Forget" : "Pair"
                    onClicked: {
                        if (row.dev.paired)
                            Bluetooth.forgetDevice(row.dev.key);
                        else
                            Bluetooth.pairDevice(row.dev.key);
                    }
                }
            }
        }
    }
}
