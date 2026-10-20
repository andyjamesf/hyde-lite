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

## B. Referenced only by HyDE's own binds for the removed apps (dead at runtime, deleting means editing upstream's dispatcher)

`Configs/.local/share/hypr/lua/hyde/dispatcher.lua` maps menu actions to `rofilaunch`, `rofiselect`,
`logoutlaunch`, `calculator` and `waybar.py --hide`; `key_binds.lua` binds them. With the shells' own
launcher, power menu and calculator these binds start something that is not installed.

| Path | What goes with it |
|---|---|
| `rofilaunch.sh`, `rofiselect.sh`, `logoutlaunch.sh`, `rofi.bookmarks.sh`, `rofi.websearch.sh` | the dispatcher and key_binds lines above |
| `luautils/selector/rofi.lua`, `luautils/rofi/pos.lua`, `pyutils/wrapper/rofi.py` | called only by the scripts above |
| `waybar.py` (153 mentions of waybar) | `waybar.toggle` in the dispatcher, `layer_rules.lua`, commented binds in `key_binds.lua` |
| `Configs/.local/share/hyde/dunst.conf` | one entry in `config-registry.toml` (`dunst.conf` target) |

## C. Keep: shared helpers that only have a rofi/waybar branch

`wallbash.sh`, `globalcontrol.sh`, `hyprlock.sh`, `cliphist.sh`, `session.py`, `notifications.py`,
`weather.py`, `wallpaper/*.sh`, `animations.lua`, `layouts.lua`, `shaders.lua`, `workflows.lua`,
`bookmarks.py`, `cava.py`, `hyprsunset.sh`, `completions.py`. They mention the removed apps in one branch or
a usage text; the shells and HyDE's own hooks call them for other reasons.

## Suggested order

1. Delete group A: 5 paths, about 870 lines of scripts and 158 KiB, with a `LITE.md` row. Zero references.
2. For group B, decide first whether the HyDE-style binds (`Super+A` style menus) are wanted at all. If not,
   remove the dispatcher and `key_binds.lua` lines and the scripts together (one commit, a few lines in two
   upstream files, each with a comment). If yes, install rofi again; the two choices exclude each other.
3. Leave group C.
