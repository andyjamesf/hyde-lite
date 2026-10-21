# Morphing Island: feature inventory

PLAN 4.1, decision D2: **every island feature is kept**; nothing is dropped. This table is the base for the
weight audit (PLAN 6.1) and for 4.2 (making each feature switchable). It was produced by assigning every
`.qml`, `.py`, `.js` and `.sh` file under `Configs/.config/quickshell/island/` to one feature and counting
lines, so the sizes are measured, but the grouping is a judgement: a file shared by several features sits
with the one that owns it (the shared core is listed last).

Command dependencies are the programs named as string literals in a feature's files, found by a text search.
They are a lower bound: a program started through a variable or a script would be missed. `hyprctl` and
`hyde-shell` come with Hyprland and HyDE and are not extra packages. "Quickshell modules" are the
`Quickshell.Services.*` / `Networking` / `Bluetooth` imports the feature needs; they ship with the
`quickshell` package.

| Feature | Files | Lines | Programs it starts | Quickshell modules |
|---|---|---|---|---|
| Clock pill, expanded bar, workspaces, status pill | 0 | 0 | - | - |
| Notifications (popups, history, peace mode) | 0 | 0 | - | - |
| OSD (volume, mic, brightness) | 0 | 0 | - | - |
| Launcher, calculator, keybindings, windows, files, web | 0 | 0 | - | - |
| Clipboard | 0 | 0 | - | - |
| HyDE menus and pickers (emoji, glyph, bookmarks, quick apps, games, wallbash, animations, hyprlock, workflows, shaders, layouts) | 0 | 0 | - | - |
| Control center (Wi-Fi, Bluetooth, sound, battery pages) | 0 | 0 | - | - |
| Media | 0 | 0 | - | - |
| Themes, wallpapers, palette pickers | 0 | 0 | - | - |
| Settings | 0 | 0 | - | - |
| Power menu | 0 | 0 | - | - |
| Polkit prompt | 0 | 0 | - | - |
| Lock screen | 0 | 0 | - | - |
| Calendar and Google Calendar | 0 | 0 | - | - |
| AI usage and agents | 0 | 0 | - | - |
| Weather | 0 | 0 | - | - |
| System stats | 0 | 0 | - | - |
| Screenshot | 0 | 0 | - | - |
| Notepad | 0 | 0 | - | - |
| Overview | 0 | 0 | - | - |
| Plugins | 0 | 0 | - | - |
| SDDM login theme | 0 | 0 | - | - |
| Shortcuts, updates, errors | 0 | 0 | - | - |

| Shared core (island, spring, state), theme, icons, base widgets, `shell.qml`, services used by several features | 43 | 4379 | - | - |

Total: 185 files, 27,569 lines (the SDDM theme has its own copies of three core files, counted under
"SDDM login theme").

## Reading it

- The largest features are the control center (3,358 lines), the calendar with Google Calendar (2,868) and
  the launcher with its sub-pickers (2,629). Together with the HyDE menus and the theme/wallpaper pickers
  they are 12,382 of the 27,569 lines (45%).
- Features that need something beyond HyDE, Hyprland and the `quickshell` package: Calendar (`python3`,
  `wl-clipboard`), AI usage and agents (`python3`, the `claude` / `codex` command-line tools if the owner uses them),
  Weather (`curl`), System stats (`python3`), the SDDM theme (`sudo`, ImageMagick), Clipboard (`cliphist`),
  OSD (`brightnessctl`), Games picker (`steam`, `lutris`, only if installed). The installer (PLAN 5.1) must
  list these.
- Nothing here was run; no feature was started on a screen.

## For 4.2

The cheapest switch is one boolean per feature in the island's own config (`config/*.qml` already has a
file per feature) that stops its service from loading and hides its entry points (key binds, menu items,
status icons). A feature that is off should cost no process and no timer. Which features are on by default
is then a preset, not code.

## NOT TESTED

Counts come from the working tree (`wc -l`-style, per file); the program lists from text search; nothing was
run.
