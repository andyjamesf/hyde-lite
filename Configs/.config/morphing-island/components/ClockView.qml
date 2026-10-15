import QtQuick
import qs.config
import qs.services

// Base mode: the small pill with the time and, when music is playing, an equalizer next to it
// ("13:37 ▂▅▇"). The equalizer shrinks to 0 when playback stops, so the pill grows/shrinks smoothly.
Item {
    implicitWidth: Math.max(Pill.minWidth, row.implicitWidth + 2 * Math.round(Pill.height * Pill.paddingFactor))
    implicitHeight: Pill.height

    Row {
        id: row
        anchors.centerIn: parent
        // The gap between the time and the equalizer lives inside EqBars (leadingGap).
        spacing: 0

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.time
            font.pixelSize: Appearance.fontSize + 1
            font.weight: Font.DemiBold
        }

        EqBars {
            anchors.verticalCenter: parent.verticalCenter
            leadingGap: Pill.eqLeadingGap
            playing: Media.playing
        }
    }
}
