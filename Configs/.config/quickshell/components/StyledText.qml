import QtQuick
import qs.services

// Shell text: Inter, tabular figures (numbers don't "dance" when they change) and 1 px of vertical
// padding, because with `elide` Qt clips to the line box and, with fractional scaling,
// the descenders of letters (g, p, y) got cut off.
Text {
    color: Theme.text
    font.family: Config.appearance.font
    font.pixelSize: Config.appearance.fontSize
    font.features: ({
            "tnum": 1
        })
    topPadding: 1
    bottomPadding: 1
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.NativeRendering

    Behavior on color {
        ColorAnim {}
    }
}
