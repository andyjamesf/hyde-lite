// The bar UI of the Quickshell configuration: loaded by ../shell.qml when the island is not active.
// External control: `qs ipc call <target> <function>`; `qs ipc show` lists everything.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar.services
import qs.bar.pickers
import qs.bar.modules.bar
import qs.bar.modules.controlcenter
import qs.bar.modules.notifications
import qs.bar.modules.osd
import qs.bar.modules.launcher
import qs.bar.modules.powermenu
import qs.bar.modules.barbuilder
import qs.bar.modules.lock
import qs.bar.modules.avatar
import qs.bar.modules.minibar.controller
import qs.bar.modules.minibar.view
import qs.shared.services
import qs.shared.pickers
import qs.shared.controlcenter

Scope {
    // Singletons are only created when something uses them; these must exist from startup
    // (the calendar events, which must be ready before it is opened).
    readonly property var agenda: Calendar
    readonly property var notifs: Notifications
    // The popup policy must exist from startup too, or the first notification has nowhere to go.
    readonly property var popups: Popups

    // User picture editor (only exists while it is open).
    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: avatarLoader
            required property ShellScreen modelData
            active: ShellState.avatarSource !== "" && (ShellState.avatarScreen === "" || ShellState.avatarScreen === modelData.name)

            AvatarEditor {
                modelData: avatarLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // The minimal bar (modules/minibar): a slimmer bar that takes the one above's place while it
    // is switched on. It creates its own windows, one per screen, and none while it is off.
    MiniBarWindows {}

    Variants {
        model: Quickshell.screens

        ControlCenter {}
    }

    // Popups and OSD also only exist when there is something to show, on the focused screen.
    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: popupLoader
            required property ShellScreen modelData
            active: Popups.list.length > 0 && (Hyprland.focusedMonitor?.name ?? "") === modelData.name

            NotificationPopups {
                modelData: popupLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: osdLoader
            required property ShellScreen modelData
            active: Osd.needed && (Hyprland.focusedMonitor?.name ?? "") === modelData.name

            OsdWindow {
                modelData: osdLoader.modelData
            }
        }
    }

    // Launcher and power menu only exist while open, and only on the screen where they opened: each
    // window has its own graphics context, and keeping them all created cost hundreds of MB.
    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: launcherLoader
            required property ShellScreen modelData
            active: ShellState.launcherOpen && ShellState.launcherScreen === modelData.name

            Launcher {
                modelData: launcherLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: powerLoader
            required property ShellScreen modelData
            active: ShellState.powerMenuOpen && ShellState.powerMenuScreen === modelData.name

            PowerMenu {
                modelData: powerLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: barEditorLoader
            required property ShellScreen modelData
            active: ShellState.barEditorOpen && ShellState.barEditorScreen === modelData.name

            BarEditor {
                modelData: barEditorLoader.modelData
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            ShellState.toggleLauncher("apps");
        }
        function clipboard(): void {
            ShellState.toggleLauncher("clipboard");
        }
        function calc(): void {
            ShellState.toggleLauncher("calc");
        }
        // Hyprland keybindings (replaces HyDE's keybinds_hint).
        function keys(): void {
            ShellState.toggleLauncher("keys");
        }
        // Opens a picker (pickers/Pickers.qml): themes, wallpapers, windows, files, web, emoji, glyph,
        // bookmarks, quickapps, games, wallbash, animations, hyprlock, workflows, shaders, layouts,
        // menu. Pressing the same key again closes it; an unknown or disabled name opens the apps.
        function pick(name: string): void {
            ShellState.toggleLauncher(Pickers.get(name) !== null ? "pick:" + name : "apps");
        }
        function close(): void {
            ShellState.launcherOpen = false;
        }
        // Opens on a specific monitor (e.g. "DP-1").
        function openOn(screen: string): void {
            ShellState.launcherOpen = false;
            ShellState.toggleLauncher("apps", screen);
        }
    }

    // A picture chosen in the control centre opens in the editor, to be positioned in the circle
    // before it is saved to ~/.face. The island saves it as it is; the shared service only picks
    // the file and leaves the rest to whichever shell is running.
    Connections {
        target: SysInfo
        function onAvatarFilePicked(path) {
            ShellState.avatarScreen = Hyprland.focusedMonitor?.name ?? "";
            ShellState.avatarSource = path;
        }
    }

    // The battery service is shared with the island and has no settings of its own, so the shell
    // that does have them hands over the one value it needs (services/Config.qml -> config.json).
    Binding {
        target: Battery
        property: "lowLevel"
        value: Config.widgets.battery.lowLevel
    }

    Binding {
        target: Brightness
        property: "step"
        value: Config.widgets.brightness.step
    }

    // With this off, locking hands over to HyDE's hyprlock instead of the shell's own lock screen.
    Binding {
        target: Lock
        property: "enabled"
        value: Config.widgets.lock.enabled
    }

    // The shortcut row is shared too. Opening a picker or the keybindings list is the launcher's
    // business and each shell drives its own, so the shared list asks and this answers.
    Connections {
        target: CcShortcuts

        function onOpenRequested(what: string): void {
            ShellState.toggleLauncher(what);
        }
    }

    // Here a shortcut that chooses something opens a picker, so one whose picker is not
    // registered is a button that would do nothing.
    Binding {
        target: CcShortcuts
        property: "hidden"
        value: CcShortcuts.items.filter(s => s.pick && Pickers.get(s.pick) === null).map(s => s.id)
    }

    // Cycling the bar layout only means something where there is a bar to cycle.
    Binding {
        target: CcShortcuts
        property: "extra"
        value: [
            {
                id: "barlayout",
                label: "Next bar layout",
                icon: "view_week",
                glyph: "\u{F0309}",
                run: () => BarLayout.cycle()
            }
        ]
    }

    // Where the colours come from, the bar's way: a source in its preferences.
    Binding {
        target: CcToggles
        property: "colorSourceName"
        value: Prefs.colorSource === "wallpaper" ? "From the wallpaper" : "From HyDE"
    }

    Binding {
        target: CcToggles
        property: "colorFromWallpaper"
        value: Prefs.colorSource === "wallpaper"
    }

    Connections {
        target: CcToggles

        function onColorSourceToggleRequested(): void {
            Theme.setColorSource(Prefs.colorSource === "wallpaper" ? "hyde" : "wallpaper");
        }
    }

    // The notification server is shared with the island; this shell's settings reach it here, and
    // how many popups it stacks is its own (the island shows one at a time instead).
    Binding {
        target: Notifications
        property: "historySize"
        value: Config.widgets.notifications.historySize
    }
    Binding {
        target: Notifications
        property: "normalTimeout"
        value: Config.widgets.notifications.timeout
    }
    Binding {
        target: Notifications
        property: "filterHydeOsd"
        value: Config.widgets.osd.enabled
    }
    Binding {
        target: Popups
        property: "max"
        value: Config.widgets.notifications.maxPopups
    }

    // The applications service is shared too; its history file is this shell's own.
    Binding {
        target: Apps
        property: "statePath"
        value: Quickshell.statePath("launcher.json")
    }

    // The pickers are shared with the island; this shell's settings and its own wallpaper picker
    // reach them here (config/config.json -> services/Config.qml).
    Binding {
        target: PickerSettings
        property: "enabled"
        value: Config.pickers.enabled
    }
    Binding {
        target: PickerSettings
        property: "menu"
        value: Config.pickers.menu
    }
    Binding {
        target: PickerSettings
        property: "maxResults"
        value: Config.pickers.maxResults
    }
    Binding {
        target: PickerSettings
        property: "files"
        value: Config.pickers.files
    }
    Binding {
        target: PickerSettings
        property: "quickAppsFallback"
        value: Config.pickers.quickAppsFallback
    }
    Binding {
        target: PickerSettings
        property: "recents"
        value: Config.pickers.recents
    }
    Binding {
        target: PickerSettings
        property: "webLabels"
        value: Config.pickers.webLabels
    }
    Binding {
        target: PickerSettings
        property: "webPreferred"
        value: Config.pickers.webPreferred
    }
    Binding {
        target: PickerSettings
        property: "pasteDelayMs"
        value: Config.pickers.pasteDelayMs
    }
    Binding {
        target: PickerSettings
        property: "qml"
        value: Config.pickers.qml
    }
    Binding {
        target: PickerSettings
        property: "glyphFont"
        value: Config.appearance.monoFont
    }
    Binding {
        target: PickerSettings
        property: "statePath"
        value: Paths.shellState
    }
    // The wallpaper picker is the bar's own (the island picks wallpapers its own way).
    Binding {
        target: Pickers
        property: "extra"
        value: ({
                "wallpapers": PickWallpapers
            })
    }
    // Choosing a picker in the HyDE menu opens it in this shell's launcher.
    Connections {
        target: PickMenu
        function onOpenRequested(name) {
            ShellState.launcherMode = "pick:" + name;
        }
    }

    LockScreen {}

    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        // Same trust level as `loginctl unlock-session` (used by hypridle's unlock_cmd).
        function unlock(): void {
            Lock.unlock();
        }
        function isLocked(): bool {
            return Lock.locked;
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            ShellState.togglePowerMenu();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            Notifications.toggleDnd();
        }
        function clear(): void {
            Notifications.clear();
        }
        function open(): void {
            ShellState.openControlCenter("notifications");
        }
        function toggle(): void {
            ShellState.toggleControlCenter("notifications");
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            ShellState.toggleControlCenter("");
        }
        function open(): void {
            ShellState.openControlCenter("");
        }
        function close(): void {
            ShellState.closeControlCenter();
        }
        // "wifi", "bluetooth" or "audio"
        function page(name: string): void {
            ShellState.openControlCenter(name);
        }
    }

    // Test/diagnostic hooks (read-only): qs ipc call bar-debug <function>
    IpcHandler {
        target: "bar-debug"

        // What this shell actually draws from the shared model, for checking that both offer the
        // same things: "toggles=<ids> shortcuts=<ids>". The control centre cannot be held open for
        // a screenshot (it closes as soon as a scripted call returns), so this is how the two are
        // compared — see tools/tests/test_cc_parity.py.
        function ccItems(): string {
            return "toggles=" + CcToggles.shown.map(t => t.id).join(",") + " shortcuts=" + CcShortcuts.shown.map(s => s.id).join(",");
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            ShellState.barHidden = !ShellState.barHidden;
        }
        function show(): void {
            ShellState.barHidden = false;
        }
        function hide(): void {
            ShellState.barHidden = true;
        }
        function layout(name: string): void {
            BarLayout.select(name);
        }
        // The layout editor (modules/barbuilder): opens or closes it.
        function edit(): void {
            ShellState.toggleBarEditor();
        }
        function next(): void {
            BarLayout.cycle(1);
        }
        function prev(): void {
            BarLayout.cycle(-1);
        }
        // "calendar", "media", "audio", "network", "bluetooth", "battery" or "brightness"
        // Opens a widget's popout; "" closes the one that is open.
        function popout(name: string): void {
            if (name === "")
                ShellState.popoutOwner = null;
            else
                ShellState.requestPopout(name);
        }
        // Opens a widget's menu ("hyde", "hyde:0" enters the 1st submenu); "" closes it.
        function menu(spec: string): void {
            ShellState.requestMenu(spec);
        }
        // Shows a widget's tooltip (the layout id, e.g. "clock"); "" hides it.
        function tooltip(name: string): void {
            ShellState.requestTooltip(name);
        }
        // Island background: surface, tint, container, accent, glass, outline or "#rrggbb".
        function pill(style: string): void {
            BarLayout.setPillStyle(style);
        }
        function opacity(value: real): void {
            BarLayout.setPillOpacity(value);
        }
        // Bar height in px (0 goes back to the layout's); taller/shorter change it by 2 px.
        function height(value: int): void {
            BarLayout.setHeight(value);
        }
        function taller(): void {
            BarLayout.adjustHeight(2);
        }
        function shorter(): void {
            BarLayout.adjustHeight(-2);
        }
        // Shows/collapses the AI agents' usage on the bar.
        function agents(): void {
            Prefs.aiExpanded = !Prefs.aiExpanded;
            Prefs.save();
        }
        function layouts(): string {
            return BarLayout.names.map(n => (n === BarLayout.current ? "* " : "  ") + n).join("\n");
        }
    }

    // Which of the two bars is in use; what the minimal one shows is
    // modules/minibar/model/MiniBarConfig.qml. The behaviour lives in its controller, so these are
    // one line each.
    IpcHandler {
        target: "minibar"

        function toggle(): void {
            MiniBarController.toggle();
        }
        function on(): void {
            MiniBarController.on();
        }
        function off(): void {
            MiniBarController.off();
        }
        function status(): string {
            return MiniBarController.status();
        }
    }

    IpcHandler {
        target: "colors"

        // "hyde" (follows HyDE) or "wallpaper" (colors of the current wallpaper).
        function source(name: string): void {
            Theme.setColorSource(name);
        }
        function toggle(): void {
            Theme.setColorSource(Prefs.colorSource === "wallpaper" ? "hyde" : "wallpaper");
        }
    }

    IpcHandler {
        target: "idle"

        function toggle(): void {
            Caffeine.toggle();
        }
        function isInhibited(): bool {
            return Caffeine.active;
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            Brightness.up();
        }
        function down(): void {
            Brightness.down();
        }
        function set(percent: int): void {
            Brightness.set(percent);
        }
    }

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(true);
        }
        // Choose the user picture (the same action as clicking the picture in the control center).
        function avatar(): void {
            SysInfo.chooseAvatar();
        }
        // Opens the editor with an already chosen image ("" closes it).
        function editAvatar(path: string): void {
            ShellState.avatarScreen = Hyprland.focusedMonitor?.name ?? "";
            ShellState.avatarSource = path;
        }
    }
}
