import QtQuick
import QtQuick.Shapes

// The island's password pill (components/PasswordField.qml): dots instead of letters, a spinner
// with "Checking…" while logging in, and a shake with a danger-coloured border on failure. Enter
// emits submitted(secret) with the field already emptied; nothing keeps a copy.
FocusScope {
    id: root

    required property var theme
    property string placeholder: "Password"
    property bool busy: false
    property bool hasError: false

    signal submitted(string secret)
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
    function submit() {
        if (busy || input.text === "")
            return;
        const secret = input.text;
        input.clear();
        submitted(secret);
    }

    implicitWidth: 300
    implicitHeight: 46

    Rectangle {
        id: pill
        width: parent.width
        height: parent.height
        radius: height / 2
        color: root.theme.surface
        border.width: root.hasError || input.activeFocus ? 1.5 : 1
        border.color: root.hasError ? root.theme.danger : input.activeFocus ? root.theme.accent : root.theme.border

        Behavior on border.color {
            ColorAnimation {
                duration: 150
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
                duration: 45
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: shakeX
                property: "x"
                to: -12
                duration: 90
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: shakeX
                property: "x"
                to: 0
                duration: 45
                easing.type: Easing.InQuad
            }
        }

        // Spinner while logging in.
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
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Shape {
                anchors.centerIn: parent
                width: 16
                height: 16
                preferredRendererType: Shape.CurveRenderer

                RotationAnimator on rotation {
                    running: spinner.visible
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }

                ShapePath {
                    strokeColor: root.theme.accent
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
            // Anchored to the pill, not to the spinner: the spinner's own left margin would count even when
            // it is hidden (width 0) and push the dots 8 px right of the centre.
            anchors.left: parent.left
            anchors.leftMargin: root.busy ? spinner.anchors.leftMargin + spinner.width + 10 : 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            focus: true
            readOnly: root.busy
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            selectByMouse: false
            color: root.theme.foreground
            selectionColor: root.theme.accent
            selectedTextColor: root.theme.accentContent
            font.family: root.theme.font
            font.pixelSize: root.theme.fontSize + 1
            font.letterSpacing: 2
            horizontalAlignment: TextInput.AlignHCenter

            onTextChanged: if (text !== "")
                root.edited()
            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
            Keys.onEscapePressed: input.clear()

            Text {
                anchors.fill: parent
                visible: input.text === ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.busy ? "Checking…" : root.placeholder
                color: root.theme.faint
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize + 1
            }
        }
    }
}
