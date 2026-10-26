import QtQuick

// Text of the control centre: the shell's font and size, tabular digits (shared/controlcenter/CcTheme.qml).
Text {
    color: CcTheme.foreground
    font.family: CcTheme.fontFamily
    font.pixelSize: CcTheme.fontSize
    font.features: ({
            "tnum": 1
        })
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: CcTheme.textRendering
    topPadding: CcTheme.textPadding
    bottomPadding: CcTheme.textPadding
}
