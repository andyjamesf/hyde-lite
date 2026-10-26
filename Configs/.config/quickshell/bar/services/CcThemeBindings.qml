import QtQuick
import Quickshell
import qs.shared.controlcenter

// The control centre's main page is drawn by shared components that read their colours and font
// from CcTheme (shared/controlcenter/CcTheme.qml). This hands them the bar's: its primary colour is
// the island's accent, its text colours the island's foreground, dim and faint.
Scope {
    Binding {
        target: CcTheme
        property: "background"
        value: Theme.surface
    }
    Binding {
        target: CcTheme
        property: "surface"
        value: Theme.surfaceContainerHigh
    }
    Binding {
        target: CcTheme
        property: "border"
        value: Theme.border
    }
    Binding {
        target: CcTheme
        property: "hover"
        value: Theme.hover
    }
    Binding {
        target: CcTheme
        property: "pressed"
        value: Theme.pressed
    }
    Binding {
        target: CcTheme
        property: "foreground"
        value: Theme.text
    }
    Binding {
        target: CcTheme
        property: "dim"
        value: Theme.textDim
    }
    Binding {
        target: CcTheme
        property: "faint"
        value: Theme.textFaint
    }
    Binding {
        target: CcTheme
        property: "icon"
        value: Theme.text
    }
    Binding {
        target: CcTheme
        property: "accent"
        value: Theme.primary
    }
    Binding {
        target: CcTheme
        property: "accentContent"
        value: Theme.onPrimary
    }
    Binding {
        target: CcTheme
        property: "danger"
        value: Theme.error
    }
    Binding {
        target: CcTheme
        property: "fontFamily"
        value: Config.appearance.font
    }
    Binding {
        target: CcTheme
        property: "nerdFont"
        value: "JetBrainsMono Nerd Font"
    }
    Binding {
        target: CcTheme
        property: "fontSize"
        // The main page is drawn at 84% (bar/modules/controlcenter/ControlCenter.qml), which would make the
        // text smaller than the island's; a fifth more keeps it at about the same size on screen.
        value: Theme.bodyMedium * 1.2
    }
    Binding {
        target: CcTheme
        property: "textRendering"
        value: Text.CurveRendering
    }
    Binding {
        target: CcTheme
        property: "textPadding"
        value: 1
    }
}
