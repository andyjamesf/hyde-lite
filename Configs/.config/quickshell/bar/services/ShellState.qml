pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shell state shared by all screens.
Singleton {
    id: root

    property bool barHidden: false

    // Windows that belong to the panel's focus grab without being the panel (the notification popups): a
    // click on one of them must not count as a click outside and shut the control center.
    property var grabExtras: []
    function addGrabExtra(w) {
        if (!grabExtras.includes(w))
            grabExtras = grabExtras.concat([w]);
    }
    function removeGrabExtra(w) {
        grabExtras = grabExtras.filter(x => x !== w);
    }

    // Control center: which screen it is open on, and which page ("" = main, "wifi", "bluetooth", "audio").
    property bool controlCenterOpen: false
    property string controlCenterScreen: ""
    property string controlCenterPage: ""
    // The tab under the header: "home" (toggles, player, notifications) or one of the launcher's
    // ("apps", "clipboard", "keys"). Opening the panel from the bar's button always starts at home.
    property string controlCenterTab: "home"
    // Launcher modes that are tabs of the panel (config.json controlCenter.tabs; off: the old window).
    readonly property var launcherTabs: ({
            apps: "apps",
            calc: "apps",
            clipboard: "clipboard",
            keys: "keys"
        })
    // The tab a launcher mode belongs to: the pickers ("pick:<name>") live in "more".
    function tabOfLauncherMode(mode) {
        const m = mode ?? "apps";
        return m.startsWith("pick:") ? "more" : launcherTabs[m];
    }
    // An outside click closes the panel (focus grab) and, if it was on the bar button, the same click
    // would open it again; this timestamp allows ignoring that second effect.
    property real controlCenterClosedAt: 0

    // Request to open a bar popout by name (IPC/keybindings): the bar on the focused screen opens it.
    property string requestedPopout: ""
    // The bar widget with the open popout (there can only be one).
    property var popoutOwner: null
    property string requestedPopoutScreen: ""

    // Bar menus and tooltips requested over IPC (for testing without a mouse): "name" or "name:i:j" opens
    // the widget's menu and enters submenus i, j…; empty closes it.
    property string requestedMenu: ""
    property string requestedTooltip: ""

    function requestMenu(spec) {
        requestedPopoutScreen = Hyprland.focusedMonitor?.name ?? "";
        requestedMenu = "";
        requestedMenu = spec;
    }

    function requestTooltip(name) {
        requestedPopoutScreen = Hyprland.focusedMonitor?.name ?? "";
        requestedTooltip = name;
    }

    function requestPopout(name) {
        requestedPopoutScreen = Hyprland.focusedMonitor?.name ?? "";
        requestedPopout = "";
        requestedPopout = name;
    }

    // Launcher: which screen it is open on and in which mode ("apps", "clipboard" or "calc").
    // Picture editor: the chosen image (empty = closed) and the screen it opens on.
    property string avatarSource: ""
    property string avatarScreen: ""

    property bool launcherOpen: false
    property string launcherScreen: ""
    property string launcherMode: "apps"
    property bool powerMenuOpen: false
    property string powerMenuScreen: ""
    // Quick notes (modules/notes).
    property bool notesOpen: false
    property string notesScreen: ""
    // "edit" (the page) or "list" (every note, as cards).
    property string notesMode: "edit"
    // Bar layout editor (modules/barbuilder).
    property bool barEditorOpen: false
    property string barEditorScreen: ""

    function toggleLauncher(mode, screen) {
        const tab = Config.controlCenter.tabs ? tabOfLauncherMode(mode) : undefined;
        if (tab !== undefined) {
            launcherOpen = false;
            powerMenuOpen = false;
            // A picker is told apart from the others by its mode: the same key closes it.
            if (tab === "more") {
                if (controlCenterOpen && controlCenterTab === "more" && controlCenterPage === "" && launcherMode === mode) {
                    closeControlCenter();
                    return;
                }
                launcherMode = mode;
                openControlCenter("", "more", screen);
                return;
            }
            toggleControlCenterTab(tab, screen);
            return;
        }
        if (launcherOpen && launcherMode === (mode ?? "apps")) {
            launcherOpen = false;
            return;
        }
        launcherScreen = screen || (Hyprland.focusedMonitor?.name ?? "");
        launcherMode = mode ?? "apps";
        powerMenuOpen = false;
        closeControlCenter();
        launcherOpen = true;
    }

    function toggleBarEditor() {
        if (barEditorOpen) {
            barEditorOpen = false;
            return;
        }
        barEditorScreen = Hyprland.focusedMonitor?.name ?? "";
        launcherOpen = false;
        powerMenuOpen = false;
        closeControlCenter();
        barEditorOpen = true;
    }

    function togglePowerMenu() {
        if (Config.controlCenter.tabs) {
            powerMenuOpen = false;
            launcherOpen = false;
            toggleControlCenterTab("power");
            return;
        }
        if (powerMenuOpen) {
            powerMenuOpen = false;
            return;
        }
        powerMenuScreen = Hyprland.focusedMonitor?.name ?? "";
        launcherOpen = false;
        closeControlCenter();
        powerMenuOpen = true;
    }

    // The same key closes the window it opened; the other mode's key switches to that mode.
    function toggleNotes(mode) {
        const m = mode ?? "edit";
        if (Config.controlCenter.tabs) {
            if (controlCenterOpen && controlCenterTab === "notes" && controlCenterPage === "" && notesMode === m) {
                closeControlCenter();
                return;
            }
            notesOpen = false;
            launcherOpen = false;
            powerMenuOpen = false;
            notesMode = m;
            openControlCenter("", "notes");
            return;
        }
        if (notesOpen && notesMode === m) {
            notesOpen = false;
            return;
        }
        if (!notesOpen) {
            notesScreen = Hyprland.focusedMonitor?.name ?? "";
            launcherOpen = false;
            powerMenuOpen = false;
            closeControlCenter();
        }
        notesMode = m;
        notesOpen = true;
    }

    // The same key closes the panel when it already shows that tab.
    function toggleControlCenterTab(tab, screen) {
        if (controlCenterOpen && controlCenterTab === tab && controlCenterPage === "") {
            closeControlCenter();
            return;
        }
        powerMenuOpen = false;
        openControlCenter("", tab, screen);
    }

    // Bar widgets whose panel is a page or a tab of the control centre: the clock's calendar, the
    // audio, network, Bluetooth and battery pages; the player and the brightness slider are on Home.
    readonly property var popoutRoutes: ({
            calendar: {
                tab: "calendar"
            },
            audio: {
                page: "audio"
            },
            bluetooth: {
                page: "bluetooth"
            },
            network: {
                page: "wifi"
            },
            battery: {
                page: "battery"
            },
            media: {},
            brightness: {}
        })

    // Opens the control centre where a bar widget's popout would have been; false if it has no route
    // (or the tabs are off), and the widget opens its own popout.
    function routePopout(name) {
        const r = Config.controlCenter.tabs ? popoutRoutes[name] : undefined;
        if (r === undefined)
            return false;
        // The same widget again closes the panel.
        if (controlCenterOpen && controlCenterPage === (r.page ?? "") && controlCenterTab === (r.tab ?? "home")) {
            closeControlCenter();
            return true;
        }
        if (!controlCenterOpen && Date.now() - controlCenterClosedAt < 300)
            return true;
        launcherOpen = false;
        powerMenuOpen = false;
        openControlCenter(r.page ?? "", r.tab ?? "home");
        return true;
    }

    function openControlCenter(page, tab, screen) {
        controlCenterScreen = screen || (Hyprland.focusedMonitor?.name ?? "");
        controlCenterPage = page ?? "";
        controlCenterTab = tab ?? "home";
        controlCenterOpen = true;
    }

    function closeControlCenter() {
        if (controlCenterOpen)
            controlCenterClosedAt = Date.now();
        controlCenterOpen = false;
    }

    function toggleControlCenter(page) {
        if (!controlCenterOpen && Date.now() - controlCenterClosedAt < 300)
            return;
        if (controlCenterOpen && (page ?? "") === controlCenterPage)
            closeControlCenter();
        else
            openControlCenter(page);
    }
}
