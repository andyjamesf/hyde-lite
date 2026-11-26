pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar.modules.minibar.model
import qs.bar.modules.minibar.controller

// Effective bar layout. The presets live in config/layouts.json (more can be added), and the owner's own
// in ~/.config/quickshell/layouts.json, which replaces a shipped one of the same name. The owner's file is
// validated (scripts/validate_layouts.py) on every change; when it is invalid the previous layouts stay
// and a notification names the first problem. Each preset defines the style, the dimensions and which widgets appear in each section.
//
// Which one is used, in order:
//   1. the one picked in the HyDE menu / over IPC (`qs ipc call bar layout <name>`, `next`, `prev`),
//      stored in Prefs;
//   2. the "layout" from config.json.
// When the HyDE theme changes, if config.json has a layout for that theme in "themeLayouts",
// that one is used. The island rounding follows Hyprland's `decoration:rounding`, which
// each HyDE theme sets — the bar matches the look of the windows.
Singleton {
    id: root

    property var shippedPresets: ({})
    property var userPresets: ({})
    // The last problem found in the owner's layouts file (empty: none).
    property string layoutError: ""
    readonly property var presets: Object.assign({}, shippedPresets, userPresets)
    readonly property var names: Object.keys(presets)
    readonly property string current: presets[Prefs.layout] ? Prefs.layout : presets[Config.bar.layout] ? Config.bar.layout : names[0] ?? ""
    readonly property var preset: presets[current] ?? ({})

    // The minimal bar (modules/minibar) can stand in for this one, and while it does, the values
    // below are its own: every widget reads its size and shape from here, so this is the one place
    // that has to know which bar is in charge. The dependency only points this way — that module's
    // model reads nothing from the services layer.
    readonly property bool mini: MiniBarState.replacesMainBar
    // The panels (control centre, notifications) open in the middle rather than in the corner the
    // normal bar's buttons sit in. Read by modules/controlcenter and modules/notifications.
    readonly property bool centerPanels: mini && MiniBarConfig.centerPanels
    // The clock's day. A layout of the minimal bar can ask for it or refuse it (clockDate);
    // otherwise it is the owner's setting in config.json, which is what the normal bar follows.
    // widgets/ClockWidget.qml reads this rather than the setting, so one clock serves both bars.
    // Battery time remaining next to the percentage. The minimal bar sets it in its own settings
    // (MiniBarConfig.batteryShowTime); the normal bar in widgets.battery.showTime (Config.qml).
    readonly property bool batteryShowTime: mini ? MiniBarConfig.batteryShowTime : Config.widgets.battery.showTime
    readonly property bool clockShowDate: mini && MiniBarState.layout.clockDate !== undefined ? MiniBarState.layout.clockDate : Config.widgets.clock.showDate

    property string hydeTheme: ""
    property int hyprRounding: 10

    // The minimal bar's "none" style is a continuous bar whose strip is not drawn (its window
    // draws the strip, not this), so only the floating groups ("islands" internally, "floating" in MiniBarConfig) differ here.
    readonly property string style: mini ? (MiniBarConfig.style === "floating" || MiniBarConfig.style === "islands" ? "islands" : "continuous") : preset.style ?? "islands"
    readonly property bool islands: style === "islands"
    readonly property string position: mini ? MiniBarConfig.position : preset.position ?? Config.bar.position
    readonly property bool atTop: position !== "bottom"
    // Height picked in the menu/IPC, or the layout's. Text, icons and radius follow it.
    readonly property int layoutHeight: preset.height ?? 28
    readonly property int height: mini && MiniBarConfig.height > 0 ? Math.max(minHeight, Math.min(maxHeight, MiniBarConfig.height)) : Prefs.barHeight > 0 ? Prefs.barHeight : layoutHeight
    readonly property int minHeight: 16
    readonly property int maxHeight: 40
    readonly property var heights: [
        {
            label: "Short",
            value: 19
        },
        {
            label: "Normal",
            value: 23
        },
        {
            label: "Tall",
            value: 27
        },
        {
            label: "Extra tall",
            value: 32
        }
    ]
    readonly property int margin: islands ? (mini ? MiniBarConfig.margin : preset.margin ?? 4) : 0
    // Horizontal padding inside each module (BarItem). The minimal bar can set it (MiniBarConfig.itemPadding).
    readonly property int itemPadding: mini && MiniBarConfig.itemPadding >= 0 ? MiniBarConfig.itemPadding : Math.round(height * 0.2)
    readonly property int spacing: mini ? MiniBarConfig.spacing : preset.spacing ?? 8
    readonly property int radius: Math.min(mini ? (MiniBarConfig.radius >= 0 ? MiniBarConfig.radius : hyprRounding) : preset.radius ?? hyprRounding, Math.floor(height / 2))
    readonly property real requestedOpacity: mini && MiniBarConfig.opacity >= 0 ? MiniBarConfig.opacity : Prefs.pillOpacity >= 0 ? Prefs.pillOpacity : preset.opacity ?? Config.bar.opacity
    // Never below Config.bar.minOpacity, except in the styles that are see-through on purpose.
    readonly property real opacity: pillStyle === "glass" || pillStyle === "outline" ? requestedOpacity : Math.max(requestedOpacity, Config.bar.minOpacity)

    // Island background. All options derive from the theme colors, so they change with it.
    readonly property var pillStyles: [
        {
            id: "surface",
            label: "Theme background"
        },
        {
            id: "tint",
            label: "Accent tint"
        },
        {
            id: "container",
            label: "Raised"
        },
        {
            id: "accent",
            label: "Accent color"
        },
        {
            id: "glass",
            label: "Glass"
        },
        {
            id: "outline",
            label: "Outline only"
        }
    ]
    readonly property string pillStyle: Prefs.pillStyle || preset.pillStyle || Config.bar.pillStyle
    readonly property color pillColor: {
        const a = opacity;
        // A fixed colour asked for by the minimal bar ("" there: follow the theme, as this bar does).
        if (mini && MiniBarConfig.color !== "")
            return Theme.alpha(MiniBarConfig.color, a);
        switch (pillStyle) {
        case "surface":
            return Theme.alpha(Theme.surface, a);
        case "tint":
            return Theme.alpha(Qt.tint(Theme.surface, Theme.alpha(Theme.primary, 0.24)), a);
        case "container":
            return Theme.alpha(Theme.surfaceContainerHighest, a);
        case "accent":
            return Theme.alpha(Theme.primaryContainer, a);
        case "glass":
            return Theme.alpha(Theme.surface, Math.min(a, 0.4));
        case "outline":
            return "transparent";
        default:
            // Fixed color written in config.json ("#rrggbb").
            return /^#[0-9a-fA-F]{6,8}$/.test(pillStyle) ? Theme.alpha(pillStyle, a) : Theme.alpha(Theme.surface, a);
        }
    }
    readonly property color pillBorder: pillStyle === "outline" ? Theme.alpha(Theme.primary, 0.7) : pillStyle === "glass" ? Theme.alpha(Theme.text, 0.18) : Theme.alpha(Theme.outlineVariant, 0.5)

    // Opaque color seen behind the island text (to guarantee contrast). With transparent
    // styles what is behind is the wallpaper: its measured top strip (Theme.wallTop), or the theme
    // background until that is known.
    readonly property color pillBase: {
        const c = Qt.color(pillColor);
        // The minimal bar's "none" style draws nothing although pillColor still carries its opacity.
        if (c.a >= 0.5 && !(mini && MiniBarConfig.style === "none"))
            return Qt.rgba(c.r, c.g, c.b, 1);
        return Theme.wallTop.a > 0 ? Theme.wallTop : Theme.surface;
    }

    // A bar with no background (the minimal bar's "none" style) has the wallpaper itself behind its text,
    // and a wallpaper is not one colour: a bright patch under the clock is invisible in the average of
    // the strip. So there the contrast is measured against what is really behind each element (the
    // wallpaper's top strip, in Theme.wallTopCells), and the colour is moved just enough to keep it.
    readonly property bool noBackground: mini && MiniBarConfig.style === "none"
    // Where each side of the bar is, in screen x: {left, center, right} -> {x0, x1}. The bar's sections report
    // it as they move; it is rounded and applied once the movement settles (they report on every frame of an
    // animation, and everything on the bar used to be coloured again each time).
    property var sides: ({})
    property var pendingSides: ({})
    function setSide(name, x0, width) {
        const a = Math.round(x0), b = Math.round(x0 + width);
        const cur = pendingSides[name];
        if (cur && cur.x0 === a && cur.x1 === b)
            return;
        const p = Object.assign({}, pendingSides);
        p[name] = {
            x0: a,
            x1: b
        };
        pendingSides = p;
        sidesTimer.restart();
    }
    // The sides as they were when sideInfo was last worked out.
    property var usedSides: ({})
    Timer {
        id: sidesTimer
        interval: 120
        onTriggered: {
            BarLayout.sides = BarLayout.pendingSides;
            // Only a side that appeared or moved a lot is worth measuring again: the digits of the clock
            // changing width are not.
            if (BarLayout.sidesMoved())
                BarLayout.refreshSideInfo();
        }
    }

    function sidesMoved() {
        for (const k in sides) {
            const u = usedSides[k];
            if (!u || Math.abs(u.x0 - sides[k].x0) > 120 || Math.abs(u.x1 - sides[k].x1) > 120)
                return true;
        }
        return false;
    }

    // For each side: what is behind it (its lightest and darkest cell) and the colour that every plain text
    // and icon on it gets: the theme's text colour moved just enough for the best contrast against both.
    // Worked out when the wallpaper or the palette changes (and when a side first appears or moves a lot),
    // never per frame: a plain property, not a binding.
    property var sideInfo: ({})

    function refreshSideInfo() {
        const out = {};
        if (noBackground && Theme.wallTopCells.length > 0) {
            for (const k in sides) {
                const ext = Theme.wallBehind(sides[k].x0, sides[k].x1);
                if (ext)
                    out[k] = {
                        ext: ext,
                        fg: fitTo(Qt.color(Theme.text), ext)
                    };
            }
        }
        usedSides = sides;
        sideInfo = out;
    }

    // The wallpaper and the palette change in bursts while the colours animate: one measurement after the last.
    Timer {
        id: refreshTimer
        interval: 250
        onTriggered: BarLayout.refreshSideInfo()
    }
    readonly property var watchedCells: Theme.wallTopCells
    readonly property color watchedText: Theme.text
    onWatchedCellsChanged: refreshTimer.restart()
    onWatchedTextChanged: refreshTimer.restart()
    onNoBackgroundChanged: refreshTimer.restart()

    // `base` moved towards white or black until it keeps 4.5:1 against the lightest and the darkest of `ext`
    // (the best it can do when no colour keeps it against both).
    function fitTo(base, ext) {
        const r = 4.5;
        const worst = c => Math.min(Theme.contrast(c, ext.light), Theme.contrast(c, ext.dark));
        if (worst(base) >= r)
            return base;
        let best = base;
        let bestWorst = worst(base);
        for (const target of ["#ffffff", "#000000"]) {
            for (let t = 0.1; t < 1.0001; t += 0.1) {
                const c = Theme.blend(base, target, Math.min(t, 1));
                const w = worst(c);
                if (w > bestWorst + 0.001) {
                    best = c;
                    bestWorst = w;
                }
                if (w >= r)
                    break;
            }
        }
        return best;
    }

    // The side of the bar an element is on: the nearest section above it (Section.side in Bar.qml and MiniBar.qml).
    function sideOf(item) {
        for (let p = item; p; p = p.parent)
            if (p.side !== undefined && p.side !== "")
                return p.side;
        return "";
    }

    // The colour for `item` (the same as readable() when the bar has no background to be measured against).
    // Without a background, every plain text and icon on a side of the bar gets the SAME colour (sideInfo);
    // only a colour that means something (an alert, a charging battery...) keeps its hue, adjusted the same way.
    function readableFor(item, fg, minRatio) {
        const info = noBackground && item ? sideInfo[sideOf(item)] : undefined;
        if (!info)
            return readable(fg, minRatio ?? 4.5);
        const c0 = Qt.color(fg);
        const c = c0.hsvSaturation > 0.35 ? fitTo(c0, info.ext) : info.fg;
        return Qt.rgba(c.r, c.g, c.b, c0.a);
    }

    // Readable color over the islands: text 4.5:1, icons and graphical elements 3:1.
    function readable(color, minRatio) {
        return Theme.readable(color, pillBase, minRatio ?? 4.5);
    }

    function setPillStyle(style) {
        Prefs.pillStyle = style;
        Prefs.save();
    }

    // 0 goes back to the layout height.
    function setHeight(value) {
        Prefs.barHeight = value > 0 ? Math.max(minHeight, Math.min(maxHeight, Math.round(value))) : 0;
        Prefs.save();
    }

    function adjustHeight(step) {
        setHeight(height + step);
    }

    function setPillOpacity(value) {
        Prefs.pillOpacity = value;
        Prefs.save();
    }
    // Text and icons follow the height, but never become unreadable.
    readonly property int fontSize: mini && MiniBarConfig.fontSize > 0 ? MiniBarConfig.fontSize : preset.fontSize ?? Math.max(11, Math.min(Config.appearance.fontSize, Math.round(height * 0.46)))
    readonly property int iconSize: mini && MiniBarConfig.iconSize > 0 ? MiniBarConfig.iconSize : preset.iconSize ?? Math.max(14, Math.min(Config.appearance.iconSize, Math.round(height * 0.64)))
    readonly property var left: preset.left ?? []
    readonly property var center: preset.center ?? []
    readonly property var right: preset.right ?? []

    function select(name) {
        if (!presets[name]) {
            console.warn(`unknown layout: "${name}"`);
            return;
        }
        Prefs.layout = name;
        Prefs.save();
        Utils.run(`notify-send -a "Quickshell" -r 91 -t 1500 -h int:transient:1 -i preferences-desktop "Bar layout" "${presets[name].label ?? name}"`);
    }

    function cycle(step = 1) {
        // "Next bar layout" and `qs ipc call bar next|prev` drive whichever bar is in charge: the
        // minimal bar keeps its own layouts (modules/minibar/model/MiniBarConfig.qml).
        if (mini) {
            MiniBarController.cycleLayout(step);
            return;
        }
        const i = names.indexOf(current);
        select(names[(i + step + names.length) % names.length]);
    }

    FileView {
        path: Quickshell.shellPath("bar/config/layouts.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.shippedPresets = JSON.parse(text());
            } catch (e) {
                console.warn("invalid layouts.json:", e);
            }
        }
    }

    // Saves a layout to the owner's file (the editor's Save). The file is watched, so it is validated and
    // applied like any hand edit; a layout with the name of a shipped one replaces it.
    function saveUserPreset(name, layout) {
        const all = Object.assign({}, userPresets);
        all[name] = layout;
        userFile.setText(JSON.stringify(all, null, 2) + "\n");
    }

    // Drops the owner's version of a layout (back to the shipped one, if there is one).
    function removeUserPreset(name) {
        const all = Object.assign({}, userPresets);
        delete all[name];
        userFile.setText(JSON.stringify(all, null, 2) + "\n");
    }

    function reportLayoutError(msg) {
        layoutError = msg;
        console.warn("layouts.json:", msg);
        Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-r", "92", "-u", "critical", "-i", "dialog-warning", "Bar layouts file not applied", msg]);
    }

    // The owner's layouts. Nothing changes until the file passes the validator.
    FileView {
        id: userFile
        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/quickshell/layouts.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            // A change while the validator runs is handled when it exits.
            if (validator.running)
                validator.again = true;
            else
                validator.running = true;
        }
        // No file is the normal case.
        onLoadFailed: error => {
            root.userPresets = ({});
            root.layoutError = "";
        }
    }

    Process {
        id: validator
        property bool again: false
        command: ["python3", "-I", Quickshell.shellPath("bar/scripts/validate_layouts.py"), userFile.path]
        stdout: StdioCollector {
            id: validatorOut
        }
        onExited: code => {
            if (again) {
                again = false;
                running = true;
                return;
            }
            if (code !== 0) {
                root.reportLayoutError(validatorOut.text.trim().split("\n")[0] || `validator exited with ${code}`);
                return;
            }
            try {
                root.userPresets = JSON.parse(userFile.text());
                root.layoutError = "";
            } catch (e) {
                root.reportLayoutError(String(e));
            }
        }
    }

    // Current HyDE theme (rewritten on every theme change).
    FileView {
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/hyde/staterc`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = /^HYDE_THEME="?([^"\n]*)"?/m.exec(text());
            if (m && m[1] !== root.hydeTheme)
                root.hydeTheme = m[1];
        }
    }

    onHydeThemeChanged: {
        const mapped = Config.bar.themeLayouts[hydeTheme];
        if (mapped && mapped !== current)
            select(mapped);
        rounding.running = true;
    }

    // The theme applies the rounding in Hyprland right after changing staterc; read it with some delay.
    Process {
        id: rounding
        command: ["sh", "-c", "sleep 1; hyprctl getoption decoration:rounding -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprRounding = JSON.parse(text).int;
                } catch (e) {}
            }
        }
    }
}
