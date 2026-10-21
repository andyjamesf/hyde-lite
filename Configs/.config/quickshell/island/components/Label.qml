import QtQuick
import qs.island.config
import qs.island.theme

// Island text: font and size from config/Appearance.qml, theme colour, tabular digits.
Text {
    color: Theme.foreground
    font.family: Appearance.font
    font.pixelSize: Appearance.fontSize
    font.features: ({
            "tnum": 1
        })
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.NativeRendering
}
