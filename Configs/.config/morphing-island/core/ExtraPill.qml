import QtQuick
import qs.config
import qs.components

// One of the extra pills (config/PillsConfig.qml): a slot that shows its pill when `spec` is set and the
// island is the plain clock, and is absorbed into the island otherwise (it slides under it and fades, like the
// workspace and status pills). `spec` is { side, widgets }, or null for an unused slot.
IslandSurface {
    id: pill

    property var spec: null
    // The island shows only its clock pill (not expanded, no surface, not hidden).
    property bool allowed: false
    // Where the pill sits when shown, and where it hides (the island's centre minus half the width).
    property real shownX: 0
    property real absorbedX: 0
    readonly property bool active: spec !== null && allowed
    readonly property var ids: spec ? spec.widgets : []

    // Under the island, so it disappears behind it when absorbed.
    z: -1
    x: Math.round(slide.value)
    targetWidth: content.implicitWidth + 2 * PillsConfig.padding
    targetHeight: Pill.height
    opacity: active ? 1 : 0
    visible: opacity > 0.01

    Spring {
        id: slide
        target: pill.active ? pill.shownX : pill.absorbedX
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Animations.duration(pill.active ? Animations.fadeIn : Animations.fadeOut)
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: PillsConfig.innerSpacing

        WorkspacesView {
            anchors.verticalCenter: parent.verticalCenter
            visible: pill.ids.includes("workspaces")
        }
        StatusZone {
            anchors.verticalCenter: parent.verticalCenter
            icons: pill.ids.filter(i => i !== "workspaces")
            batteryPercent: StatusPillConfig.batteryPercent
            batteryTime: StatusPillConfig.batteryTime
            alwaysShowBell: StatusPillConfig.alwaysShowBell
            visible: icons.length > 0
        }
    }
}
