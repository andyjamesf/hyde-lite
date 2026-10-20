# What is left of the removed apps

hyde-lite does not install rofi, waybar, dunst, swaync or wlogout, but HyDE's code still mentions them.
This is a map of that, not a clean-up: nothing here was deleted. Measured on 2026-10-20 at `origin/main`
(`8f42831d`) with `git grep`; "referenced" means a text match for the file's name outside the file itself
and outside this document and `LITE.md`.

```sh
git grep -l -i -E 'rofi|waybar|wlogout|swaync|dunst' -- Configs/.local Scripts | wc -l     # 101 files
```

**Limit of the method.** `Configs/.local/bin/hydectl` and `hyde-ipc` are prebuilt binaries and cannot be
searched for the scripts they might call by name. A file marked "no reference" is unused as far as the text
of this repository shows.

> **Status 2026-10-20.** Group A was deleted in #14. Of group B, B1 (the five rofi scripts, their `dispatcher.lua`
> entries and nine rofi binds) and `waybar.py` with `pyutils/wrapper/rofi.py` (its only importer, once `Scripts/install.sh`
> stopped calling it) were deleted in the PR that follows this document. What is left of B2 is
> `luautils/selector/rofi.lua`, required by `common.lua` and `shaders.lua`.

## A. No reference anywhere (safe to delete, each is a delete/modify conflict when porting upstream)

| Path | Size | Note |
|---|---|---|
| `Configs/.local/lib/hyde/gpuinfo.sh` | 361 lines | a waybar module script |
| `Configs/.local/lib/hyde/sensorsinfo.py` | 266 lines | same |
| `Configs/.local/lib/hyde/cpuinfo.sh` | 128 lines | same |
| `Configs/.local/lib/hyde/rofi.layouts.lua`, `rofi.shaders.lua`, `rofi.workflows.lua` | 114 lines | the shells have their own ports (`PickLayouts.qml`, `PickShaders.qml`, `PickWorkflows.qml`) and only mention these in comments |
| `Configs/.config/wlogout/` | 16 files, 158 KiB | `LITE.md` kept it for upstream's `test_monitor_scale`; that test went with the `tests` submodule, and the only test left that names wlogout (`tools/tests/test_package_lists.py`) asserts the package is *not* installed |

## B. Referenced only by HyDE's own binds for the removed apps (checked again on 2026-10-20: not one block)

`Configs/.local/share/hypr/lua/hyde/dispatcher.lua` maps menu actions to `rofilaunch`, `rofiselect`,
`logoutlaunch`, `calculator` and `waybar.py --hide`; `key_binds.lua` binds them. A second look at who calls what
splits the group in two.

**B1. Dead, and removable together.** The launch scripts and the binds that reach them:

| Path | Lines | Reached only by |
|---|---|---|
| `rofilaunch.sh`, `rofiselect.sh`, `logoutlaunch.sh` | 211 | `dispatcher.lua` (`menu.apps/windows/files/launcher/select`, `session.logout.launcher`) |
| `rofi.websearch.sh`, `rofi.bookmarks.sh` | 256 | the HyDE schema text only (`[rofi.websearch]` sections), and the shells' ports mention them in comments |
| 9 binds in `key_binds.lua` (`TAB`, `SHIFT+E`, `comma`, `period`, `SHIFT+slash`, `SHIFT+G`, `SHIFT+W/R/T`) | 9 lines | `island.lua` binds the same keys (all but `SHIFT+slash`, which it moved to `SHIFT+backslash`) to the shells' pickers |

Removing them means editing two upstream files (`dispatcher.lua`, `key_binds.lua`: a few lines each, with a
comment) and deleting five scripts. Left as is, those keys do nothing useful when `island.lua` fails to load.

**B2. Not dead: keep.**

| Path | Why |
|---|---|
| `waybar.py` | `Scripts/install.sh:499` runs `waybar.py --update`; HyDE's config starts the bar with `waybar.py --watch` (`schema/config.toml:320`); `Configs/.local/bin/island` has a comment about it. It is part of how a HyDE session starts, whatever the bar is |
| `luautils/selector/rofi.lua`, `luautils/rofi/pos.lua` | `luautils/selector/common.lua` and `shaders.lua` `require` it |
| `pyutils/wrapper/rofi.py` | imported by `waybar.py` |
| `Configs/.local/share/hyde/dunst.conf` | a target in `config-registry.toml` |

So the earlier estimate of "dead at runtime" for all of group B was too generous. B1 is the removable part:
467 lines of scripts and 9 bind lines.

## C. Keep: shared helpers that only have a rofi/waybar branch

`wallbash.sh`, `globalcontrol.sh`, `hyprlock.sh`, `cliphist.sh`, `session.py`, `notifications.py`,
`weather.py`, `wallpaper/*.sh`, `animations.lua`, `layouts.lua`, `shaders.lua`, `workflows.lua`,
`bookmarks.py`, `cava.py`, `hyprsunset.sh`, `completions.py`. They mention the removed apps in one branch or
a usage text; the shells and HyDE's own hooks call them for other reasons.

## Suggested order

1. Delete group A: 5 paths, about 870 lines of scripts and 158 KiB, with a `LITE.md` row. Zero references.
2. Group B1, in one commit: the 9 binds, their `dispatcher.lua` entries and the five scripts. B2 stays.
3. Leave group C.
