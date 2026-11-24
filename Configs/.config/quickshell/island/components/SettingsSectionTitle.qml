import QtQuick
import qs.island.config
import qs.island.theme

// Settings section title ("Appearance", "Behaviour"…), small and subtle.
Label {
    leftPadding: 12
    topPadding: 10
    height: 30
    verticalAlignment: Text.AlignBottom
    color: Theme.faint
    font.pixelSize: Math.max(Appearance.fontSize - 2, Appearance.minFontSize)
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
}
