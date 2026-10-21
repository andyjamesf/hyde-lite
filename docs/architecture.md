# Architecture

How the code is laid out, where the layers leak, and what to refactor first. Counts are from a read of the
tree on 2026-10-15 (`wc`, `grep`); the shells were not run for it. Upstream HyDE (`Scripts/`,
`Configs/.local/lib/hyde`) is out of scope: see [`LITE.md`](../LITE.md).

## Shape

Neither shell is object-oriented in the textbook sense, and neither is classic MVC. Both are **QML singletons
in layers**, close to MVVM: services hold state and logic, components draw it.

| Layer | Morphing Island (`Configs/.config/quickshell/island`) | Bar (`Configs/.config/quickshell/bar`) |
|---|---|---|
| Constants | `config/`: 30 singletons, each property documented | none; `config.json` and `services/Config.qml` |
| State and logic | `services/`: 60 singletons (20 are `Pick*` pickers) | `services/`: 30; `pickers/` mixes logic and views |
| Views | `components/`: 55 files | `components/` and `modules/` (a window plus its view) |
| Controller, windows | `core/`: `IslandController`, `IslandState`, `IslandWindow`, `ModeSlot` | in `modules/` and `shell.qml` |

The island's discipline is better: none of its views start processes (every `Process` is in `services/`).
The bar shell has 14 `Process` blocks in views, 12 of them in `pickers/`.

Tooling (`tools/`, the shells' `scripts/`) is procedural Python and shell with unit tests
(`tools/tests/`, run by `tools/check.sh` and CI). QML has lint and a parse check, but no behavioural tests.

## Two shells, some shared files

Each shell is deployed on its own, so a file used by both exists twice. Those copies must not drift:
`tools/tests/test_mirrored_files.py` fails when two same-named scripts differ (today `ical_events.py`,
`pick_file.py`) or when a listed service does (`PamText.qml`). Edit one, copy it to the other.

Fifteen service names exist in both shells (Apps, Audio, Battery, Bluetooth, Brightness, Calculator, Clipboard,
Keybinds, Lock, Media, Network, NightLight, PamText, Prefs, SysInfo). Apart from `PamText` they have diverged
(from 26 to 192 changed lines each), so they are separate code that happens to share a name.

## Where the layers leak

1. **Config reads services.** `island/config/*.qml` such as `Pill`, `Clock` and `StatusPillConfig`
   call `Prefs.get(...)`, so the constants layer depends on the state layer. It is a deliberate shortcut: one
   place per setting, live from `prefs.json`. A pref must have an entry in `config/PrefsSchema.qml`
   (`tools/tests/test_prefs_schema.py` checks it).
2. **Services call the controller.** Seven island services import `qs.core`; `Shortcuts` and `Menus` call
   `IslandController.open(...)` directly.
3. **Views hold rules.** `StatusZone` decides which icon is visible; views read `Prefs` directly.
4. **God views.** `LauncherView` (1238 lines, 52 properties), `CcMainPage` (937), `CalendarView` (765) in the
   island; `Launcher.qml` (737) and `ControlCenter.qml` (707) in the bar shell.

## Refactor order (none started; each is its own small PR)

1. Keep mirrored files identical (done: the test above).
2. Split `LauncherView` and `CcMainPage` into sub-views plus a state service.
3. Replace `IslandController` calls in `Shortcuts` and `Menus` with signals, so services stop importing `qs.core`.
4. Move the icon-visibility rules from `StatusZone` into a service.
5. Move the bar shell's picker `Process` blocks into services.
6. Keep `config/` to constants and bind `Prefs` one layer above.
7. Add behavioural tests for the services (the pure parts can already be run in Node, as
   `tools/tests/test_icon_list_editor.py` does).

Each of 2 to 6 changes visual code that cannot be tried in the cloud; the owner has to look at the screen
after each one.
