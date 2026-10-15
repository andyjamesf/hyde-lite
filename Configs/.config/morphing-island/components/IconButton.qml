import QtQuick
import qs.config
import qs.theme

// Round button that holds an icon (default child, centred automatically).
// The MouseArea always accepts the click, even when disabled, so a click never reaches the
// island's "empty space" MouseArea (which toggles the pin).
Item {
    id: root

    // Icon (or other content) inside the button.
    default property alias content: holder.data
    readonly property alias contentItem: holder
    property real size: Pill.height - 12
    // Overrides Item's `enabled`: the Item stays enabled (to swallow clicks), only the button stops
    // reacting and fades.
    override property bool enabled: true
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    signal clicked
    // Right click (e.g. a menu); only when something listens (rightClickable).
    signal rightClicked
    property bool rightClickable: false

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        scale: root.enabled && root.pressed ? 0.92 : 1
        color: !root.enabled ? "transparent" : root.pressed ? Theme.pressed : root.hovered ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Animations.duration(120)
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Animations.duration(140)
                easing.type: Easing.OutCubic
            }
        }

        // Centres the content by its rectangle (icons need no anchors).
        Item {
            id: holder
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
            opacity: root.enabled ? 1 : 0.35

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(150)
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: root.rightClickable ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: mouseEvent => {
            mouseEvent.accepted = true;
            if (!root.enabled)
                return;
            if (mouseEvent.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
