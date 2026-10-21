# Quickshell shell for HyDE

The desktop shell of the HyDE Quickshell Edition: bar, notifications, OSD, launcher (apps,
clipboard, calculator, keybindings), control center, power menu and lock screen. It is one of the two UIs of the
Quickshell configuration in `~/.config/quickshell`: `qs` starts `../shell.qml`, which loads this one unless the
island is active (`island on`). HyDE launches `qs` at login through `hyde.config.start.bar`.

The features, keybindings, configuration, IPC and how to go back to Waybar/dunst/hyprlock are
documented in the repository's [`docs/`](../../../../docs/) folder (the bar layouts in `docs/bar-builder.md`).

## Layout

| Path | Contents |
|---|---|
| `shell.qml` | entry point: per-screen windows and IPC targets |
| `services/` | singletons with the logic (colors, audio, network, Bluetooth, notifications, launcher, keybindings, lock…) |
| `components/` | reusable visual pieces (buttons, sliders, cards, popouts, menus, tooltips) |
| `modules/` | bar, control center, notifications, OSD, launcher, power menu, lock screen |
| `pickers/` | the launcher's pickers, HyDE's rofi menus ported to the shell: windows, files, web, emoji, glyphs, bookmarks, games, HyDE themes, wallpapers, wallbash, animations, lock screen, workflows, shaders, layouts (`qs ipc call launcher pick <name>`; settings in `config.json` → `pickers`) |
| `config/config.json` | your settings (only what you change; defaults in `services/Config.qml`) |
| `config/layouts.json` | bar layout presets (add your own) |
| `scripts/ical_events.py` | iCal reader for the calendar (Google Calendar) |

HyDE updates overwrite the code; `config/` is only copied when missing, so your settings are kept.
Settings picked in the menus are stored in `~/.local/state/quickshell/`.

## Development

- `qs ipc call shell reload` reloads the shell (files are also watched). Do not reload while the
  screen is locked if you are on an older version of `services/Lock.qml`.
- `journalctl --user -u "hyde-*-qsbar.service"` shows the logs.
- `qs ipc call bar menu <widget[:submenu]>`, `bar tooltip <widget>` and `bar popout <name>` open
  menus, tooltips and popouts without a mouse, for testing.
- Colors, spacing, type scale and shapes come from `services/Theme.qml`; please don't hardcode
  sizes.
