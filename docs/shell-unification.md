# One Quickshell configuration instead of two

Status: plan, 2026-10-20. Nothing here is built yet. Numbers are from `git ls-files`, `wc`, `difflib` and a comparison
of declared properties, functions and signals, on `origin/main` (`19625ee2`).

## Why

hyde-lite ships two Quickshell configurations, `Configs/.config/quickshell` (the HyDE-style shell with the bar) and
`Configs/.config/morphing-island` (the island). They are deployed, launched and addressed separately
(`qs` against `qs -p ~/.config/morphing-island`), and a file used by both exists twice.

| | files | QML files | QML lines |
|---|---|---|---|
| `quickshell` (bar shell) | 123 | 117 | 13 479 |
| `morphing-island` | 196 | 186 | 27 337 |

53 file names exist in both. Of those, **26 are identical or differ by a few lines** (similarity 0.95 to 1.00: `PickWorkflows`,
`PickShaders`, `PickPalette`, `PickLayouts`, `PamText`, `Fuzzy`, `HydeLuaPicker`, `PickHydeThemes`, `Hyde`, `PickHyprlock`,
`PickWallbash`, `PickGames`, `PickFiles`, `PickWindows`, `PickBookmarks`, `PickEmoji`, `PickGlyph`, `PickWeb`,
`PickQuickApps`, `Launch`, `Keybinds`, `PickMenu`, `PickerStore`, `pick_file.py`, `ical_events.py`), about 3 000 lines
copied by hand. `tools/tests/test_mirrored_files.py` only keeps two of them from drifting. Another 15 services
(`Apps`, `Audio`, `Battery`, `Bluetooth`, `Brightness`, `Calculator`, `Clipboard`, `Lock`, `Media`, `Network`,
`NightLight`, `SysInfo`, `Prefs`, `Theme`, `Osd`) have diverged: each side declares names the other lacks (for
`Audio`, 9 on the bar side and 17 on the island side, 15 in common), but none of the bar-only names is a
different behaviour: they are icon helpers and small functions that a union of the two covers.

## Target

One configuration root, `Configs/.config/quickshell`, started by one `qs`, with the code that both UIs use in one place:

```
quickshell/
  shell.qml          picks the UI from ~/.local/state/quickshell/ui ("island" or "bar") and loads it
  common/            qs.common.*   services, pickers, scripts and widgets used by both
  island/            qs.island.*   the island's core, components, config, theme, icons and login theme
  bar/               qs.bar.*      the bar's modules and components
```

- `shell.qml` holds a `Loader` whose source follows the state file, so `island on|off|toggle` writes the file and the
  UI swaps inside one process (no second systemd unit, no `qs -p`). Only the active UI is instantiated; a singleton
  in `common/` is created once, when first used.
- Each UI's current root file becomes a component (`ShellRoot` -> `Scope`).
- IPC targets keep their names; `qs ipc call island ...` and `qs ipc call launcher ...` address the one process.

## Order (each step is its own pull request and leaves both UIs working)

1. **Move, no logic change.** `git mv` the two trees under the new root, rewrite `import qs.<dir>` to
   `qs.island.<dir>` / `qs.bar.<dir>`, add the root `shell.qml`, point `island`, `island.lua`, the dots, `tools/qml-lint.sh`,
   the tests and the docs at the new paths. Check: `tools/check.sh`, qmllint counts do not grow, each UI loads in a
   nested Hyprland without an error in the log.
2. **Share the identical files.** The 26 above go to `common/` once, both UIs import `qs.common.*`, the mirrored-file
   test goes (there is nothing left to mirror).
3. **Merge the diverged services**, a few per pull request, taking the union of the two APIs and keeping both UIs'
   callers unchanged: `Audio`, `Network`, `Bluetooth`, `Battery`, `Brightness`, `Media`, `Lock`, `NightLight`,
   `Clipboard`, `Calculator`, `Apps`, `SysInfo`, then `Osd`.
4. **Prefs and Theme.** One preferences file and one theme singleton (matugen is the only colour source), instead of
   the island's `prefs.json` with a schema beside the bar's `by-shell` state.
5. **Then look at the bar again.** With the services and pickers shared, what is left of `bar/` is its own UI
   (about the size of the island's `core/` plus `components/`). If it still cannot reuse the island's widgets,
   the waybar-style bar leaves this repository and becomes an optional install from its own repository.

## What this does not decide

- The bar UI and the island UI stay two designs until step 5. Sharing their widgets is not assumed.
- On the owner's machine both shells are links into the private dotfiles repository. Until that repository is
  re-synced, nothing changes there.
- Per-shell state keyed by Quickshell's shell id (the bar's `by-shell/<id>/prefs.json`) moves when the config path
  moves; step 4 migrates it.

## How it is tested

QML has lint (`tools/qml-lint.sh`, a baseline that may not grow) and a parse check, but no behavioural tests, and the
cloud cannot show a screen. Each step is checked by loading the configuration in a nested Hyprland
(`Hyprland -c minimal.lua` inside the session, `WAYLAND_DISPLAY=wayland-N qs -p ...`) and reading Quickshell's
log: "Configuration Loaded" with no `ERROR`. On 2026-10-20 the bar shell loaded that way with no error. What this does
not prove is how a window looks; the owner looks at the screen after each step.
