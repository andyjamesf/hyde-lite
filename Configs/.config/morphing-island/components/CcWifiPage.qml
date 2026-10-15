import QtQuick
import Quickshell
import qs.config
import qs.core
import qs.icons
import qs.services
import qs.theme

// Wi-Fi subview: switch, current network and the network list (connected first, then saved ones,
// then by signal). Clicking a network → Network.connect(key); if the network needs a password
// (Network.pendingKey === key) a field opens below it.
// While the page is on screen, it counts as a scan user (Network.scanUsers).
Item {
    id: root

    property bool shown: false

    readonly property int pad: ControlCenter.padding
    readonly property int rowHeight: ControlCenter.listRowHeight
    readonly property int passwordHeight: 52
    readonly property int maxRows: ControlCenter.maxListRows

    readonly property var networks: {
        const list = (Network.networks ?? []).slice();
        list.sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.strength - a.strength));
        return list;
    }
    // Key → current entry (the delegates read fresh data from here).
    readonly property var byKey: {
        const m = {};
        for (const n of networks)
            m[n.key] = n;
        return m;
    }
    readonly property bool hasPending: Network.pendingKey !== "" && byKey[Network.pendingKey] !== undefined

    // The password field released the focus: the view gives it back to the island (for Esc).
    signal releaseFocus

    implicitWidth: ControlCenter.width
    implicitHeight: column.implicitHeight + 10 + pad

    // Scan user count: +1 while on screen, −1 when leaving (and when destroyed).
    property bool counted: false

    function syncScan() {
        if (shown && !counted) {
            counted = true;
            Network.scanUsers += 1;
        } else if (!shown && counted) {
            counted = false;
            Network.scanUsers = Math.max(0, Network.scanUsers - 1);
        }
    }

    onShownChanged: {
        syncScan();
        // Leaving the page with a password request open cancels it.
        if (!shown && Network.pendingKey !== "")
            Network.cancelPending();
    }
    Component.onCompleted: syncScan()
    Component.onDestruction: {
        if (counted) {
            counted = false;
            Network.scanUsers = Math.max(0, Network.scanUsers - 1);
        }
    }

    Column {
        id: column
        x: root.pad
        y: 10
        width: root.width - 2 * root.pad
        spacing: 8

        CcHeader {
            width: parent.width
            title: "Wi‑Fi"

            Glyph {
                id: scanGlyph
                anchors.verticalCenter: parent.verticalCenter
                kind: "refresh"
                size: 16
                color: Theme.dim
                visible: Network.scanning && Network.wifiEnabled

                RotationAnimation on rotation {
                    running: scanGlyph.visible && Animations.enabled
                    from: 0
                    to: 360
                    duration: 1100
                    loops: Animation.Infinite
                }
            }

            CcSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.wifiEnabled
                onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            }
        }

        // Current network (or wired).
        Label {
            width: parent.width
            leftPadding: 6
            text: Network.wired ? "Connected via Ethernet" : Network.connected ? `Connected to ${Network.name}` : Network.wifiEnabled ? "Not connected" : "Wi‑Fi is off"
            textFormat: Text.PlainText
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        // Last error (wrong password, connection failure…).
        Label {
            width: parent.width
            leftPadding: 6
            visible: (Network.lastError ?? "") !== ""
            text: Network.lastError ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            color: Theme.danger
            font.pixelSize: Appearance.fontSize - 1
        }

        Label {
            width: parent.width
            height: 44
            visible: Network.wifiEnabled && root.networks.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Network.scanning ? "Searching…" : "No networks found"
            color: Theme.faint
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, root.maxRows * root.rowHeight + (root.hasPending ? root.passwordHeight : 0))
            visible: Network.wifiEnabled && root.networks.length > 0
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel {
                values: root.networks
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
                required property int index
                readonly property var net: root.byKey[modelData.key] ?? modelData
                readonly property bool pending: root.hasPending && Network.pendingKey === net.key
                readonly property bool hovered: rowMouse.containsMouse || actionButton.hovered

                width: ListView.view.width
                height: root.rowHeight + (pending ? root.passwordHeight : 0)
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Animations.duration(200)
                        easing.type: Easing.OutCubic
                    }
                }

                onPendingChanged: {
                    if (pending) {
                        // The requested password: the field stays visible and focused.
                        Qt.callLater(() => {
                            list.positionViewAtIndex(row.index, ListView.Contain);
                            field.forceActiveFocus();
                        });
                    } else {
                        field.text = "";
                        if (field.activeFocus)
                            root.releaseFocus();
                    }
                }

                function submit() {
                    const pw = field.text;
                    field.text = "";
                    if (pw !== "")
                        Network.connectWithPassword(row.net.key, pw);
                }

                function cancel() {
                    field.text = "";
                    Network.cancelPending();
                    root.releaseFocus();
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 16
                    color: row.pending ? Theme.hover : rowMouse.pressed ? Theme.pressed : row.hovered ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Animations.duration(120)
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    width: parent.width
                    height: root.rowHeight
                    hoverEnabled: true
                    cursorShape: row.net.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!row.net.connected && !row.pending)
                            Network.connect(row.net.key);
                    }
                }

                WifiIcon {
                    id: sigIcon
                    x: 12
                    y: (root.rowHeight - height) / 2
                    size: 18
                    level: row.net.level ?? 0
                    connected: true
                    color: row.net.connected ? Theme.accent : Theme.icon
                }

                Column {
                    anchors.left: sigIcon.right
                    anchors.leftMargin: 12
                    anchors.right: actionButton.left
                    anchors.rightMargin: 8
                    y: (root.rowHeight - height) / 2
                    spacing: 0

                    Row {
                        width: parent.width
                        spacing: 6

                        Label {
                            id: nameLabel
                            width: Math.min(implicitWidth, parent.width - (lock.visible ? lock.width + 6 : 0))
                            text: row.net.name || "Hidden network"
                            textFormat: Text.PlainText
                            font.weight: row.net.connected ? Font.DemiBold : Font.Normal
                        }

                        Glyph {
                            id: lock
                            anchors.verticalCenter: nameLabel.verticalCenter
                            visible: row.net.secured === true
                            kind: "lock"
                            size: 12
                            color: Theme.dim
                        }
                    }

                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: row.net.connected ? "Connected" : row.net.connecting ? "Connecting…" : row.pending ? "Password required" : row.net.known ? "Saved" : ""
                        color: row.net.connected ? Theme.accent : Theme.dim
                        font.pixelSize: Appearance.fontSize - 2
                    }
                }

                // Connected: "Disconnect"; saved (with the pointer over it): "Forget".
                CcTextButton {
                    id: actionButton
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: (root.rowHeight - height) / 2
                    text: row.net.connected ? "Disconnect" : "Forget"
                    visible: row.net.connected || (row.net.known && row.hovered && !row.pending)
                    onClicked: {
                        if (row.net.connected)
                            Network.disconnect();
                        else
                            Network.forget(row.net.key);
                    }
                }

                // Password (only with the request open for this network).
                Item {
                    id: passwordRow
                    y: root.rowHeight
                    width: parent.width
                    height: root.passwordHeight
                    visible: row.pending

                    Rectangle {
                        id: fieldBox
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: connectButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 34
                        radius: height / 2
                        color: Theme.surface
                        border.width: 1
                        border.color: field.activeFocus ? Theme.accent : Theme.border

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Animations.duration(120)
                            }
                        }

                        // Clicking the box (outside the text) also focuses the field.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onPressed: field.forceActiveFocus()
                        }

                        TextInput {
                            id: field
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            echoMode: TextInput.Password
                            passwordMaskDelay: 0
                            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            selectByMouse: true
                            color: Theme.foreground
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.accentContent
                            font.family: Appearance.font
                            font.pixelSize: Appearance.fontSize
                            renderType: Text.NativeRendering

                            Keys.onReturnPressed: row.submit()
                            Keys.onEnterPressed: row.submit()
                            Keys.onEscapePressed: event => {
                                event.accepted = true;
                                row.cancel();
                            }

                            Label {
                                anchors.fill: parent
                                visible: field.text === ""
                                text: "Password"
                                color: Theme.faint
                            }
                        }
                    }

                    CcTextButton {
                        id: connectButton
                        anchors.right: cancelButton.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        primary: true
                        enabled: field.text !== ""
                        text: "Connect"
                        onClicked: row.submit()
                    }

                    IconButton {
                        id: cancelButton
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        size: 30
                        onClicked: row.cancel()

                        Glyph {
                            kind: "close"
                            size: 14
                            color: Theme.dim
                        }
                    }
                }
            }
        }
    }
}
