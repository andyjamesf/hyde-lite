import QtQuick
import Quickshell
import qs.island.config
import qs.island.theme
import qs.shared.controlcenter

// The control centre is drawn by shared components that read their colours, font and animation
// scale from CcTheme (shared/controlcenter/CcTheme.qml). This hands them the island's.
Scope {
    Binding {
        target: CcTheme
        property: "background"
        value: Theme.background
    }
    Binding {
        target: CcTheme
        property: "surface"
        value: Theme.surface
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
        value: Theme.foreground
    }
    Binding {
        target: CcTheme
        property: "dim"
        value: Theme.dim
    }
    Binding {
        target: CcTheme
        property: "faint"
        value: Theme.faint
    }
    Binding {
        target: CcTheme
        property: "icon"
        value: Theme.icon
    }
    Binding {
        target: CcTheme
        property: "accent"
        value: Theme.accent
    }
    Binding {
        target: CcTheme
        property: "accentContent"
        value: Theme.accentContent
    }
    Binding {
        target: CcTheme
        property: "danger"
        value: Theme.danger
    }
    Binding {
        target: CcTheme
        property: "fontFamily"
        value: Appearance.font
    }
    Binding {
        target: CcTheme
        property: "nerdFont"
        value: Appearance.nerdFont
    }
    Binding {
        target: CcTheme
        property: "fontSize"
        value: Appearance.fontSize
    }
    Binding {
        target: CcTheme
        property: "panelWidth"
        value: ControlCenter.width
    }
    Binding {
        target: CcTheme
        property: "tileHeight"
        value: ControlCenter.tileHeight
    }
    Binding {
        target: CcTheme
        property: "sliderThrottleMs"
        value: ControlCenter.sliderThrottleMs
    }
    Binding {
        target: CcTheme
        property: "duration"
        value: (ms => Animations.duration(ms))
    }
}
