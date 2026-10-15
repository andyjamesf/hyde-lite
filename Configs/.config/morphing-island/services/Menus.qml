pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.core

// Right-click menus of the island's buttons (status pill, shortcut buttons, control center tiles):
// the quick choices each one has. items(id) is read again while the menu is open, so ticks follow
// the state. An item: { label, detail, checked (true/false, or undefined = no tick), action };
// { section: "Title" } is a heading. Drawn by core/IslandWindow.qml (IslandController.menu*).
Singleton {
    // Buttons that have a menu.
    function has(id) {
        return items(id).length > 0;
    }

    function items(id) {
        switch (id) {
        case "nightlight":
            return nightLight();
        case "profile":
        case "battery":
        case "batterypage":
            return profiles();
        case "volume":
        case "sound":
            return outputs();
        case "mic":
            return inputs();
        case "wifi":
            return wifi();
        case "bluetooth":
            return bluetooth();
        case "caffeine":
            return caffeine();
        case "notifications":
        case "peace":
            return notifications();
        case "screenshot":
            return screenshot();
        case "wallpaper":
        case "nextwallpaper":
            return wallpaper();
        case "power":
            return power();
        case "updates":
            return [
                {
                    label: "Update now…",
                    action: () => Updates.open()
                },
                {
                    label: "Check again",
                    action: () => Updates.refresh()
                }
            ];
        case "ai":
            return [
                {
                    label: "Refresh",
                    action: () => AiUsage.refresh()
                }
            ];
        }
        return [];
    }

    function nightLight() {
        const on = NightLight.active, t = NightLight.currentTemperature;
        const temps = [
            [5500, "Slightly warm"],
            [4500, "Warm"],
            [4000, "Warmer"],
            [3500, "Very warm"],
            [3000, "Evening"],
            [2500, "Late night"]
        ];
        return [
            {
                section: "Colour temperature"
            },
            {
                label: "Off",
                checked: !on,
                action: () => NightLight.set(false)
            }
        ].concat(temps.map(([k, name]) => ({
                    label: name,
                    detail: `${k} K`,
                    checked: on && Math.abs(t - k) < 250,
                    action: () => NightLight.setTemperature(k)
                })));
    }

    function profiles() {
        const list = [
            {
                section: "Power profile"
            }
        ];
        for (let p = 0; p < (Battery.hasPerformance ? 3 : 2); p++) {
            const v = p;
            list.push({
                label: Battery.profileNames[v],
                checked: Battery.profile === v,
                action: () => Battery.setProfile(v)
            });
        }
        list.push({
            label: "Battery…",
            action: () => IslandController.open(IslandState.battery)
        });
        return list;
    }

    function outputs() {
        return [
            {
                section: "Output"
            }
        ].concat((Audio.sinks ?? []).map(s => ({
                    label: s.name,
                    checked: s.isDefault,
                    action: () => Audio.setDefaultSink(s.key)
                }))).concat([
            {
                label: Audio.muted ? "Unmute" : "Mute",
                action: () => Audio.toggleMute()
            },
            {
                label: "Sound settings…",
                action: () => IslandController.open(IslandState.audio)
            }
        ]);
    }

    function inputs() {
        return [
            {
                section: "Microphone"
            }
        ].concat((Audio.sources ?? []).map(s => ({
                    label: s.name,
                    checked: s.isDefault,
                    action: () => Audio.setDefaultSource(s.key)
                }))).concat([
            {
                label: Audio.micMuted ? "Turn on" : "Turn off",
                action: () => Audio.toggleMicMute()
            }
        ]);
    }

    function wifi() {
        const list = [
            {
                label: "Wi-Fi",
                checked: Network.wifiEnabled,
                action: () => Network.setWifiEnabled(!Network.wifiEnabled)
            }
        ];
        const nets = Network.wifiEnabled ? (Network.networks ?? []).filter(n => n.connected || n.known).slice(0, 6) : [];
        if (nets.length > 0)
            list.push({
                section: "Saved networks"
            });
        for (const n of nets) {
            const net = n;
            list.push({
                label: net.name,
                detail: net.connected ? "Connected" : "",
                checked: net.connected,
                action: () => net.connected ? Network.disconnect() : Network.connect(net.key)
            });
        }
        list.push({
            label: "All networks…",
            action: () => IslandController.open(IslandState.wifi)
        });
        return list;
    }

    function bluetooth() {
        if (!Bluetooth.available)
            return [];
        const list = [
            {
                label: "Bluetooth",
                checked: Bluetooth.enabled,
                action: () => Bluetooth.setEnabled(!Bluetooth.enabled)
            }
        ];
        const devs = Bluetooth.enabled ? (Bluetooth.devices ?? []).filter(d => d.paired).slice(0, 6) : [];
        if (devs.length > 0)
            list.push({
                section: "Devices"
            });
        for (const d of devs) {
            const dev = d;
            list.push({
                label: dev.name,
                detail: dev.connected ? (dev.battery >= 0 ? `${dev.battery}%` : "Connected") : "",
                checked: dev.connected,
                action: () => dev.connected ? Bluetooth.disconnectDevice(dev.key) : Bluetooth.connectDevice(dev.key)
            });
        }
        list.push({
            label: "All devices…",
            action: () => IslandController.open(IslandState.bluetooth)
        });
        return list;
    }

    function caffeine() {
        const timed = Caffeine.active && Caffeine.until > 0;
        return [
            {
                section: Caffeine.remaining !== "" ? `Caffeine · ${Caffeine.remaining}` : "Keep the screen awake"
            },
            {
                label: "Off",
                checked: !Caffeine.active,
                action: () => Caffeine.off()
            },
            {
                label: "For 30 minutes",
                action: () => Caffeine.enableFor(30)
            },
            {
                label: "For 1 hour",
                action: () => Caffeine.enableFor(60)
            },
            {
                label: "For 2 hours",
                action: () => Caffeine.enableFor(120)
            },
            {
                label: "Until turned off",
                checked: Caffeine.active && !timed,
                action: () => Caffeine.enableFor(0)
            }
        ];
    }

    function notifications() {
        return [
            {
                label: "Peace Mode",
                detail: "no popups",
                checked: Notifications.peaceMode,
                action: () => Notifications.togglePeace()
            },
            {
                label: `Clear all${Notifications.count > 0 ? ` (${Notifications.count})` : ""}`,
                action: () => Notifications.clear()
            },
            {
                label: "Notification center…",
                action: () => IslandController.open(IslandState.controlCenter)
            }
        ];
    }

    function screenshot() {
        return [
            {
                section: "Screenshot"
            },
            {
                label: "Select an area",
                action: () => Screenshot.take("area")
            },
            {
                label: "Area on a frozen screen",
                action: () => Screenshot.take("freeze")
            },
            {
                label: "This monitor",
                action: () => Screenshot.take("output")
            },
            {
                label: "All monitors",
                action: () => Screenshot.take("screen")
            }
        ];
    }

    function wallpaper() {
        return [
            {
                label: "Next wallpaper",
                action: () => Launch.run(["hyde-shell", "wallpaper", "--next"])
            },
            {
                label: "Previous wallpaper",
                action: () => Launch.run(["hyde-shell", "wallpaper", "--prev"])
            },
            {
                label: "Choose…",
                action: () => IslandController.open(IslandState.wallpaper)
            }
        ];
    }

    function power() {
        return [
            {
                label: "Lock",
                action: () => Launch.run(["loginctl", "lock-session"])
            },
            {
                label: "Suspend",
                action: () => Launch.run(["systemctl", "suspend"])
            },
            {
                label: "Log out, restart, shut down…",
                action: () => IslandController.open(IslandState.power)
            }
        ];
    }
}
