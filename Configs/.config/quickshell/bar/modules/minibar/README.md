# The minimal bar

A second, slimmer bar that takes the normal one's place while it is switched on. It duplicates
nothing: it shows the **same modules** as the normal bar (`../bar/widgets/`), in the same container
(`Island`), through the same services. Putting a module on it means writing its name in a list —
no new code.

It starts with the day and time in the middle and the desktop you are on at the left, and nothing
else; every other module is one commented-out line away in the settings.

It reserves no space, so a window can use the whole screen and the bar floats on top
(`reserveSpace`), and it can hide itself as well (`autoHide`, below).

## Switching it on and off

```sh
qs ipc call minibar toggle     # minimal bar <-> normal bar
qs ipc call minibar on         # switch the minimal one on
qs ipc call minibar off        # back to the normal one
qs ipc call minibar status     # say which one is in use
```

They are `on`/`off` and not `show`/`hide` because `show` is also the name of a `qs ipc`
subcommand: `qs ipc call <target> show` never reaches the shell — the CLI prints the list of IPC
targets and exits, having changed nothing. The shell's own `bar` target has had that hole for as
long.

The key is **`$mod+SHIFT+I`**, which steps island -> HyDE bar -> minimal bar -> island
(`Configs/.local/bin/shell-cycle`, bound in `Configs/.config/hypr/keybinds.lua`, `M.binds`). There
is no key for the minimal bar alone; from a terminal `qs ipc call minibar toggle` does it.
`$mod+comma` is a different thing: it hides whichever bar is in use, this one included. The choice is
kept in `~/.local/state/quickshell/.../minibar.json`, so it survives `qs ipc call shell reload` and a login.

## The only file to edit

[`model/MiniBarConfig.qml`](model/MiniBarConfig.qml), commented line by line. Save it and the bar
applies the change on its own — the file is watched, nothing has to be restarted.

| Section | What it controls |
|---|---|
| 1. The main switch | `enabled` (exist at all) and `hideMainBar` (replace the normal bar or sit beside it) |
| 2. Position and shape | `position`, `style`, `height`, `margin`, `spacing`, `opacity`, `color`, `radius`, `fontSize`, `iconSize`, `reserveSpace`, `screens`, and the three hiding settings below |
| 3. Modules | the `left`, `center` and `right` lists; commenting a line out with `//` switches that module off |

Each module's **own** options stay in `config/config.json` → `widgets`, shared with the normal bar.
The clock's day is one of them: `widgets.clock.showDate` (with `format` and `dateFormat` next to
it). That file is the owner's, so `tools/sync_shell.py` adds it when missing and never overwrites
it — a change there stays on the machine it was made on.

## Hiding it

`autoHide: true` keeps the bar off the screen edge and leaves `peek` px of it behind. Only what the
mask covers takes the pointer, so while the bar is hidden the clicks belong to the window
underneath; moving the pointer onto that strip slides the bar back in, and it slides away again
`hideDelay` ms after the pointer leaves. It never hides while one of its own panels is open (the
calendar, the volume panel), and a bar that hides itself never reserves space, whatever
`reserveSpace` says.

The pointer is read with a `HoverHandler` rather than a `MouseArea` on purpose: a handler reports
the pointer in parallel with the widgets' own mouse areas instead of competing with them for it, so
hovering a module does not read as "the pointer left the bar". **This has not been seen on a
screen.** If the bar does slide away while the pointer is over a module, that is the mechanism that
failed, and the fix is to reveal on the widgets' own hover as well rather than to swap the handler
for a `MouseArea`, which would eat their clicks.

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
    └── MiniBarController.qml   on / off / toggle / status
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

- `qs ipc call bar toggle` ($mod+CTRL+B) hides whichever bar is in use, this one included.
- The bar is on the `top` layer, like the normal one, so a **fullscreen** window covers it. For a
  bar whose point is to leave the screen to the windows that is the wanted behaviour; a bar that
  should stay over a fullscreen video wants `WlrLayer.Overlay` in `view/MiniBar.qml`.
- `qs ipc call bar layout <name>` and the layout editor (`bar edit`) act on the **normal** bar; the
  minimal one has its own lists and ignores them.
- `qs ipc call bar height N`, `taller` and `shorter` are ignored too while the minimal bar is in
  charge with a `height` of its own. Set `height: 0` to go back to controlling the height from there.
- A misspelled module id in a list: the bar does not break, the module does not appear and the name
  is in the log (`journalctl --user -u "hyde-*-qsbar.service"`).
- Everything the modules do — menus, popouts, tooltips, scrolling on the volume — works the same
  here, including the IPC test path (`qs ipc call bar popout calendar`).
