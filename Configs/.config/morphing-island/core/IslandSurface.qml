import QtQuick
import QtQuick.Effects
import qs.config
import qs.theme

// The island's look, shared by the desktop island (core/Island.qml) and the lock screen
// (core/LockSurface.qml): background, border, soft shadow (none on e-ink) and rounded corners.
// Width, height and radius follow their targets through critically damped springs, so the shape
// morphs continuously. Children go inside a clipping item that fills the surface.
Item {
    id: surface

    // Size the surface is heading to, in pixels (the springs follow).
    property real targetWidth: Pill.minWidth
    property real targetHeight: Pill.height
    // Largest corner radius: a low surface is a full pill (radius = height / 2); a tall one keeps
    // generous corners but not circular ones.
    property real maxRadius: 26
    readonly property real targetRadius: Math.min(targetHeight / 2, maxRadius)
    readonly property real radius: r.value

    default property alias surfaceData: clipper.data

    width: Math.round(w.value)
    height: Math.round(h.value)

    Spring {
        id: w
        target: surface.targetWidth
    }
    Spring {
        id: h
        target: surface.targetHeight
    }
    Spring {
        id: r
        target: surface.targetRadius
    }

    Rectangle {
        anchors.fill: parent
        radius: r.value
        color: Qt.alpha(Theme.background, Theme.islandOpacity)
        border.width: 1
        border.color: Theme.border
        layer.enabled: !Theme.eink
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: ThemeConfig.shadowBlur
            shadowVerticalOffset: ThemeConfig.shadowOffsetY
        }
    }

    Item {
        id: clipper
        anchors.fill: parent
        clip: true
    }
}
