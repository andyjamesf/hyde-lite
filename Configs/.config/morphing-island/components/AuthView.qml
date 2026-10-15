import QtQuick
import qs.config
import qs.core
import qs.services
import qs.theme

// Polkit authentication request in the island ("auth" mode): shield, title, the requested action's
// message and id, the user (a selector if there are several), PAM's prompt and the answer field,
// with "Cancel" and "Authenticate". The request's life cycle is in services/Polkit.qml.
// Keyboard: Enter authenticates · Esc cancels (the request is cancelled, never left pending).
// Failure: the field shakes, "Authentication failed" appears and, after PolkitConfig.failureNoticeMs,
// the request is cancelled and the island closes (see PolkitConfig.maxAttempts).
FocusScope {
    id: root

    // True while this is the current mode (the island passes it through ModeSlot).
    property bool open: false

    readonly property real islandRadius: 26
    readonly property int pad: 22
    readonly property int contentWidth: implicitWidth - 2 * pad

    readonly property var flow: Polkit.flow
    readonly property var identities: flow?.identities ?? []
    // Only accepts answers a moment after opening (PolkitConfig.armDelay): whatever was being typed in
    // another window (and an Enter) does not land in the field by mistake.
    property bool armed: false
    readonly property bool canSubmit: open && armed && Polkit.canRespond
    readonly property bool waiting: Polkit.active && !flow.isResponseRequired && !Polkit.closingAfterFailure
    readonly property bool errorShown: Polkit.failedNotice || ((flow?.supplementaryIsError ?? false) && (flow?.supplementaryMessage ?? "") !== "")

    focus: true
    implicitWidth: 460
    implicitHeight: body.y + body.implicitHeight + pad

    onOpenChanged: reset()
    Component.onCompleted: reset()
    Component.onDestruction: field.clear()

    // Every opening (and every closing) starts with an empty field.
    function reset() {
        field.clear();
        armed = false;
        if (!open)
            return;
        focusRetry.start();
        armTimer.restart();
    }

    // New request in the queue (the view stays open): empty field and wait again before accepting.
    onFlowChanged: reset()

    Keys.onEscapePressed: event => {
        event.accepted = true;
        field.clear();
        Polkit.cancel();
    }

    Connections {
        target: Polkit
        function onAttemptFailed() {
            field.clear();
            field.shake();
        }
    }

    // The window's keyboard focus (exclusive) only arrives a moment later: try again.
    FocusRetry {
        id: focusRetry
        target: field
        when: root.open
    }

    Timer {
        id: armTimer
        interval: PolkitConfig.armDelay
        onTriggered: root.armed = root.open
    }

    // Under everything: swallows clicks outside the controls and gives the focus back to the field.
    MouseArea {
        anchors.fill: parent
        onPressed: field.focusField()
    }

    // Header: shield + title + the action's message.
    Item {
        id: header
        x: root.pad
        y: 18
        width: root.contentWidth
        height: Math.max(shield.height, titles.implicitHeight)

        AuthShield {
            id: shield
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 2
            size: 34
            color: root.errorShown ? Theme.danger : Theme.accent
        }

        Column {
            id: titles
            anchors.left: shield.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            spacing: 3

            Label {
                width: parent.width
                text: "Authentication required"
                font.pixelSize: Appearance.fontSize + 3
                font.weight: Font.DemiBold
            }

            Label {
                width: parent.width
                visible: text !== ""
                text: root.flow?.message ?? ""
                color: Theme.dim
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                visible: text !== ""
                text: root.flow?.actionId ?? ""
                color: Theme.faint
                font.family: Appearance.monoFont
                font.pixelSize: Appearance.fontSize - 2
            }
        }
    }

    Column {
        id: body
        x: root.pad
        y: header.y + header.height + 16
        width: root.contentWidth
        spacing: 10

        // User: a selector when there is more than one identity, plain text if there is only one.
        Label {
            width: parent.width
            visible: root.identities.length === 1
            text: `Authenticating as ${root.identities[0]?.displayName ?? ""}`
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        Flow {
            width: parent.width
            visible: root.identities.length > 1
            spacing: 6

            Label {
                height: 28
                text: "User"
                color: Theme.dim
                font.pixelSize: Appearance.fontSize - 1
                rightPadding: 4
            }

            Repeater {
                model: root.identities.length > 1 ? root.identities : []

                CcTextButton {
                    required property var modelData
                    height: 28
                    text: modelData.displayName + (modelData.isGroup ? " (group)" : "")
                    primary: root.flow?.selectedIdentity === modelData
                    enabled: !Polkit.closingAfterFailure && !root.waiting
                    onClicked: {
                        if (root.flow && root.flow.selectedIdentity !== modelData) {
                            field.clear();
                            root.flow.selectedIdentity = modelData;
                        }
                        field.focusField();
                    }
                }
            }
        }

        // PAM's prompt (e.g. "Password:").
        Label {
            width: parent.width
            visible: text !== ""
            text: root.flow?.inputPrompt ?? ""
            color: Theme.dim
            font.pixelSize: Appearance.fontSize - 1
        }

        PasswordField {
            id: field
            width: parent.width
            // No text inside the field: the prompt ("Password:") already shows above.
            placeholder: ""
            responseVisible: root.flow?.responseVisible ?? false
            acceptsInput: root.canSubmit
            busy: root.waiting
            hasError: root.errorShown
            // The answer goes straight to the AuthFlow; the field is already empty.
            onSubmitted: secret => Polkit.submit(secret)
        }

        // Messages: failure (danger) or PAM's supplementary message (danger if it is an error).
        Label {
            width: parent.width
            visible: text !== ""
            // PAM's own explanation (e.g. "account locked") wins over the generic notice.
            text: PamText.friendly(root.flow?.supplementaryMessage ?? "") || (Polkit.failedNotice ? "Authentication failed" : "")
            color: root.errorShown ? Theme.danger : Theme.dim
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.pixelSize: Appearance.fontSize - 1
        }

        // Buttons on the right.
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
                    text: "Cancel"
                    enabled: !Polkit.closingAfterFailure
                    onClicked: {
                        field.clear();
                        Polkit.cancel();
                    }
                }

                CcTextButton {
                    height: 32
                    width: Math.max(120, implicitWidth)
                    text: "Authenticate"
                    primary: true
                    enabled: root.canSubmit && !field.empty
                    onClicked: {
                        field.submit();
                        field.focusField();
                    }
                }
            }
        }
    }
}
