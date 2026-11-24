import QtQuick
import qs.bar.services

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
    // Not NativeRendering: at the 1.5x scale of this screen it snapped glyphs to whole pixels and the
    // letters came out jagged and unevenly spaced (apps list, subtitles).
    renderType: Text.CurveRendering

    Behavior on color {
        ColorAnim {}
    }
}
