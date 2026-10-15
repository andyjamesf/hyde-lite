import QtQuick
import QtQuick.Layouts
import qs.services

// Material Symbols icon by name (ligature), e.g. MaterialIcon { icon: "volume_up" }.
// `fill` (0..1) animates the fill through the font's FILL variable axis.
// The box is always a `size` square: icons side by side stay aligned, whatever the glyph.
Text {
    id: root

    property string icon
    property real fill: 0
    property int weight: 400
    property int size: Config.appearance.iconSize

    width: size
    height: size
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    text: icon
    color: Theme.text
    font.family: Config.appearance.iconFont
    font.pixelSize: size
    font.variableAxes: ({
            "FILL": root.fill,
            "wght": root.weight,
            "opsz": Math.max(20, Math.min(48, root.size))
        })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on fill {
        NumberAnim {}
    }
    Behavior on color {
        ColorAnim {}
    }
}
