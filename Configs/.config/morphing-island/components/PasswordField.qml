import QtQuick
import QtQuick.Shapes
import qs.config
import qs.theme

// Password pill shared by the lock screen (LockCard) and the polkit dialog (AuthView): dots
// instead of letters, a spinner with "Checking…" while PAM verifies, and a horizontal shake plus
// a danger-coloured border on failure.
//
// Security: the secret only lives in this TextInput. Enter emits submitted(secret) and the field is
// cleared right away; the receiver passes it straight to PAM (Lock.submit / Polkit.submit) without
// storing it. Nothing here logs or keeps a copy.
FocusScope {
    id: root

    // Hint shown while empty (e.g. PAM's prompt "Password:"); "" = none.
    property string placeholder: ""
    // Show the answer in clear (PAM asked for something that is not secret).
    property bool responseVisible: false
    // Accepting answers (PAM is waiting and the view is ready). When it turns false, the field is
    // emptied.
    property bool acceptsInput: true
    // Verifying (spinner + "Checking…").
    property bool busy: false
    // Danger-coloured border.
    property bool hasError: false
    // Text alignment inside the pill.
    property int horizontalAlignment: TextInput.AlignLeft
    // Space between the pill's edges and the text, in pixels.
    property int sidePadding: 18
    // Esc clears the typed text (and is not passed on).
    property bool escapeClears: false

    readonly property bool empty: input.text === ""

    // The typed secret, sent once; the field is already empty when this fires.
    signal submitted(string secret)
    // The user typed something (e.g. to clear a previous error).
    signal edited

    function focusField() {
        input.forceActiveFocus();
    }

    function clear() {
        input.clear();
    }

    function shake() {
        shakeAnim.restart();
    }

    // Sends what is typed and clears the field. No copy is kept anywhere.
    function submit() {
        if (!acceptsInput || input.text === "")
            return;
        const secret = input.text;
        input.clear();
        submitted(secret);
    }

    implicitWidth: 320
    implicitHeight: 42

    // Stopped accepting answers (request finished, final failure): nothing stays typed.
    onAcceptsInputChanged: if (!acceptsInput)
        input.clear()

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.surface
        border.width: root.hasError || input.activeFocus ? (Theme.eink ? 2 : 1.5) : 1
        border.color: root.hasError ? Theme.danger : input.activeFocus ? Theme.accent : Theme.border

        Behavior on border.color {
            ColorAnimation {
                duration: Animations.duration(150)
            }
        }

        transform: Translate {
            id: shakeX
        }

        SequentialAnimation {
            id: shakeAnim
            loops: 2
            NumberAnimation {
                target: shakeX
                property: "x"
                to: 12
                duration: Animations.duration(45)
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeX
                property: "x"
                to: -12
                duration: Animations.duration(90)
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeX
                property: "x"
                to: 0
                duration: Animations.duration(45)
                easing.type: Easing.InQuad
            }
        }

        // Subtle spinner while PAM verifies.
        Item {
            id: spinner
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: root.busy ? 16 : 0
            height: 16
            opacity: root.busy ? 1 : 0
            visible: opacity > 0.01

            Behavior on width {
                NumberAnimation {
                    duration: Animations.duration(180)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(150)
                }
            }

            Shape {
                anchors.centerIn: parent
                width: 16
                height: 16
                preferredRendererType: Shape.CurveRenderer

                RotationAnimator on rotation {
                    running: spinner.visible && Animations.enabled
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }

                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 8
                        centerY: 8
                        radiusX: 6.5
                        radiusY: 6.5
                        startAngle: -90
                        sweepAngle: 270
                    }
                }
            }
        }

        TextInput {
            id: input
            anchors.left: spinner.right
            anchors.leftMargin: root.busy ? 10 : root.sidePadding
            anchors.right: parent.right
            anchors.rightMargin: root.sidePadding
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            focus: true
            readOnly: !root.acceptsInput
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            selectByMouse: false
            persistentSelection: false
            color: Theme.foreground
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentContent
            font.family: Appearance.font
            font.pixelSize: Appearance.fontSize + 1
            font.letterSpacing: root.responseVisible ? 0 : 2
            horizontalAlignment: root.horizontalAlignment
            renderType: Text.NativeRendering

            onTextChanged: {
                if (text !== "")
                    root.edited();
            }
            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
            Keys.onEscapePressed: event => {
                if (!root.escapeClears) {
                    event.accepted = false;
                    return;
                }
                event.accepted = true;
                input.clear();
            }

            // Placeholder, or "Checking…" while PAM verifies.
            Label {
                anchors.fill: parent
                visible: input.text === "" && (root.busy || root.placeholder !== "")
                horizontalAlignment: root.horizontalAlignment
                text: root.busy ? "Checking…" : root.placeholder
                color: Theme.faint
                font.pixelSize: Appearance.fontSize + 1
            }
        }
    }
}
