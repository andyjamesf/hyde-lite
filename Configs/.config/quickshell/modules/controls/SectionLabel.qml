import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Small title of a section inside a panel.
StyledText {
    Layout.fillWidth: true
    Layout.topMargin: 4
    font.pixelSize: Theme.labelSmall
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.6
    color: Theme.textDim
}
