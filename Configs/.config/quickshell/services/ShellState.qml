pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Shell state shared by all screens.
Singleton {
    id: root

    property bool barHidden: false
    // Read by each bar's IdleInhibitor (the inhibitor needs a window).
    property bool idleInhibited: false

    // Control center: which screen it is open on, and which page ("" = main, "wifi", "bluetooth", "audio").
    property bool controlCenterOpen: false
    property string controlCenterScreen: ""
    property string controlCenterPage: ""
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
    // Bar layout editor (modules/barbuilder).
    property bool barEditorOpen: false
    property string barEditorScreen: ""

    function toggleLauncher(mode, screen) {
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
        if (powerMenuOpen) {
            powerMenuOpen = false;
            return;
        }
        powerMenuScreen = Hyprland.focusedMonitor?.name ?? "";
        launcherOpen = false;
        closeControlCenter();
        powerMenuOpen = true;
    }

    function openControlCenter(page) {
        controlCenterScreen = Hyprland.focusedMonitor?.name ?? "";
        controlCenterPage = page ?? "";
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
