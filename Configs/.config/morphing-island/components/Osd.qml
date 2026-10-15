import QtQuick
import qs.config
import qs.icons
import qs.services
import qs.theme

// On-screen display: icon + bar + percentage (or "Muted"), a pill-shaped transient.
// `kind` selects the source: "volume" (default output), "mic" (default input) or "brightness".
// Sizes and timing: config/OsdConfig.qml.
Item {
    id: root

    property string kind: "volume"

    readonly property real value: kind === "brightness" ? Brightness.percent / 100 : kind === "mic" ? Audio.micVolume : Audio.volume
    readonly property bool muted: kind === "mic" ? Audio.micMuted : kind === "volume" ? Audio.muted : false
    readonly property real iconSize: Math.round(Pill.height * 0.5)

    implicitWidth: OsdConfig.width
    implicitHeight: Pill.height + OsdConfig.extraHeight

    Item {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.implicitHeight * 0.4)
        anchors.verticalCenter: parent.verticalCenter
        width: root.iconSize
        height: root.iconSize

        VolumeIcon {
            anchors.centerIn: parent
            visible: root.kind === "volume"
            size: root.iconSize
            color: Theme.icon
            level: root.value
            muted: root.muted
        }
        Glyph {
            anchors.centerIn: parent
            visible: root.kind === "mic"
            kind: root.muted ? "micOff" : "mic"
            size: root.iconSize
            color: Theme.icon
        }
        BrightnessIcon {
            anchors.centerIn: parent
            visible: root.kind === "brightness"
            size: root.iconSize
            color: Theme.icon
            level: root.value
        }
    }

    OsdBar {
        anchors.left: icon.right
        anchors.leftMargin: 12
        anchors.right: pct.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        thickness: OsdConfig.barThickness
        value: root.value
        muted: root.muted
    }

    // Fixed width (that of the widest text) so the bar does not move when the number changes.
    TextMetrics {
        id: metricsMuted
        font: pct.font
        text: root.kind === "brightness" ? "" : "Muted"
    }
    TextMetrics {
        id: metricsPct
        font: pct.font
        text: "100%"
    }

    Label {
        id: pct
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.implicitHeight * 0.45)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.ceil(Math.max(metricsMuted.advanceWidth, metricsPct.advanceWidth))
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideNone
        text: root.muted ? "Muted" : `${Math.round(root.value * 100)}%`
        color: root.muted ? Theme.dim : Theme.foreground
        font.weight: Font.DemiBold
    }
}
