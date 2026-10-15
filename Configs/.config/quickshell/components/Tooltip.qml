import QtQuick
import Quickshell
import qs.services

// Tooltip anchored to an item (on the bar or in a panel); accepts Pango markup (which is what HyDE's
// scripts produce). Long texts wrap instead of running off the screen.
PopupWindow {
    id: tip

    required property Item target
    property string text
    // On the bar it opens towards the inside of the screen; in panels the caller picks the side.
    property bool below: BarLayout.atTop

    anchor.item: target
    anchor.rect.y: below ? 0 : -Theme.space2
    anchor.rect.width: target.width
    anchor.rect.height: target.height + Theme.space2
    anchor.edges: below ? Edges.Bottom : Edges.Top
    anchor.gravity: below ? Edges.Bottom : Edges.Top
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
    visible: true
    color: "transparent"
    implicitWidth: body.width + 2 * Theme.space3
    implicitHeight: body.implicitHeight + 2 * Theme.space2

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.shapeSmall
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.border
        opacity: 0
        scale: 0.94

        Component.onCompleted: {
            opacity = 1;
            scale = 1;
        }

        Behavior on opacity {
            NumberAnim {
                duration: Anim.fast
            }
        }
        Behavior on scale {
            NumberAnim {
                duration: Anim.fast
            }
        }

        // Natural width up to 360 px; beyond that, it wraps.
        StyledText {
            id: body
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 360)
            text: Utils.pango(tip.text)
            textFormat: Text.StyledText
            font.pixelSize: Theme.bodySmall
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
    }
}
