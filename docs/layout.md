# Repository layout

Where things live and what to touch for a given change. For how the shells are layered inside, see
[`architecture.md`](architecture.md); for what differs from upstream HyDE, [`../LITE.md`](../LITE.md).

The tree is not reorganised on purpose: the installer (`Scripts/restore_cfg.psv`, `Scripts/dots/*.toml`)
and the upstream port path (`LITE.md`, "Following upstream") both depend on the current paths. This page is
the map, not a move.

## Who owns what

The split that matters when editing: files hyde-lite wrote are free to change; HyDE's own files are
porting conflicts, so every edit to them is minimal and recorded in `LITE.md`.

| Owner | Paths |
|---|---|
| hyde-lite | `Configs/.config/quickshell/` (both shells and `shared/`), `Configs/.config/matugen/`, `Configs/.local/bin/{island,wallbash-matugen,wallpaper-library,wallpaper-palette,matugen-icons,shell-cycle,hyde-lite,hydectl}`, `tools/`, `docs/` (hardware-specific files belong in `machines/<name>/` when one is added) |
| HyDE (edit minimally) | `Scripts/*.sh`, `Scripts/*.lst`, `Scripts/restore_cfg.psv`, `Configs/.local/lib/hyde/`, `Configs/.local/bin/hyde-shell`, `Configs/.local/share/{hyde,wallbash,hypr}/` |
| Mixed | `Scripts/dots/` and `Scripts/dots-groups/` (HyDE's format, lite's entries: `colour`, `hyde-lite`, `morphing-island`, `quickshell`), `Configs/.config/hypr/` (`keybinds.lua`, `island.lua`, `hypridle.conf` are lite's) |

## Top level

| Path | What it is |
|---|---|
| `install.sh` | the one-command installer; wraps `Scripts/install.sh` in separate steps |
| `Configs/` | everything deployed into `$HOME` (`.config`, `.local`) |
| `Scripts/` | HyDE's installer and the dot/group definitions that decide what gets deployed where |
| `Wallpapers/` | the wallpaper library (`SOURCES.md` lists origins and licences) |
| `Source/` | archives the installer unpacks (SDDM, GTK and icon themes, Spotify) |
| `tools/` | checks, generators and unit tests; `tools/check.sh` runs all of it, CI runs the same |
| `docs/` | maintainer docs (this page, architecture, the two builders, troubleshooting, weight) |
| `LITE.md` | the ledger of every difference from upstream, and how to port upstream changes |
| `CLAUDE.md` | rules and decisions for working in the repository |

## `Configs/`

| Path | What it is |
|---|---|
| `.config/quickshell/shell.qml`, `lock.qml`, `sync.qml` | entry points: pick the active shell; the lock-only shell; the sync helper |
| `.config/quickshell/bar/` | the HyDE-style bar (islands, pills, layouts); `config/` holds user config, `services/` state, `modules/` window plus view |
| `.config/quickshell/island/` | the Morphing Island; `config/` constants, `services/` state, `components/` views, `core/` controller and lock screen, `sddm/` the login theme |
| `.config/quickshell/shared/` | code both shells load: `services/Lock.qml`, `pickers/`, `controlcenter/` |
| `.config/matugen/` | matugen config and its four templates (Hyprland, GTK, kitty, zed) |
| `.config/hypr/` | `hyprland.lua` (entry), `keybinds.lua`, `island.lua`, `hypridle.conf`, `lua/` |
| `.config/hyde/` | HyDE's `config.toml` and the wallbash scripts/templates |
| `.config/{kitty,zsh,fish,...}` | app configs |
| `.local/bin/` | commands on `PATH` |
| `.local/lib/hyde/` | HyDE's helper scripts (wallpaper, theme, color, session, cava, ...) |
| `.local/share/{hyde,wallbash,hypr}/` | HyDE's schema, wallbash templates and Hyprland Lua modules |

## Where to change what

| I want to... | Go to | Then run |
|---|---|---|
| change a colour, scheme or mode | `Configs/.local/bin/wallpaper-palette`, `Configs/.config/matugen/`; wallbash templates under `Configs/.local/share/wallbash/` | `tools/tests/test_wallbash_matugen.py` |
| add a program to the colour pipeline | a matugen template plus an entry in `Configs/.config/matugen/config.toml`, or a wallbash `.dcol` | `tools/check.sh` |
| change a keybinding | `Configs/.config/hypr/keybinds.lua` (lite's) or `Configs/.local/share/hypr/lua/key_binds.lua` (HyDE's); then regenerate `KEYBINDINGS.md` with `tools/gen_keybindings.py` | `tools/check.sh` |
| change the lock screen | `Configs/.config/quickshell/shared/services/Lock.qml`, `island/core/LockScreen.qml`, `island/config/LockScreenConfig.qml`, `bar/modules/lock/`; idle in `Configs/.config/hypr/hypridle.conf` | lock by hand on your machine |
| change the login screen | `Configs/.config/quickshell/island/sddm/`, `island/scripts/sddm.py` | `tools/qml-lint.sh` |
| add a bar widget or layout | `bar/` (`docs/bar-builder.md`) | `tools/qml-lint.sh` |
| add an island feature | `island/` (`docs/island-builder.md`, `docs/island-features.md`) | `tools/qml-lint.sh` |
| edit something both shells have | edit one copy and mirror it: `tools/tests/test_mirrored_files.py` fails on drift | `tools/check.sh` |
| add or remove a package | `Scripts/pkg_core.lst` (legacy reader) and the dot's `[[x.dependency]]` in `Scripts/dots/` | `tools/tests/test_package_lists.py` |
| deploy a new file to `$HOME` | a `[[x.files]]` entry in `Scripts/dots/<x>.toml`; the group in `Scripts/dots-groups/` decides when it is installed | `tools/check.sh` |
| port an upstream HyDE change | `LITE.md`, "Following upstream" | `tools/check.sh` |

## Checks

`tools/check.sh` runs `bash -n`, `py_compile` and `ruff`, TOML/JSON parsing, the unit tests in
`tools/tests/` and the QML lint against `tools/qml-lint.baseline` (it fails only when a category grows).
Nothing in it starts a shell, a compositor or a lock screen: visual and session behaviour is only checked on
a real machine.

## Dependency map

`graphify` can build a queryable graph of the code (`graphify-out/`, not tracked). Its parser has no QML
support, so the graph covers the Python, shell and Lua (about 330 files) and not the 280 QML files of the
shells: use it for `Scripts/`, `lib/hyde/` and `tools/`, and `architecture.md` for the shells.
