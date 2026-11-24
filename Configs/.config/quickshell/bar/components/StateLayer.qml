import QtQuick
import qs.bar.services

// Clickable area with the hover/press layer underneath the content. Emits the same signals for
// all three buttons and accumulates scrolling (touchpads send many small events) into steps of 120.
MouseArea {
    id: root

    property real radius: height / 2
    property color highlight: Theme.hover
    property bool active: false

    signal scrolled(int direction) // +1 up, -1 down

    property real _wheel: 0

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor

    onWheel: wheel => {
        _wheel += wheel.angleDelta.y;
        while (_wheel >= 120) {
            _wheel -= 120;
            scrolled(1);
        }
        while (_wheel <= -120) {
            _wheel += 120;
            scrolled(-1);
        }
    }

    Rectangle {
        anchors.fill: parent
        z: -1
        radius: root.radius
        // A widget that is switched on (caffeine, do not disturb, an open panel) reads as such, not as a hover.
        color: root.pressed ? Theme.pressed : root.active ? Theme.alpha(Theme.primary, 0.22) : root.highlight
        opacity: root.containsMouse || root.active ? 1 : 0

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
    }
}
