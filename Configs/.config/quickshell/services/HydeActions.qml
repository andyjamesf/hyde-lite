pragma Singleton
import Quickshell

// HyDE actions (the same entries and commands as HyDE's Waybar menus:
// ~/.local/share/waybar/menus/*.xml + the modules' "menu-actions"), except that the "Select …"
// entries open the launcher's pickers (pickers/) instead of rofi. Format for MenuPopup:
// { label, cmd } | { label, items: [...] } | { sep: true }.
Singleton {
    readonly property var hyprsunset: [
        {
            "label": "Toggle",
            "cmd": "hyde-shell hyprsunset -t -P waybar:19"
        },
        {
            "sep": true
        },
        {
            "label": "  Temperature",
            "items": [
                {
                    "label": "󰨙  Default",
                    "cmd": "hyde-shell hyprsunset --cm temp -s identity -P waybar:19"
                },
                {
                    "sep": true
                },
                {
                    "label": "Warm Candle",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 3000 -P waybar:19"
                },
                {
                    "label": "Soft Warm",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 4000 -P waybar:19"
                },
                {
                    "label": "Neutral White",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 5000 -P waybar:19"
                },
                {
                    "label": "Daylight",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 6500 -P waybar:19"
                },
                {
                    "label": "Cool White",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 7500 -P waybar:19"
                },
                {
                    "label": "Bright Blue",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 9000 -P waybar:19"
                },
                {
                    "label": "Arctic Blue",
                    "cmd": "hyde-shell hyprsunset --cm temp -s 10000 -P waybar:19"
                }
            ]
        },
        {
            "label": "󰃝  Gamma",
            "items": [
                {
                    "label": "Default (100)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 100 -P waybar:19"
                },
                {
                    "label": "Slightly Dim (90)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 90 -P waybar:19"
                },
                {
                    "label": "Dimmer (80)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 80 -P waybar:19"
                },
                {
                    "label": "Quite Dim (70)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 70 -P waybar:19"
                },
                {
                    "label": "Dim (60)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 60 -P waybar:19"
                },
                {
                    "label": "Very Dim (50)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 50 -P waybar:19"
                },
                {
                    "label": "Extra Dim (40)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 40 -P waybar:19"
                },
                {
                    "label": "Super Dim (30)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 30 -P waybar:19"
                },
                {
                    "label": "Ultra Dim (20)",
                    "cmd": "hyde-shell hyprsunset --cm gamma -s 20 -P waybar:19"
                }
            ]
        }
    ]

    readonly property var hyde: [
        {
            "label": "󰗘  Animations",
            "items": [
                {
                    "label": "  Select Animation",
                    "cmd": "qs ipc call launcher pick animations"
                }
            ]
        },
        {
            "label": "󰸉  Wallpaper",
            "items": [
                {
                    "label": "  Select Wallpaper",
                    "cmd": "qs ipc call launcher pick wallpapers"
                },
                {
                    "label": "  Next Wallpaper",
                    "cmd": "hyde-shell app -t scope -- wallpaper.sh --next --global"
                },
                {
                    "label": "  Previous Wallpaper",
                    "cmd": "hyde-shell app -t scope -- wallpaper.sh --previous --global"
                },
                {
                    "label": "  Random Wallpaper",
                    "cmd": "hyde-shell app -t scope -- wallpaper.sh --random --global"
                }
            ]
        },
        {
            "label": "󰏘  Theme",
            "items": [
                {
                    "label": "󰏘  Select Theme",
                    "cmd": "qs ipc call launcher pick themes"
                },
                {
                    "label": "  Next Theme",
                    "cmd": "hyde-shell app -t scope -- theme.switch.sh -n"
                },
                {
                    "label": "  Previous Theme",
                    "cmd": "hyde-shell app -t scope -- theme.switch.sh -p"
                },
                {
                    "label": "  More Themes",
                    "cmd": "hyde-shell app -T -- hydectl theme import"
                }
            ]
        },
        {
            "label": "  Layouts",
            "items": [
                {
                    "label": "  Select Layout",
                    "cmd": "qs ipc call launcher pick layouts"
                }
            ]
        },
        {
            "label": "  Workflows",
            "items": [
                {
                    "label": "  Select Workflow",
                    "cmd": "qs ipc call launcher pick workflows"
                }
            ]
        },
        {
            "label": "  Lockscreen",
            "items": [
                {
                    "label": "  Select Lockscreen",
                    "cmd": "qs ipc call launcher pick hyprlock"
                }
            ]
        },
        {
            "label": "󰛨  Eye Care",
            "items": [
                {
                    "label": "Toggle",
                    "cmd": "hyde-shell hyprsunset -t -P waybar:19"
                },
                {
                    "sep": true
                },
                {
                    "label": "  Temperature",
                    "items": [
                        {
                            "label": "󰨙  Default",
                            "cmd": "hyde-shell hyprsunset --cm temp -s identity -P waybar:19"
                        },
                        {
                            "sep": true
                        },
                        {
                            "label": "Warm Candle",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 3000 -P waybar:19"
                        },
                        {
                            "label": "Soft Warm",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 4000 -P waybar:19"
                        },
                        {
                            "label": "Neutral White",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 5000 -P waybar:19"
                        },
                        {
                            "label": "Daylight",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 6500 -P waybar:19"
                        },
                        {
                            "label": "Cool White",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 7500 -P waybar:19"
                        },
                        {
                            "label": "Bright Blue",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 9000 -P waybar:19"
                        },
                        {
                            "label": "Arctic Blue",
                            "cmd": "hyde-shell hyprsunset --cm temp -s 10000 -P waybar:19"
                        }
                    ]
                },
                {
                    "label": "󰃝  Gamma",
                    "items": [
                        {
                            "label": "Default (100)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 100 -P waybar:19"
                        },
                        {
                            "label": "Slightly Dim (90)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 90 -P waybar:19"
                        },
                        {
                            "label": "Dimmer (80)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 80 -P waybar:19"
                        },
                        {
                            "label": "Quite Dim (70)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 70 -P waybar:19"
                        },
                        {
                            "label": "Dim (60)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 60 -P waybar:19"
                        },
                        {
                            "label": "Very Dim (50)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 50 -P waybar:19"
                        },
                        {
                            "label": "Extra Dim (40)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 40 -P waybar:19"
                        },
                        {
                            "label": "Super Dim (30)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 30 -P waybar:19"
                        },
                        {
                            "label": "Ultra Dim (20)",
                            "cmd": "hyde-shell hyprsunset --cm gamma -s 20 -P waybar:19"
                        }
                    ]
                }
            ]
        },
        {
            "label": "  Shaders",
            "cmd": "qs ipc call launcher pick shaders"
        },
        {
            "sep": true
        },
        {
            "label": "󰑓  Reload Bar",
            "cmd": "qs ipc call shell reload"
        },
        {
            "label": "  Keybinds",
            "cmd": "hyde-shell keybinds_hint"
        },
        {
            "label": "  About",
            "cmd": "xdg-open https://hydeproject.pages.dev"
        }
    ]

    readonly property var power: [
        {
            "label": "󰍁  Lock",
            "cmd": "loginctl lock-session"
        },
        {
            "label": "󰍃  Logout",
            "cmd": "hyprctl dispatch 'hl.dsp.exit()'"
        },
        {
            "label": "󰒲  Suspend",
            "cmd": "systemctl suspend"
        },
        {
            "label": "󰜗  Hibernate",
            "cmd": "systemctl hibernate"
        },
        {
            "sep": true
        },
        {
            "label": "󰜉  Reboot",
            "items": [
                {
                    "label": "󰜉  Reboot",
                    "cmd": "systemctl reboot"
                },
                {
                    "label": "󰮫  Reboot to UEFI",
                    "cmd": "systemctl reboot --firmware-setup"
                }
            ]
        },
        {
            "label": "󰐥  Shutdown",
            "items": [
                {
                    "label": "󰐥  Shutdown Now",
                    "cmd": "shutdown now"
                },
                {
                    "label": "󰐥  Shutdown (wait)",
                    "cmd": "systemctl poweroff"
                }
            ]
        }
    ]

    readonly property var clipboard: [
        {
            "label": "󰓎  Favorites",
            "cmd": "hyde-shell cliphist --favorites"
        },
        {
            "label": "󰋚  History",
            "cmd": "hyde-shell cliphist --copy"
        },
        {
            "label": "󰆴  Delete History",
            "cmd": "hyde-shell cliphist --delete"
        },
        {
            "label": "󰎟  Clear History",
            "cmd": "hyde-shell cliphist --wipe"
        },
        {
            "label": "󱕣  Manage Favorites",
            "cmd": "hyde-shell cliphist 'Manage Favorites'"
        }
    ]
}
