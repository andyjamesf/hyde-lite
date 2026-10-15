import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Panel that opens below (or above) a bar widget, with its contents in `content`.
// Enters with a short slide and a fade. Closes on an outside click or Esc: it uses Hyprland's
// focus grab (not the xdg_popup one, which only works if the popup was opened by a click — it fails when
// the popout is opened over IPC). The bar is part of the grab, so clicks on it keep
// working (switching popouts, closing on the same widget).
PopupWindow {
    id: popout

    required property Item target
    property Component content
    property var barWindow: null
    readonly property bool below: BarLayout.atTop

    signal dismissed

    anchor.item: target
    anchor.rect.y: below ? 0 : -10
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 10
    anchor.edges: below ? Edges.Bottom : Edges.Top
    anchor.gravity: below ? Edges.Bottom : Edges.Top
    anchor.adjustment: PopupAdjustment.Slide
    visible: true
    color: "transparent"
    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight + 10

    onVisibleChanged: if (!visible)
        dismissed()

    function close() {
        visible = false;
    }

    // The grab only starts once the popout is on screen: when switching popouts, the previous one's grab is still
    // going away and Hyprland would cancel the new one at once (the popout opened and closed in the same instant).
    property bool grabReady: false

    Timer {
        running: popout.visible && !popout.grabReady
        interval: 60
        onTriggered: popout.grabReady = true
    }

    HyprlandFocusGrab {
        windows: popout.barWindow ? [popout, popout.barWindow] : [popout]
        active: popout.visible && popout.grabReady
        onCleared: popout.close()
    }

    Rectangle {
        id: bg

        implicitWidth: loader.implicitWidth + 2 * Theme.space5
        implicitHeight: loader.implicitHeight + 2 * Theme.space5
        width: parent.width
        height: implicitHeight
        y: popout.below ? 0 : 10
        radius: Theme.shapeLarge + 4
        color: Theme.alpha(Theme.surfaceContainer, 0.97)
        border.width: 1
        border.color: Theme.border
        focus: true
        Keys.onEscapePressed: popout.close()

        opacity: 0
        transform: Translate {
            id: slide
            y: popout.below ? -8 : 8
        }

        Component.onCompleted: opacity = 1

        Behavior on opacity {
            NumberAnim {
                duration: Anim.normal
            }
        }

        Loader {
            id: loader
            anchors.centerIn: parent
            sourceComponent: popout.content
        }
    }

    // Translate is not an Item (it does not accept a Behavior), so the slide is a separate animation.
    NumberAnimation {
        running: true
        target: slide
        property: "y"
        to: 0
        duration: Anim.normal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Anim.emphasized
    }
}
