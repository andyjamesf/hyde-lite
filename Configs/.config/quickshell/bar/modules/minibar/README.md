# The minimal bar

A second, slimmer bar that takes the normal one's place while it is switched on. It duplicates
nothing: it shows the **same modules** as the normal bar (`../bar/widgets/`), in the same container
(`Island`), through the same services. Putting a module on it means writing its name in a list —
no new code.

By default it reserves no space, so a window can use the whole screen and the bar floats on top
(`reserveSpace` in the settings).

## Switching it on and off

```sh
qs ipc call minibar toggle     # minimal bar <-> normal bar
qs ipc call minibar show       # switch the minimal one on
qs ipc call minibar hide       # back to the normal one
qs ipc call minibar status     # say which one is in use
```

The key is `$mod+SHIFT+B` (`Configs/.config/hypr/keybinds.lua`, `M.shell`; it does nothing while
the island is the active shell, like the bar layout keys next to it). The choice is kept in
`~/.local/state/quickshell/.../minibar.json`, so it survives `qs ipc call shell reload` and a login.

## The only file to edit

[`model/MiniBarConfig.qml`](model/MiniBarConfig.qml), commented line by line. Save it and the bar
applies the change on its own — the file is watched, nothing has to be restarted.

| Section | What it controls |
|---|---|
| 1. The main switch | `enabled` (exist at all) and `hideMainBar` (replace the normal bar or sit beside it) |
| 2. Position and shape | `position`, `style`, `height`, `margin`, `spacing`, `opacity`, `color`, `radius`, `fontSize`, `iconSize`, `reserveSpace`, `screens` |
| 3. Modules | the `left`, `center` and `right` lists; commenting a line out with `//` switches that module off |

Each module's **own** options (clock format, brightness step and so on) stay in
`config/config.json` → `widgets`, shared with the normal bar.

## Layout

The module is split the way the rest of the shell is, with one directory per role, so that each
file has one reason to change:

```
minibar/
├── model/        what it should be, and what it is
│   ├── MiniBarConfig.qml   the settings above (pure data, no dependencies)
│   └── MiniBarState.qml    switched on or not, kept in its own state file
├── view/         what is drawn
│   ├── MiniBar.qml         the bar of one screen (a PanelWindow)
│   └── MiniBarWindows.qml  one of those per screen, only while the bar is on
└── controller/   what acts
    └── MiniBarController.qml   show / hide / toggle / status
```

- **The model has no dependencies.** `MiniBarState` keeps its own file instead of adding a field to
  `services/Prefs.qml`, so the services layer does not have to know this module exists and the
  dependency points one way only: `services/BarLayout.qml` reads the model, never the other way
  around. A QML module cycle between the two would not resolve.
- **The view only reads.** It never writes the state; the controller is the single place the stored
  choice changes.
- **The controller is not where the IPC target is declared.** That stays in `bar/Shell.qml`, where
  every target of this shell lives so `qs ipc show` lists them in one place, and each of its
  functions is one line into the controller.

## What it touches outside this directory

Three hooks, each a few lines and commented where it sits:

| File | What was added |
|---|---|
| `bar/services/BarLayout.qml` | `mini`, and the measurements it takes from `MiniBarConfig` while the minimal bar is in charge |
| `bar/modules/bar/Bar.qml` | the normal bar hides while it is being stood in for |
| `bar/Shell.qml` | `MiniBarWindows {}` and the thin `minibar` IPC target |

The modules read the height, the font and the icon size from `BarLayout`, which is **shared by both
bars**. That is why the measurements in section 2 only apply when the minimal bar replaces the
normal one (`hideMainBar: true`). With `hideMainBar: false` both are shown at once but share the
normal bar's measurements — a deliberate trade, not a bug, and it avoids duplicating the 20 modules
just to give them two sizes.

## Worth knowing

- `qs ipc call bar hide` / `show` / `toggle` hide whichever bar is in use.
- `qs ipc call bar layout <name>` and the layout editor (`bar edit`) act on the **normal** bar; the
  minimal one has its own lists and ignores them.
- `qs ipc call bar height N`, `taller` and `shorter` are ignored too while the minimal bar is in
  charge with a `height` of its own. Set `height: 0` to go back to controlling the height from there.
- A misspelled module id in a list: the bar does not break, the module does not appear and the name
  is in the log (`journalctl --user -u "hyde-*-qsbar.service"`).
- Everything the modules do — menus, popouts, tooltips, scrolling on the volume — works the same
  here, including the IPC test path (`qs ipc call bar popout calendar`).
