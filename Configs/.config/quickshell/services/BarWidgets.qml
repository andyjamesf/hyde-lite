pragma Singleton
import QtQuick
import Quickshell

// The bar's widget catalogue: id -> file in modules/bar/widgets/<File>Widget.qml. The one list the bar
// (WidgetLoader), the layout validator (scripts/validate_layouts.py reads this file) and the layout
// editor (modules/barbuilder) all use. Adding a widget is a new file plus a line here.
Singleton {
    readonly property var files: ({
            "hyde": "HydeMenu",
            "workspaces": "Workspaces",
            "activeWindow": "ActiveWindow",
            "clock": "Clock",
            "media": "Media",
            "cava": "Cava",
            "aiUsage": "AiUsage",
            "tray": "Tray",
            "audio": "Audio",
            "mic": "Mic",
            "brightness": "Brightness",
            "network": "Network",
            "bluetooth": "Bluetooth",
            "battery": "Battery",
            "stats": "Stats",
            "idle": "Idle",
            "nightLight": "NightLight",
            "notifications": "Notifications",
            "power": "Power",
            "controlCenter": "ControlCenter"
        })
    readonly property var ids: Object.keys(files)

    // "activeWindow" -> "Active window"
    function label(id) {
        const s = String(id).replace(/([A-Z])/g, " $1").toLowerCase();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
}
