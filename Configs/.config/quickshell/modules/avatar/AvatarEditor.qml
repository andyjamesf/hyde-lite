import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// User picture editor: the chosen image appears in a frame with the circle the
// shell displays; drag to position it and zoom (mouse wheel or slider). "Save" writes
// the square crop (512 px) to ~/.face.
PanelWindow {
    id: win

    required property ShellScreen modelData
    readonly property string source: ShellState.avatarSource
    // Size of the editing frame (logical px).
    readonly property int frame: 280

    // Zoom 1 = the image exactly covers the frame; offset in px from the center.
    property real zoom: 1
    property real ox: 0
    property real oy: 0
    readonly property real base: img.implicitWidth > 0 ? Math.max(frame / img.implicitWidth, frame / img.implicitHeight) : 1
    readonly property real shownW: img.implicitWidth * base * zoom
    readonly property real shownH: img.implicitHeight * base * zoom

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: Qt.rgba(0, 0, 0, 0.45)

    WlrLayershell.namespace: "quickshell:avatar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function clampOffsets() {
        const mx = Math.max(0, (shownW - frame) / 2), my = Math.max(0, (shownH - frame) / 2);
        ox = Math.max(-mx, Math.min(mx, ox));
        oy = Math.max(-my, Math.min(my, oy));
    }

    // Zoom around the center of the frame: the point at the center stays at the center.
    function setZoom(z) {
        const nz = Math.max(1, Math.min(4, z));
        ox = ox * nz / zoom;
        oy = oy * nz / zoom;
        zoom = nz;
        clampOffsets();
    }

    function save() {
        const tmp = `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/quickshell-face.png`;
        crop.grabToImage(result => {
            if (result.saveToFile(tmp))
                Quickshell.execDetached(["cp", "-f", "--", tmp, `${Quickshell.env("HOME")}/.face`]);
            ShellState.avatarSource = "";
        }, Qt.size(512, 512));
    }

    // A click outside the card cancels.
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.avatarSource = ""
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: content.implicitWidth + 2 * Theme.space6
        height: content.implicitHeight + 2 * Theme.space6
        radius: Theme.shapeXL
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.border
        focus: true
        Keys.onEscapePressed: ShellState.avatarSource = ""
        Keys.onReturnPressed: win.save()

        // Swallows clicks on the card (they don't close the editor).
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: content
            anchors.centerIn: parent
            spacing: Theme.space4

            StyledText {
                text: "Position your photo"
                font.pixelSize: Theme.titleMedium
                font.weight: Font.DemiBold
            }

            StyledText {
                text: "Drag to move · scroll or use the slider to zoom"
                font.pixelSize: Theme.bodySmall
                color: Theme.textDim
            }

            // Editing frame: the clipped image (this is what gets saved) and, on top, the circular
            // mask showing what will appear in the shell.
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: win.frame
                implicitHeight: win.frame

                Item {
                    id: crop
                    anchors.fill: parent
                    clip: true

                    Image {
                        id: img
                        source: win.source !== "" ? `file://${win.source}` : ""
                        asynchronous: true
                        cache: false
                        smooth: true
                        mipmap: true
                        width: win.shownW
                        height: win.shownH
                        x: (win.frame - width) / 2 + win.ox
                        y: (win.frame - height) / 2 + win.oy
                        onStatusChanged: if (status === Image.Ready) {
                            win.zoom = 1;
                            win.ox = 0;
                            win.oy = 0;
                        }
                    }
                }

                Canvas {
                    id: mask
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.55);
                        ctx.beginPath();
                        ctx.rect(0, 0, width, height);
                        ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 2, true);
                        ctx.fill("evenodd");
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.8);
                        ctx.lineWidth = 2;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, width / 2 - 1, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point last
                    onPressed: mouse => last = Qt.point(mouse.x, mouse.y)
                    onPositionChanged: mouse => {
                        win.ox += mouse.x - last.x;
                        win.oy += mouse.y - last.y;
                        last = Qt.point(mouse.x, mouse.y);
                        win.clampOffsets();
                    }
                    onWheel: wheel => win.setZoom(win.zoom * (wheel.angleDelta.y > 0 ? 1.08 : 1 / 1.08))
                }
            }

            StyledSlider {
                Layout.fillWidth: true
                icon: "zoom_in"
                showValue: false
                value: (win.zoom - 1) / 3
                onMoved: v => win.setZoom(1 + v * 3)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                PillButton {
                    text: "Choose another"
                    onClicked: SysInfo.chooseAvatar()
                }

                Item {
                    Layout.fillWidth: true
                }

                PillButton {
                    text: "Cancel"
                    onClicked: ShellState.avatarSource = ""
                }

                PillButton {
                    text: "Save"
                    primary: true
                    onClicked: win.save()
                }
            }
        }
    }

    component PillButton: Rectangle {
        id: btn

        property string text
        property bool primary: false

        signal clicked

        implicitWidth: label.implicitWidth + 2 * Theme.space4
        implicitHeight: 36
        radius: height / 2
        color: primary ? Theme.primary : Theme.surfaceContainerHighest

        StateLayer {
            anchors.fill: parent
            highlight: Theme.alpha(btn.primary ? Theme.onPrimary : Theme.text, 0.08)
            onClicked: btn.clicked()
        }

        StyledText {
            id: label
            anchors.centerIn: parent
            text: btn.text
            font.pixelSize: Theme.labelLarge
            font.weight: Font.Medium
            color: btn.primary ? Theme.onPrimary : Theme.text
        }
    }
}
