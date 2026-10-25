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

Scope {
    // Singletons are only created when something uses them; these must exist from startup
    // (the calendar events, which must be ready before it is opened).
    readonly property var agenda: Agenda
    readonly property var notifs: Notifs

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
            active: Notifs.popups.length > 0 && (Hyprland.focusedMonitor?.name ?? "") === modelData.name

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

    // The battery service is shared with the island and has no settings of its own, so the shell
    // that does have them hands over the one value it needs (services/Config.qml -> config.json).
    Binding {
        target: Battery
        property: "lowLevel"
        value: Config.widgets.battery.lowLevel
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
            Notifs.toggleDnd();
        }
        function clear(): void {
            Notifs.clear();
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
            ShellState.idleInhibited = !ShellState.idleInhibited;
        }
        function isInhibited(): bool {
            return ShellState.idleInhibited;
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            Brightness.change(Config.widgets.brightness.step);
        }
        function down(): void {
            Brightness.change(-Config.widgets.brightness.step);
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
