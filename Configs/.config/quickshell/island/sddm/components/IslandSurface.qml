import QtQuick
import QtQuick.Effects

// The island's look (core/IslandSurface.qml): background, border, soft shadow and rounded corners,
// with width, height and radius following their targets through springs. Children are clipped.
Item {
    id: surface

    required property var theme
    property real targetWidth: 128
    property real targetHeight: 36
    property real maxRadius: 30
    readonly property real targetRadius: Math.min(targetHeight / 2, maxRadius)

    default property alias surfaceData: clipper.data

    width: Math.round(w.value)
    height: Math.round(h.value)

    Spring {
        id: w
        target: surface.targetWidth
        omega: surface.theme.springOmega
    }
    Spring {
        id: h
        target: surface.targetHeight
        omega: surface.theme.springOmega
    }
    Spring {
        id: r
        target: surface.targetRadius
        omega: surface.theme.springOmega
    }

    Rectangle {
        anchors.fill: parent
        radius: r.value
        color: Qt.alpha(surface.theme.background, surface.theme.islandOpacity)
        border.width: 1
        border.color: surface.theme.border
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: surface.theme.shadow
            shadowBlur: 0.7
            shadowVerticalOffset: 3
        }
    }

    Item {
        id: clipper
        anchors.fill: parent
        clip: true
    }
}
