import QtQuick
import Quickshell.Widgets
import qs.shared.icons
import qs.shared.services

// Header of the control centre's main page: picture (click: choose another), name and time since
// boot on the left; battery (click: battery page), system, settings, lock and power on the right.
// Shared by the compact page (CcMainView) and the wide one (CcWideView).
Item {
    id: root

    // A detail page: "battery".
    signal pageRequested(string page)
    // A header button: "avatar", "system", "settings", "lock", "power".
    signal headerAction(string id)
    signal menuRequested(string id, Item item)
    signal hintRequested(bool on, string id, Item item)

    height: 40

    Rectangle {
        id: avatarFrame

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: width / 2
        color: CcTheme.surface
        border.width: 1
        border.color: avatarMouse.containsMouse ? CcTheme.accent : CcTheme.border

        CcLabel {
            anchors.centerIn: parent
            visible: avatarImage.status !== Image.Ready
            text: SysInfo.user.charAt(0).toUpperCase()
            color: CcTheme.accent
            font.weight: Font.DemiBold
        }

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: width / 2
            color: "transparent"
            visible: avatarImage.status === Image.Ready

            Image {
                id: avatarImage

                anchors.fill: parent
                source: SysInfo.avatarUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 80
                sourceSize.height: 80
                asynchronous: true
                cache: false
            }

        }

        MouseArea {
            id: avatarMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.headerAction("avatar")
            onContainsMouseChanged: root.hintRequested(containsMouse, "avatar", avatarFrame)
        }

    }

    Column {
        anchors.left: avatarFrame.right
        anchors.leftMargin: 10
        anchors.right: headerButtons.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        CcLabel {
            text: SysInfo.user
            font.weight: Font.DemiBold
        }

        CcLabel {
            text: `Up for ${SysInfo.uptime}`
            color: CcTheme.dim
            font.pixelSize: CcTheme.fontSize - 2
        }

    }

    Row {
        id: headerButtons

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Battery: percentage and icon; opens the battery page (power profiles).
        Rectangle {
            id: batteryButton

            anchors.verticalCenter: parent.verticalCenter
            visible: Battery.available
            width: batteryIcon.implicitWidth + 16
            height: 32
            radius: height / 2
            color: batteryMouse.pressed ? CcTheme.pressed : batteryMouse.containsMouse ? CcTheme.hover : "transparent"

            Row {
                id: batteryRow

                anchors.centerIn: parent
                spacing: 0

                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    id: batteryIcon
                    size: 20
                    showPercent: false
                    present: Battery.available
                    percent: Battery.percent
                    charging: Battery.charging
                }

            }

            MouseArea {
                id: batteryMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (event) => {
                    return event.button === Qt.RightButton ? root.menuRequested("battery", batteryButton) : root.pageRequested("battery");
                }
                onContainsMouseChanged: root.hintRequested(containsMouse, "batterypage", batteryButton)
            }

        }

        Repeater {
            model: [{
                "id": "system",
                "glyph": "\u{F061A}"
            }, {
                "id": "settings",
                "glyph": "\u{F0493}"
            }, {
                "id": "lock",
                "glyph": "\u{F033E}"
            }, {
                "id": "power",
                "glyph": "\u{F0425}"
            }]

            CcIconButton {
                id: headerButton

                required property var modelData

                anchors.verticalCenter: parent.verticalCenter
                size: 32
                onClicked: root.headerAction(modelData.id)
                rightClickable: true
                onRightClicked: root.menuRequested(modelData.id, headerButton)
                onHoveredChanged: root.hintRequested(hovered, modelData.id, headerButton)

                CcLabel {
                    text: headerButton.modelData.glyph
                    font.family: CcTheme.nerdFont
                    font.pixelSize: 17
                    elide: Text.ElideNone
                    color: CcTheme.icon
                }

            }

        }

    }

}
