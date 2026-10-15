import QtQuick
import qs.config
import qs.theme

// OSD progress bar: a rounded track + a fill whose width animates smoothly.
// When muted, the fill turns grey and the whole bar drops to 40%.
Item {
    id: root

    // 0..1 (values outside the range are clamped).
    property real value: 0
    property bool muted: false
    property real thickness: 6

    implicitWidth: 160
    implicitHeight: thickness
    opacity: muted ? 0.4 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(150)
        }
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Theme.faint, 0.35)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // Never narrower than its height, so the ends stay round (0 = empty).
            width: {
                const v = Math.max(0, Math.min(1, root.value));
                return v <= 0 ? 0 : Math.max(height, parent.width * v);
            }
            radius: height / 2
            color: root.muted ? Theme.dim : Theme.accent

            Behavior on width {
                NumberAnimation {
                    duration: Animations.duration(180)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(150)
                }
            }
        }
    }
}
