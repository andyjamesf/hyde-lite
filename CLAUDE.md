# hyde-lite - context for Claude

**HyDE, trimmed down, with two Quickshell shells and a single colour pipeline (matugen) on top.** This
repository is meant to be the one thing you install on a barebones Arch with one command.
This file is how to work in it.

Everything written into the repository (code comments, docs, commit messages, PR text) is **English**,
because this is a GPL-3.0 fork of `HyDE-Project/HyDE` and should stay readable to its upstream.

## What this repository is

- A fork of HyDE cut at upstream `aceb94ee` (2026-09-20, the Lua-configuration era). `main` is that
  commit plus a small set of commits listed in `LITE.md`. Keep that set small and rebase-friendly:
  prefer removing a line from a list over editing the middle of an upstream script, and say in
  `LITE.md` what each change is and why.
- `upstream` is `HyDE-Project/HyDE` (fetch only; pushing to it is disabled on purpose). `origin` is
  this repository.

## Decisions already taken (do not re-litigate; build on them)

1. HyDE's theme system is being **dispensed with**: one base theme ("Nordic Blue", 3 MB) is shipped,
   not twelve. Wallpapers are picked from one library, not through a theme.
2. **matugen is the only source of colour.** The owner picks one of its 10 schemes and a mode
   (auto/dark/light) per wallpaper; both live in one place (`theme.mode`, `theme.scheme`) and HyDE's
   own `enableWallDcol` is written from them so the two can never disagree. A flag that disagrees
   with matugen makes HyDE invert templates that were right.
3. The owner keeps **both shells**: the HyDE-style bar (islands/pills, 7 layouts) and the
   "Morphing Island" (one pill that expands). He wants a **bar builder** (compose bars and pills from
   widgets) rather than more hard-coded layouts.
4. **Simple and fast** is the goal. HyDE is too full; remove what the shells replace, do not add
   features nobody asked for. A colour change should show on screen in about half a second; the slow
   part (rebuilding HyDE's templates) runs in the background.
5. Install is **one command** from a barebones Arch, idempotent, and it must work on an unknown PC
   (no hardware assumptions outside `machines/`).

## Rules

- **Measure, then claim.** Every performance or correctness claim in a commit, PR or doc has the command
  and the output behind it. Anything you could not test is listed as "NOT TESTED" with the reason. Do
  not write "works" for something that did not run. A result of zero evidence is a valid result.
- Branch per task (`claude/<topic>`), small PRs against `main`, never push to `main` directly, never
  force-push, never touch `upstream`.
- **No secrets.** Do not commit tokens, keys, passwords, `.env` files or API credentials; scan new
  files before committing. The git history is forever, so write as if everything were public (no personal paths or email in files).
- Only files the owner owns are tracked. Never commit what HyDE generates or overwrites
  (`~/.cache/hyde`, `~/.config/waybar/theme.css`, `~/.config/hypr/themes/*`, compiled caches).
- Changes in `Scripts/` or `Configs/.local/lib/hyde/` (HyDE's own code) are the expensive ones: each
  one is a future rebase conflict. Make them minimal, put the reason in a comment and in `LITE.md`.
- Hyprland's configuration here is **Lua** (`hyprland.lua`), not `hyprland.conf`.
- Never run `hyprlock` to "test" it: it really locks the screen.
- End commit messages with the co-author line your harness gives you.

## What you can and cannot test where

Cloud sessions run in an Ubuntu 24.04 microVM (4 vCPUs, ~15 GiB RAM, 30 GB disk). Measured on
2026-10-13 with the first test of this repository:

- **No `/dev/kvm`, no QEMU installed**: a real Arch VM is impossible there.
- `docker` exists but its daemon was not running; start it yourself (`dockerd`) before concluding it is
  unavailable. Docker Hub and GitHub are reachable.
- The default "Trusted" network blocks `geo.mirror.pkgbuild.com`, `mirror.pkgbuild.com`,
  `archlinux.org` and `aur.archlinux.org`, so `pacman` and the AUR do not work unless the owner
  switches the environment's network to Full. If a step needs them and they are blocked, stop that step,
  list the exact blocked domains and mark it NOT TESTED; do not work around the proxy.

So the work divides like this:

| Where | What it can prove |
|---|---|
| Cloud session | Code and docs work; `bash -n`, `shellcheck`, `python3 -m py_compile`, `ruff`, TOML/JSON parsing, `qmllint` (try `apt install qt6-declarative-dev-tools`), unit tests of the Python tools, container tests of package/dotfile deployment (only with Full network) |
| Owner's machine / a local VM | Anything that needs systemd, SDDM, Hyprland, a GPU, the real shells on screen, or a clean-install timing |

A PR that touches visual behaviour says plainly that it was not seen on a screen, and lists what the
owner has to look at.

## Conventions worth knowing

- Quickshell resolves `qs.<dir>` to the shell's own subdirectories at runtime; `qmllint` does not, so
  the linter builds a throwaway import tree (see the owner's `tools/qml-lint.sh`, to be moved here).
  It only understands the island's tree; the HyDE-style shell resolves its modules differently.
- A change that affects every machine is fine for preferences; hardware (monitors, GPU, drivers)
  belongs under `machines/<name>/` and nowhere else.
- Colour code reads polarity from matugen's `default` key (it follows `-m dark|light|smart`).
- Two things that have already bitten, so check for them: wallbash's shade ramp can come out reversed
  (`1xa1` next to the text instead of the background) and `~/.cache/hyde/wall.dcol` is a symlink HyDE
  re-points, so a file watch on it silently goes stale.
