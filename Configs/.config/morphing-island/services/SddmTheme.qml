pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Keeps the login screen (SDDM theme in sddm/, installed by scripts/sddm.py) matching the island:
// when the colours, the wallpaper or the settings change, scripts/sddm.py sync rewrites the theme's
// theme.conf.user and copies the wallpaper and avatar. Does nothing until the theme is installed.
Singleton {
    id: root

    // The island's colour roles and opacity, set by shell.qml (qs.theme imports qs.services, so a
    // service cannot import it back).
    property var roles: null
    property real islandOpacity: 0.94

    // The values handed to the theme (keys of sddm/theme.conf).
    readonly property var values: {
        const r = roles;
        if (!r)
            return null;
        const c = x => String(x);
        return {
            background: c(r.background),
            surface: c(r.surface),
            foreground: c(r.foreground),
            accent: c(r.accent),
            accentContent: c(r.accentContent),
            dim: c(r.dim),
            faint: c(r.faint),
            border: c(r.border),
            shadow: c(r.shadow),
            danger: c(r.danger),
            hover: c(r.hover),
            islandOpacity: islandOpacity,
            font: Appearance.font,
            iconFont: Appearance.nerdFont,
            fontSize: Appearance.fontSize,
            springOmega: Animations.springOmega,
            pillHeight: Pill.height,
            pillTopMargin: Pill.topMargin,
            pillMinWidth: Pill.minWidth,
            cardWidth: LockScreenConfig.cardWidth,
            cardPadding: LockScreenConfig.cardPadding,
            cardRadius: LockScreenConfig.cardRadius,
            cardOffset: LockScreenConfig.cardOffset,
            clockSize: LockScreenConfig.clockSize,
            avatarSize: LockScreenConfig.avatarSize,
            avatarPath: Paths.expand(LockScreenConfig.avatarPath),
            fieldWidth: LockScreenConfig.fieldWidth,
            fieldHeight: LockScreenConfig.fieldHeight,
            veil: LockScreenConfig.veil,
            entry: LockScreenConfig.entry,
            locale: Clock.locale,
            timeFormat: Clock.timeFormat,
            longDateFormat: Clock.longDateFormat
        };
    }
    // Last result of a sync ({ ok, changed } or { ok: false, reason }).
    property var lastResult: null

    function sync() {
        if (!values)
            return;
        if (runner.running) {
            again = true;
            return;
        }
        runner.command = ["python3", Quickshell.shellPath("scripts/sddm.py"), "sync", JSON.stringify(values)];
        runner.running = true;
    }
    property bool again: false

    onValuesChanged: if (LoginScreenConfig.sync)
        debounce.restart()

    Timer {
        id: debounce
        interval: 1500
        onTriggered: root.sync()
    }

    // The wallpaper: wall.set is replaced by HyDE (a new link), so its target is checked now and then.
    property string _wall: ""
    Timer {
        interval: LoginScreenConfig.wallpaperCheckSeconds * 1000
        running: LoginScreenConfig.sync
        repeat: true
        triggeredOnStart: true
        onTriggered: wallCheck.running = true
    }
    Process {
        id: wallCheck
        command: ["readlink", "-f", `${Paths.cacheHome}/hyde/wall.set`]
        stdout: StdioCollector {
            onStreamFinished: {
                const w = text.trim();
                if (w !== root._wall) {
                    root._wall = w;
                    debounce.restart();
                }
            }
        }
    }

    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.lastResult = JSON.parse(text.trim().split("\n").pop());
                } catch (e) {
                    root.lastResult = null;
                }
                if (root.again) {
                    root.again = false;
                    Qt.callLater(root.sync);
                }
            }
        }
    }
}
