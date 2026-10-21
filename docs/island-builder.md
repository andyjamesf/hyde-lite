# Island builder

What you can arrange on the Morphing Island without editing code: which icons the status pill and the expanded
island show, and extra pills beside the clock. Everything is stored as overrides in
`~/.local/state/morphing-island/prefs.json` (see `Configs/.config/morphing-island/config/README.md`), applies live,
and "Reset to defaults" in Settings removes it.

> [!NOTE]
> Written from the code and its tests. The Settings editors and the extra pills have not been seen on a screen yet:
> the first thing to check is that they look right and that every pill receives clicks.

## In Settings

Open the island, then Settings (the cog in the expanded island), and scroll down:

- **Pill**: 12-hour clock, top margin, status pill on or off, status pill next to the clock.
- **Icons**: *Status* (the status pill, and the right zone of the expanded island) and *Shortcuts* (buttons next to
  them, as many as fit). Click an icon to select it, then **Earlier**, **Later** or **Remove**; click a `+` chip to
  add one. **Default** goes back to the shipped list.
- **Extra pills**: **Add a pill** (up to four). Each pill has a **Left / Right** choice, its own widget list (edited
  the same way) and **Remove pill**. A pill with no widgets is removed.

## By hand

```json
{
  "statusPill.icons": ["volume", "wifi", "battery", "power"],
  "expanded.extraButtons": ["screenshot", "lock"],
  "pills.extra": [
    { "side": "right", "widgets": ["clock", "media"] },
    { "side": "left", "widgets": ["workspaces", "date"] }
  ]
}
```

A list that is not valid (wrong type, an empty or non-string id, more than four pills, a `side` other than `left` or
`right`, a pill without widgets) is dropped and reported as one notification; the shipped default applies.

## Widgets

| Id | Shows | Click |
|---|---|---|
| `volume`, `bluetooth`, `wifi`, `battery`, `power` | the usual status icons | their page or the power menu |
| `notifications`, `caffeine`, `ai`, `weather`, `updates` | bell, caffeine, AI usage, weather, pending updates | their page |
| `clock`, `date` | the time, the date | the calendar |
| `mic` | microphone, crossed out when muted | mutes it |
| `brightness` | a sun and the percentage | scroll to change it |
| `media` | play or pause and the title | pause or resume; middle click skips |
| `workspaces` | the workspace indicator (extra pills only) | switches workspace |

Shortcut buttons (the *Shortcuts* list): `nightlight`, `screenshot`, `clipboard`, `picker`, `wallpaper`, `theme`,
`settings`, `lock`, `power`, `system`, `nextwallpaper`, `hydetheme`, `keybindings`. A plugin's id (from
`~/.local/share/morphing-island/plugins`) also works in `statusPill.icons`.

## How extra pills behave

They sit at the screen's edges next to the two built-in pills: left ones stack rightwards after the workspace pill,
right ones leftwards before the status pill. When the island expands, or shows anything other than its clock, they
slide under it and fade, like the built-in pills. Up to four exist (`PillsConfig.maxPills`).

## Where it lives

| File | Role |
|---|---|
| `config/PillsConfig.qml` | reads `pills.extra`; the pure list edits and the position arithmetic |
| `config/PrefsSchema.qml` | validates every key, including the `list` and `pills` shapes |
| `core/ExtraPill.qml`, `core/IslandWindow.qml` | the four pill slots and their click regions |
| `components/IconListEditor.qml`, `PillsEditor.qml`, `PillCard.qml` | the Settings editors |
| `tools/tests/test_pills.py`, `test_icon_list_editor.py`, `test_prefs_schema.py` | the tests |

## Keeping an installed copy in step

If the configuration you run is a copy (for example `~/.config/quickshell` is a link into your dotfiles) and not this
checkout, turn on the pull hook once:

```sh
bash tools/install_hooks.sh
```

After that, a `git pull` that changes `Configs/.config/quickshell` runs `tools/sync_shell.py` by itself: it copies
the whole installed folder to `~/.local/state/hyde-lite/backups/` first (the newest five are kept), then adds and
overwrites the new and changed files. It never deletes anything, never touches `prefs.json` or your wallpapers (they
live outside that folder), and a failure only prints a message: the pull itself is never affected. A pull with
`pull.rebase` is covered too.

- Restart the island afterwards (`island off && island on`); whether Quickshell also reloads by itself when the files
  change has not been checked.
- If the installed folder is inside a git repository (dotfiles), it will show the changes: commit them there.
- Skip it once with `HYDE_LITE_NO_SYNC=1 git pull`; turn it off with `bash tools/install_hooks.sh --off`.
- To see what it would do without a pull: `python3 tools/sync_shell.py` (a dry run).
