import QtQuick
import qs.config
import qs.theme

// Settings section title ("Appearance", "Behaviour"…), small and subtle.
Label {
    leftPadding: 12
    topPadding: 10
    height: 30
    verticalAlignment: Text.AlignBottom
    color: Theme.faint
    font.pixelSize: Appearance.fontSize - 2
    font.weight: Font.DemiBold
    font.letterSpacing: 0.6
}
