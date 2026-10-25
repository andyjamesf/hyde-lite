pragma Singleton
import QtQuick
import Quickshell

// Power menu (island mode "power"): a row of tiles. Hibernate is left out (not configured).
Singleton {
    // Tiles, in order. Each entry:
    //   id       unique name
    //   label    text under the tile
    //   glyph    icon kind drawn by icons/PowerGlyph.qml: "lock", "suspend",
    //            "logout", "restart", "power"
    //   command  argv list run with Launch.run() after the island closes
    //   confirm  true = the first press arms the tile (turns red) and a second press runs it
    readonly property var actions: [
        {
            id: "lock",
            label: "Lock",
            glyph: "lock",
            command: ["loginctl", "lock-session"],
            confirm: false
        },
        {
            id: "suspend",
            label: "Suspend",
            glyph: "suspend",
            command: ["systemctl", "suspend"],
            confirm: false
        },
        {
            // `hyde-shell logout` ends the uwsm session properly (and falls back to Hyprland's
            // `hl.dsp.exit()` outside uwsm); without HyDE, exit Hyprland directly.
            id: "logout",
            label: "Log out",
            glyph: "logout",
            command: ["sh", "-c", "if command -v hyde-shell >/dev/null 2>&1; then exec hyde-shell logout; else exec hyprctl dispatch 'hl.dsp.exit()'; fi"],
            confirm: true
        },
        {
            id: "restart",
            label: "Restart",
            glyph: "restart",
            command: ["systemctl", "reboot"],
            confirm: true
        },
        {
            id: "poweroff",
            label: "Power off",
            glyph: "power",
            command: ["systemctl", "poweroff"],
            confirm: true
        }
    ]
    // An armed tile disarms after this long. Milliseconds, default 4000.
    readonly property int confirmTimeout: 4000
    // Tile size in pixels. Default 88.
    readonly property int tileSize: 88
}
