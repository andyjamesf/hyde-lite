import QtQuick
import qs.config
import qs.theme

// Large rounded slider (volume, brightness): a track filled with Theme.accent and the icon inside,
// on the left. Dragging, clicking the track or using the wheel emits moved(v) with v in 0..1.
// While dragging it shows the hand's value (does not wait for the service); otherwise it follows
// `value` with an animation. `throttle` (ms) limits how often moved() fires while dragging (the
// last value is always sent).
Item {
    id: root

    property real value: 0
    property bool muted: false
    property real thickness: 32
    // Optional text on the right, inside the track (e.g. "72%").
    property string label: ""
    // The icon is also a button (e.g. mute).
    property bool iconClickable: false
    property int throttle: 0
    property real wheelStep: 0.05

    // Icon (default child), centred in the left square.
    default property alias icon: iconHolder.data

    readonly property bool dragging: drag.pressed
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))
    // Colour the icon should use (over the fill).
    readonly property color iconColor: muted ? Theme.foreground : Theme.accentContent

    property real dragValue: 0
    property real _pending: -1

    signal moved(real v)
    signal iconClicked

    implicitWidth: 240
    implicitHeight: thickness

    function valueAt(x) {
        const span = width - height;
        return span <= 0 ? 0 : Math.max(0, Math.min(1, (x - height / 2) / span));
    }

    function send(v) {
        if (throttle <= 0) {
            moved(v);
            return;
        }
        _pending = v;
        if (!throttleTimer.running) {
            moved(v);
            _pending = -1;
            throttleTimer.start();
        }
    }

    function flush() {
        if (_pending >= 0) {
            moved(_pending);
            _pending = -1;
        }
    }

    Timer {
        id: throttleTimer
        interval: Math.max(1, root.throttle)
        onTriggered: root.flush()
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.hover
        border.width: 1
        border.color: Theme.border

        // Fill: never narrower than the icon square (the icon always sits on it).
        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.height + (parent.width - root.height) * root.shown
            radius: height / 2
            color: root.muted ? Theme.pressed : Theme.accent

            Behavior on width {
                enabled: !root.dragging
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

        // Subtle handle at the end of the fill.
        Rectangle {
            x: fill.width - width - (root.height - height) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(root.height * 0.18)
            height: Math.round(root.height * 0.5)
            radius: width / 2
            visible: root.shown > 0.02
            color: root.muted ? Theme.dim : Theme.accentContent
            opacity: drag.containsMouse || root.dragging ? 0.9 : 0.5

            Behavior on opacity {
                NumberAnimation {
                    duration: Animations.duration(120)
                }
            }
        }
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.height * 0.45)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.label !== ""
        text: root.label
        color: fill.width > root.width - width - root.height * 0.6 ? root.iconColor : Theme.dim
        font.pixelSize: Appearance.fontSize - 1
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            // With a clickable icon, the left square is a button (does not change the value).
            if (root.iconClickable && mouse.x < root.height) {
                mouse.accepted = false;
                return;
            }
            root.dragValue = root.valueAt(mouse.x);
            root.send(root.dragValue);
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.dragValue = root.valueAt(mouse.x);
            root.send(root.dragValue);
        }
        onReleased: {
            throttleTimer.stop();
            root.flush();
        }
        onWheel: wheel => {
            const steps = wheel.angleDelta.y / 120;
            if (steps === 0)
                return;
            root.moved(Math.max(0, Math.min(1, root.value + steps * root.wheelStep)));
        }
    }

    // Icon square (above the drag MouseArea, so clicks on the icon belong to it).
    Item {
        id: iconBox
        width: root.height
        height: root.height

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: width / 2
            color: iconMouse.pressed ? Qt.alpha(root.iconColor, 0.22) : iconMouse.containsMouse ? Qt.alpha(root.iconColor, 0.14) : "transparent"
            visible: root.iconClickable

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(120)
                }
            }
        }

        Item {
            id: iconHolder
            anchors.centerIn: parent
            width: childrenRect.width
            height: childrenRect.height
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            enabled: root.iconClickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }
}
