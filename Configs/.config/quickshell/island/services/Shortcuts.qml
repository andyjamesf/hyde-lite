pragma Singleton
import QtQuick
import Quickshell
import qs.island.core
// Battery is only ever read inside template literals below, which qmllint does not look
// into, so it reports this import as unused. It is not.
// qmllint disable unused-imports
import qs.shared.services
import qs.shared.pickers
// qmllint enable unused-imports

// What the status icons and the shortcut buttons of the expanded island do when clicked, and the
// hint shown when the pointer rests on them (what each one is, and its state) (components/StatusZone.qml). Kept here so every
// action can also be run and tested by IPC (`island-debug statusClick` / `shortcut`).
Singleton {
    // Hint for an icon or shortcut button: what it is, and its state now.
    function hint(id) {
        if (Plugins.has(id))
            return Plugins.hint(id);
        switch (id) {
        case "volume":
            return Audio.muted ? "Volume: muted" : `Volume: ${Math.round(Audio.volume * 100)}%`;
        case "bluetooth":
            return `Bluetooth: ${Bluetooth.summary}`;
        case "wifi":
            return Network.wired ? "Wired network" : Network.connected ? `Wi-Fi: ${Network.name}` : Network.wifiEnabled ? "Wi-Fi: not connected" : "Wi-Fi: off";
        case "caffeine":
            return Caffeine.active ? "Caffeine: on (the screen stays awake)" : "Caffeine: off";
        case "notifications":
            return Notifications.peaceMode ? "Notifications: peace mode" : Notifications.count > 0 ? `Notifications: ${Notifications.count}` : "Notifications: none";
        case "battery":
            return `Battery: ${Math.round(Battery.percent)}%${Battery.charging ? ", charging" : Battery.plugged ? ", plugged in" : ""}`;
        case "nightlight":
            return NightLight.active ? "Night light: on" : "Night light: off";
        case "screenshot":
            return "Screenshot";
        case "clipboard":
            return "Clipboard history";
        case "picker":
            return "Colour picker";
        case "wallpaper":
            return "Wallpapers";
        case "theme":
            return "Island theme";
        case "settings":
            return "Island settings";
        case "lock":
            return "Lock screen";
        case "clock":
        case "date":
            return "Calendar";
        case "mic":
        case "brightness":
        case "media":
            return IslandController.widgetHint(id);
        case "power":
            return "Power menu";
        case "detachstats":
            return "Detach: a floating window over your apps";
        case "system":
            return "System: CPU, memory, temperatures…";
        case "avatar":
            return "Change your picture";
        case "batterypage":
            return `Battery: ${Battery.profileName} profile`;
        case "nextwallpaper":
            return "Next wallpaper";
        case "hydetheme":
            return "HyDE theme";
        case "animations":
            return "Animations";
        case "keybindings":
            return "Keybindings";
        case "updates":
            return `Updates: ${Updates.count} (${Updates.summary})`;
        case "ai":
            return `AI usage\n${AiUsage.summary}`;
        case "weather":
            return Weather.current ? `${Weather.place}\n${Weather.describe(Weather.current.code)}, feels ${Math.round(Weather.current.feels)}°` : "Weather";
        }
        return "";
    }

    // Status icons: volume (middle button: mute), bluetooth, wifi, caffeine, notifications, battery,
    // power.
    function status(id, button) {
        if (id === "volume" && button === Qt.MiddleButton)
            Audio.toggleMute();
        else if (id === "volume")
            IslandController.open(IslandState.audio);
        else if (id === "bluetooth")
            IslandController.open(IslandState.bluetooth);
        else if (id === "wifi")
            IslandController.open(IslandState.wifi);
        else if (id === "caffeine")
            Caffeine.toggle();
        else if (id === "power")
            IslandController.open(IslandState.power);
        else if (id === "clock" || id === "date")
            IslandController.open(IslandState.calendar);
        else if (IslandController.widgetHandlesClick(id))
            IslandController.widgetClick(id, button);
        else if (id === "battery")
            IslandController.open(IslandState.battery);
        else if (id === "updates")
            Updates.open();
        else if (id === "weather") {
            // Fresh numbers, then the page: a click is usually "is that still true?".
            Weather.refresh();
            IslandController.open(IslandState.weather);
        } else if (id === "ai") {
            // Fresh numbers, in the AI popup (they fill in as they arrive).
            AiUsage.refresh();
            IslandController.open(IslandState.ai);
        } else if (Plugins.has(id))
            Plugins.activate(id, button);
        else
            IslandController.open(IslandState.controlCenter);
    }

    // Opens the launcher in one of the pickers (services/Pickers.qml).
    function pick(name) {
        LauncherState.provider = name;
        if (IslandController.mode !== IslandState.launcher)
            IslandController.open(IslandState.launcher);
        else
            LauncherState.query = "";
    }

    // Shortcut buttons (Expanded.extraButtons).
    function run(id) {
        // Capture tools: the island first shrinks back to the pill (and out of the picture).
        if ((id === "screenshot" || id === "picker") && IslandController.pinned)
            IslandController.togglePin();
        if (id === "nightlight")
            NightLight.toggle();
        else if (id === "screenshot")
            Screenshot.take("area");
        else if (id === "picker")
            Launch.run(["hyprpicker", "-an"]);
        else if (id === "clipboard") {
            IslandController.open(IslandState.launcher);
            LauncherState.query = ":";
        } else if (id === "wallpaper")
            IslandController.open(IslandState.wallpaper);
        else if (id === "theme")
            IslandController.open(IslandState.theme);
        else if (id === "settings")
            IslandController.open(IslandState.settings);
        else if (id === "lock")
            Launch.run(["loginctl", "lock-session"]);
        else if (id === "system")
            IslandController.open(IslandState.system);
        else if (id === "nextwallpaper")
            Launch.run(["hyde-shell", "wallpaper", "--next"]);
        else if (id === "hydetheme")
            pick("themes");
        else if (id === "animations")
            pick("animations");
        else if (id === "keybindings") {
            IslandController.open(IslandState.launcher);
            LauncherState.query = "?";
        }
        else if (id === "power")
            IslandController.open(IslandState.power);
    }
}
