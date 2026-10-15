import QtQuick
import qs.services

// Control center quick toggle: round button with the icon and the name underneath. Click
// toggles on/off; if `expandable`, right click (or press and hold) opens the detail page and
// a small badge with an arrow shows there are more options.
Item {
    id: root

    property string icon
    property string label
    property string subtitle
    property bool checked: false
    property bool expandable: false
    property int size: 56

    signal toggled
    signal expand

    implicitWidth: size + Theme.space2
    implicitHeight: size + Theme.space2 + caption.implicitHeight

    Rectangle {
        id: circle

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size
        height: root.size
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        scale: area.pressed ? 0.92 : 1

        Behavior on color {
            ColorAnim {}
        }
        Behavior on scale {
            NumberAnim {
                duration: Anim.fast
            }
        }

        StateLayer {
            id: area
            anchors.fill: parent
            highlight: Theme.alpha(root.checked ? Theme.onPrimary : Theme.text, 0.08)
            pressAndHoldInterval: 400
            property bool held: false
            onPressed: held = false
            onPressAndHold: {
                if (root.expandable) {
                    held = true;
                    root.expand();
                }
            }
            onClicked: mouse => {
                if (held)
                    return;
                if (mouse.button === Qt.RightButton && root.expandable)
                    root.expand();
                else if (mouse.button === Qt.LeftButton)
                    root.toggled();
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            icon: root.icon
            size: Math.round(root.size * 0.43)
            fill: root.checked ? 1 : 0
            color: root.checked ? Theme.onPrimary : Theme.text
        }

        // "More" badge: opens the detail page with a normal click.
        Rectangle {
            visible: root.expandable
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2
            anchors.bottomMargin: -2
            width: 20
            height: 20
            radius: height / 2
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.border

            MaterialIcon {
                anchors.centerIn: parent
                icon: "chevron_right"
                size: 14
                weight: 600
                color: Theme.textDim
            }

            StateLayer {
                anchors.fill: parent
                onClicked: root.expand()
            }
        }
    }

    StyledText {
        id: caption
        anchors.top: circle.bottom
        anchors.topMargin: Theme.space2
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.pixelSize: Theme.labelMedium
        font.weight: Font.Medium
        color: root.checked ? Theme.text : Theme.textDim
    }
}
