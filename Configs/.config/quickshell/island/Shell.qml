import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.core
import qs.island.config
import qs.island.services
import qs.island.theme
import qs.shared.services

// Morphing Island: a single floating island at the top of each screen that turns into a clock,
// an expanded bar, OSDs, notifications, the launcher, the control center, etc.
// Loaded by ../shell.qml when ~/.local/state/morphing-island/active exists (`island on`, which swaps it
// with the bar UI).
// Tunables: config/ (see config/README.md).
Scope {
    // Singletons are only created when something uses them: this starts the notification server now.
    readonly property int notificationCount: Notifications.count
    // The polkit agent must exist from startup (it registers with polkitd).
    readonly property bool polkitRegistered: Polkit.registered
    // Wi-Fi and Bluetooth agent (scripts/agents.py) from startup.
    readonly property var agentRequests: Agents.queue
    // The login screen (SDDM) follows the island's colours and wallpaper from startup.
    Binding {
        target: SddmTheme
        property: "roles"
        value: Theme.targetRoles
    }
    Binding {
        target: SddmTheme
        property: "islandOpacity"
        value: Theme.islandOpacity
    }
    // The brightness service is shared with the bar and has no settings of its own, so this shell
    // hands it the two values it reads from config/OsdConfig.qml.
    Binding {
        target: Brightness
        property: "step"
        value: OsdConfig.brightnessStep
    }
    Binding {
        target: Brightness
        property: "dimmingThreshold"
        value: OsdConfig.dimmingThreshold
    }
    Binding {
        target: Audio
        property: "armDelay"
        value: OsdConfig.audioArmDelay
    }
    Binding {
        target: Audio
        property: "micMinDelta"
        value: OsdConfig.micMinDelta
    }
    Binding {
        target: Audio
        property: "micMinIntervalMs"
        value: OsdConfig.micMinIntervalMs
    }

    Variants {
        model: Quickshell.screens

        IslandWindow {}
    }

    // PC statistics detached from the control center (System page): a floating card over the apps.
    Variants {
        model: Quickshell.screens

        StatsWindow {}
    }

    // Lock screen (ext-session-lock + PAM): see services/Lock.qml.
    LockScreen {}

    // Volume, microphone and brightness changes (keys, apps, other panels) → OSD in the island of
    // the focused screen.
    Connections {
        target: Audio
        function onChangedByUser() {
            IslandController.showTransient(IslandState.volume);
        }
        function onMicChangedByUser() {
            if (OsdConfig.showMic)
                IslandController.showTransient(IslandState.mic);
        }
    }
    Connections {
        target: Brightness
        function onChangedByUser() {
            IslandController.showTransient(IslandState.brightness);
        }
    }

    // qs ipc call lock <function> (hypridle, loginctl lock-session)
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

    // qs ipc call island <function>
    IpcHandler {
        target: "island"

        // Opens (or closes, if already open) a surface: launcher, controlcenter, theme…
        function open(mode: string): void {
            IslandController.open(mode);
        }
        function close(): void {
            IslandController.close();
        }
        // Hides/shows the pill (windows move up to the top); persisted (Prefs "pill.hidden").
        function hide(): void {
            Pill.setHidden(!Pill.hidden);
        }
        function pin(): void {
            IslandController.togglePin();
        }
        function mode(): string {
            return IslandController.mode || (IslandController.pinned ? "expanded" : "clock");
        }
        // Peace mode (no popups, history only); toggles and is persisted.
        function peace(): void {
            Notifications.togglePeace();
        }
        // Caffeine (idle inhibitor); toggles and is persisted.
        function caffeine(): void {
            Caffeine.toggle();
        }
        // Night light (hyprsunset through HyDE's script); toggles. Returns "turning on" or "turning off"
        // (HyDE's state file, and so NightLight.active, updates a moment later).
        // Takes a screenshot and shows it in the island (Copy, Save, Edit, Delete): "area",
        // "freeze" (area on a frozen screen), "output" (focused monitor) or "screen" (all).
        function screenshot(mode: string): void {
            Screenshot.take(mode);
        }
        // The PC statistics window: "detach" (floating, on the focused screen), "attach" (closes it),
        // "toggle", "compact" (switches the compact view).
        function stats(action: string): void {
            if (action === "detach" || (action === "toggle" && !SysStats.detached))
                SysStats.detach(IslandController.focusedScreen);
            else if (action === "attach" || action === "toggle")
                SysStats.attach();
            else if (action === "compact")
                SysStats.setCompact(!SysStats.compact);
        }
        // Brings the login screen (SDDM theme) up to date with the island now; returns the result.
        // Normally automatic (services/SddmTheme.qml).
        function sddmSync(): string {
            SddmTheme.sync();
            return SddmTheme.lastResult ? JSON.stringify(SddmTheme.lastResult) : "syncing";
        }
        // Light or dark for the wallpaper palette: "auto", "dark", "light", or nothing to step
        // through the three. Sets HyDE's too, so the other programs flip with the island.
        function scheme(mode: string): string {
            if (mode === "")
                ThemeConfig.cycleMode();
            else
                ThemeConfig.setMode(mode);
            return ThemeConfig.mode;
        }
        function nightlight(): string {
            NightLight.toggle();
            return NightLight.active ? "turning off" : "turning on";
        }
        // Number of notifications in the history.
        function notifications(): string {
            return String(Notifications.count);
        }
        function clearNotifications(): void {
            Notifications.clear();
        }
        // Launcher without a keyboard: opens it (if not already open on this screen) and types the
        // query, prefix included ("=2+2", ":text", "fire").
        function launcher(query: string): void {
            const here = IslandController.mode === IslandState.launcher && IslandController.screen === IslandController.focusedScreen;
            // With a picker open, reopen the normal launcher (closing empties the picker).
            if (here && LauncherState.provider !== "")
                IslandController.close();
            if (IslandController.mode !== IslandState.launcher)
                IslandController.open(IslandState.launcher);
            LauncherState.query = query;
        }
        // Opens the launcher in a picker (services/Pickers.qml): windows, files, web, emoji, glyph,
        // bookmarks, quickapps, games, wallbash, animations, hyprlock, workflows, shaders, layouts.
        // An unknown name opens the normal launcher. With the launcher already open, switches picker.
        function pick(name: string): void {
            const known = Pickers.get(name) !== null;
            const here = IslandController.mode === IslandState.launcher && IslandController.screen === IslandController.focusedScreen;
            if (here && !known && LauncherState.provider !== "")
                IslandController.close();
            LauncherState.provider = known ? name : "";
            if (IslandController.mode !== IslandState.launcher || IslandController.screen !== IslandController.focusedScreen)
                IslandController.open(IslandState.launcher);
            else
                LauncherState.query = "";
        }
    }

    // Test/diagnostic hooks (read-only or harmless): qs ipc call island-debug <function>
    IpcHandler {
        target: "island-debug"

        // Removes from the history the notifications of one app (test cleanup); returns how many.
        function dismissApp(app: string): int {
            const list = Notifications.list.filter(n => n.appName === app);
            for (const n of list)
                Notifications.dismiss(n);
            return list.length;
        }

        // Opens a button's right-click menu at (x, y) on the focused screen (services/Menus.qml);
        // "" closes it. Returns the labels of its items.
        function menu(id: string, x: int, y: int): string {
            IslandController.menuScreen = IslandController.focusedScreen;
            IslandController.menuAt = Qt.point(x, y);
            IslandController.menu = id;
            return Menus.items(id).map(i => i.section ?? i.label).join(" | ");
        }
        // Runs item n (counting headings) of an open menu's list.
        function menuRun(id: string, n: int): string {
            const it = Menus.items(id)[n];
            if (!it || !it.action)
                return "none";
            it.action();
            return it.label;
        }

        // Sets the power profile the way the battery page does (0 saver, 1 balanced, 2 performance);
        // returns the one now active.
        function powerProfile(p: int): string {
            Battery.setProfile(p);
            return Battery.profileName;
        }

        // Opens the calendar and the first editable event on a day (YYYY-MM-DD) in the edit form
        // (only loads it; nothing is saved). Returns its title or "none".
        function calendarEditFirst(day: string): string {
            const d = Calendar.parseDate(day, true);
            const e = Calendar.eventsOn(d).find(x => Calendar.editable(x));
            if (!e)
                return "none";
            if (IslandController.mode !== IslandState.calendar)
                IslandController.open(IslandState.calendar);
            Qt.callLater(() => Calendar.editRequest = e);
            return e.title;
        }

        // Checks for updates now (the icon updates when done).
        function updatesRefresh(): void {
            Updates.refresh();
        }

        // Shows a fake Wi-Fi/Bluetooth request (JSON as scripts/agents.py prints it, e.g.
        // {"type":"confirm","id":9999,"name":"Test","code":"123456"}); its answer goes to the agent,
        // which ignores unknown ids.
        function agentRequest(json: string): void {
            Agents._receive(json);
        }
        // The Wi-Fi/Bluetooth requests waiting, as JSON.
        function agentQueue(): string {
            return JSON.stringify(Agents.queue);
        }

        // Runs a button of the screenshot preview: copy, save, edit, discard.
        function screenshotAction(name: string): string {
            if (!["copy", "save", "edit", "discard"].includes(name))
                return "unknown";
            Screenshot[name]();
            return Screenshot.savedPath || Screenshot.file || "done";
        }

        // The values the login screen (SDDM) gets from the island, as JSON.
        function sddmValues(): string {
            return JSON.stringify(SddmTheme.values);
        }

        // Pretends the pointer is over the island of the focused screen (tests without a mouse).
        function hover(on: bool): void {
            IslandController.forceHover = on;
        }
        // "registered" if the island is the session's polkit agent.
        function polkit(): string {
            return Polkit.registered ? "registered" : "not registered";
        }
        // The latest notifications in the history (app · title · icon).
        function recentNotifications(): string {
            return Notifications.list.slice(0, 10).map(n => `${n.appName} · ${n.summary} · ${n.appIcon}`).join("\n");
        }
        // Control center: "page=<page> sliding=0|1 height=<px> wifi=… networks=<n>
        // bluetooth=… devices=<n> sinks=<n> sources=<n> media=0|1 notifications=<n>", or "closed".
        function ccState(): string {
            const m = IslandController.mode;
            return m === IslandState.controlCenter || IslandState.subviews.includes(m) ? ControlCenterState.status : "closed";
        }
        // Launcher/picker: "<mode> <result count> <selected title>" (e.g. "apps 3 Firefox",
        // "pick:windows 4 ~"), or "closed".
        function launcherState(): string {
            return IslandController.mode === IslandState.launcher ? LauncherState.status : "closed";
        }
        // Calendar: the calendars list as JSON; add the clipboard's link; rename; set a colour.
        function calendars(): string {
            return JSON.stringify(Calendar.calendars);
        }
        function calendarAddFromClipboard(name: string): void {
            Calendar.addFromClipboard(name);
        }
        function calendarRename(index: int, name: string): void {
            Calendar.rename(index, name);
        }
        function calendarSetColor(index: int, color: string): void {
            Calendar.setColor(index, color);
        }
        // Runs a status icon's click (Shortcuts.status; button 1 = left, 4 = middle) or a shortcut
        // button (Shortcuts.run), exactly as a click would.
        function statusClick(id: string, button: int): void {
            Shortcuts.status(id, button);
        }
        function shortcut(id: string): void {
            Shortcuts.run(id);
        }
        // Shows the hint of an icon/shortcut `id` at window position x, y on the focused screen
        // ("" hides it), as hovering would.
        function hint(id: string, x: int, y: int): void {
            IslandController.hintScreen = IslandController.focusedScreen;
            IslandController.hintAt = Qt.point(x, y);
            IslandController.hint = id;
        }
        // Plugins that loaded, and the ones that did not, with the reason (services/Plugins.qml).
        function plugins(): string {
            return JSON.stringify({
                "loaded": Plugins.names,
                "failed": Plugins.failures
            });
        }
        // Current Prefs overrides as JSON (services/Prefs.qml).
        function prefs(): string {
            return JSON.stringify(Prefs.values);
        }
        // Reloads a picker's data, as opening it does (asynchronous: call pickItems a moment later).
        function pickRefresh(name: string): string {
            const p = Pickers.get(name);
            if (!p)
                return "unknown picker";
            p.refresh();
            return "refreshing";
        }
        // A picker's entries for a query, one per line: "<index>\t<key>\t<title>\t<badge>".
        function pickItems(name: string, query: string): string {
            const p = Pickers.get(name);
            return p ? p.items(query).map((it, i) => `${i}\t${it.key ?? ""}\t${it.title ?? ""}\t${it.badge ?? ""}`).join("\n") : "unknown picker";
        }
        // Activates entry <index> of pickItems(name, query), as Enter would. Changes real state:
        // the bind tests restore it afterwards.
        function pickActivate(name: string, query: string, index: int): string {
            const p = Pickers.get(name);
            const it = p ? p.items(query)[index] : undefined;
            if (!it)
                return "no such entry";
            p.activate(it);
            return `activated ${it.key ?? it.title}`;
        }
    }
}
