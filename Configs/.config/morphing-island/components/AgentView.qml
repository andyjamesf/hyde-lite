import QtQuick
import qs.config
import qs.core
import qs.icons
import qs.services
import qs.theme

// Wi-Fi or Bluetooth request in the island ("agent" mode, services/Agents.qml):
//   wifi       a network needs its password (again, if the saved one was refused)
//   pin        type the device's PIN          passkey   type the 6-digit passkey it shows
//   confirm    check the code matches          authorize let an unpaired device connect
//   display    type this code on the device (a keyboard): goes away by itself when done
// Keyboard: Enter answers · Esc refuses.
FocusScope {
    id: root

    property bool open: false

    readonly property real islandRadius: 26
    readonly property int pad: 22
    readonly property int contentWidth: implicitWidth - 2 * pad

    readonly property var request: Agents.request
    readonly property string type: request?.type ?? ""
    readonly property string name: request?.name ?? ""
    readonly property bool wifi: type === "wifi"
    readonly property bool asksText: ["wifi", "pin", "passkey"].includes(type)
    readonly property bool showsCode: type === "confirm" || type === "display"
    property string problem: ""

    readonly property string title: {
        switch (type) {
        case "wifi":
            return request?.enterprise ? `Sign in to ${name}` : `Password for ${name}`;
        case "pin":
            return `PIN for ${name}`;
        case "passkey":
            return `Passkey for ${name}`;
        case "confirm":
            return `Pair with ${name}?`;
        case "authorize":
            return `Allow ${name}?`;
        case "display":
            return `Pair with ${name}`;
        }
        return "";
    }
    readonly property string message: {
        switch (type) {
        case "wifi":
            return request?.retry ? "The saved password was not accepted. Type it again." : "This Wi-Fi network needs a password.";
        case "pin":
            return "Type the PIN the device expects (often 0000 or 1234).";
        case "passkey":
            return "Type the 6-digit passkey the device shows.";
        case "confirm":
            return "Pair only if the device shows this same code.";
        case "authorize":
            return "This Bluetooth device wants to connect.";
        case "display":
            return `Type this code on ${name}, then press Enter on it.`;
        }
        return "";
    }
    readonly property string okText: ({
            wifi: "Connect",
            pin: "Pair",
            passkey: "Pair",
            confirm: "Pair",
            authorize: "Allow",
            display: "Hide"
        })[type] ?? "OK"

    focus: true
    implicitWidth: 420
    implicitHeight: body.y + body.implicitHeight + pad

    onOpenChanged: reset()
    onRequestChanged: reset()
    Component.onCompleted: reset()
    Component.onDestruction: field.clear()

    function reset() {
        field.clear();
        problem = "";
        if (open)
            focusRetry.start();
    }

    // Enter from the field (or the button): checks and sends.
    function submit(secret) {
        if (!asksText) {
            Agents.answer(true, "");
            return;
        }
        if (wifi && !request?.enterprise && secret.length < AgentsConfig.minWifiPassword) {
            problem = `The password needs at least ${AgentsConfig.minWifiPassword} characters`;
            field.shake();
            return;
        }
        if (type === "passkey" && !/^\d{1,6}$/.test(secret)) {
            problem = "The passkey is up to 6 digits";
            field.shake();
            return;
        }
        Agents.answer(true, secret);
    }

    Keys.onEscapePressed: event => {
        event.accepted = true;
        field.clear();
        Agents.cancel();
    }
    Keys.onReturnPressed: if (!asksText)
        submit("")
    Keys.onEnterPressed: if (!asksText)
        submit("")

    FocusRetry {
        id: focusRetry
        target: root.asksText ? field : root
        when: root.open
    }

    MouseArea {
        anchors.fill: parent
        onPressed: root.asksText ? field.focusField() : root.forceActiveFocus()
    }

    // Header: Wi-Fi or Bluetooth symbol, title and what is asked.
    Item {
        id: header
        x: root.pad
        y: 18
        width: root.contentWidth
        height: Math.max(34, titles.implicitHeight)

        Item {
            id: symbol
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 2
            width: 34
            height: 34

            WifiIcon {
                anchors.centerIn: parent
                visible: root.wifi
                size: 28
                color: root.problem !== "" ? Theme.danger : Theme.accent
            }
            BluetoothIcon {
                anchors.centerIn: parent
                visible: !root.wifi
                size: 28
                color: root.problem !== "" ? Theme.danger : Theme.accent
            }
        }

        Column {
            id: titles
            anchors.left: symbol.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            spacing: 3

            Label {
                width: parent.width
                text: root.title
                font.pixelSize: Appearance.fontSize + 3
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                width: parent.width
                text: root.message
                color: Theme.dim
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }

    Column {
        id: body
        x: root.pad
        y: header.y + header.height + 16
        width: root.contentWidth
        spacing: 10

        // The code to compare or to type on the device.
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.showsCode
            text: (root.request?.code ?? "").replace(/^(\d{3})(\d{3})$/, "$1 $2")
            font.pixelSize: 34
            font.weight: Font.Light
            font.letterSpacing: 3
        }
        // Digits already typed on the keyboard being paired.
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.type === "display" && (root.request?.entered ?? 0) > 0
            text: "●".repeat(root.request?.entered ?? 0) + "○".repeat(Math.max(0, (root.request?.code ?? "").length - (root.request?.entered ?? 0)))
            color: Theme.accent
        }

        PasswordField {
            id: field
            width: parent.width
            visible: root.asksText
            placeholder: root.wifi ? "Password" : root.type === "pin" ? "PIN" : "Passkey"
            responseVisible: !root.wifi
            acceptsInput: root.open && root.asksText
            hasError: root.problem !== ""
            onSubmitted: secret => root.submit(secret)
            onEdited: root.problem = ""
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.problem
            color: Theme.danger
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.fontSize - 1
        }

        Item {
            width: parent.width
            height: 32

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                CcTextButton {
                    height: 32
                    width: Math.max(88, implicitWidth)
                    visible: root.type !== "display"
                    text: "Cancel"
                    onClicked: {
                        field.clear();
                        Agents.cancel();
                    }
                }
                CcTextButton {
                    height: 32
                    width: Math.max(110, implicitWidth)
                    text: root.okText
                    primary: true
                    enabled: !root.asksText || !field.empty
                    onClicked: root.asksText ? field.submit() : root.submit("")
                }
            }
        }
    }
}
