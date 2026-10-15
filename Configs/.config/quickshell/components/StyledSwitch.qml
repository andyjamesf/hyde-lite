import QtQuick
import qs.services

Item {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 44
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnim {}
        }
    }

    Rectangle {
        width: root.checked ? root.height - 6 : root.height - 10
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 5
        color: root.checked ? Theme.onPrimary : Theme.outline

        Behavior on x {
            NumberAnim {
                easing.bezierCurve: Anim.emphasized
            }
        }
        Behavior on width {
            NumberAnim {}
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
