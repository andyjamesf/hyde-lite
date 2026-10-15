import QtQuick
import qs.services

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
        color: root.pressed ? Theme.pressed : root.highlight
        opacity: root.containsMouse || root.active ? 1 : 0

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
    }
}
