# HyDE LiTE

A branch of HyDE with what a Quickshell setup does not need taken out, and one change to make
colour changes faster. It follows upstream by porting its changes (see "Following upstream"): every cut is a
line removed from a list, not an edit inside a script, so an upstream patch applies with few conflicts.

Not a standalone desktop: the bar, notifications, launcher and logout menu are expected to come from
a shell installed on top (waybar, rofi, dunst, swaync and wlogout are not installed here).

## What is different from upstream

| Where | Change |
|---|---|
| `Scripts/dots-groups/core.toml` | no `waybar`, `rofi`, `dunst`, `wlogout` dots (9 includes -> 5) |
| `Scripts/dots-groups/extra.toml` | no `swaync` dot |
| `Scripts/dots/deps.toml` | no `wlogout` (an AUR package, so it was built from source on install) |
| `Scripts/pkg_core.lst` | same four packages out of the legacy list that `install_pkg.sh` reads |
| `Scripts/themepatcher.lst` | one theme (Nordic Blue, 3 MB) instead of twelve. HyDE falls back to the first theme of the list when `HYDE_THEME` is missing (`globalcontrol.sh`), so any one will do |
| `Scripts/dots/quickshell.toml` | `ttf-jetbrains-mono-nerd` added: the shells' icon font used to come only from an archive download (`Scripts/dots/archives.toml`, group `font-jetbrains-mono`) that the lite path does not run, so the icons showed as boxes on a clean install. A system package and not a copy under `~/.local/share/fonts`, because the login screen (SDDM) runs as its own user and cannot read your home. `Scripts/pkg_core.lst` lists it too, from an earlier attempt, but that line is dead code: `install_pkg.sh` is its only reader and nothing in the repository calls it (the mention in `Scripts/dots/deps.toml` is a comment) |
| `Configs/.config/quickshell`, `Scripts/dots/quickshell.toml`, `Scripts/dots/morphing-island.toml`, `Scripts/restore_cfg.psv` | one Quickshell configuration instead of two: the HyDE-style shell moved to `quickshell/bar/` and the Morphing Island (was `Configs/.config/morphing-island`) to `quickshell/island/`, imports are `qs.bar.*` and `qs.island.*`, and a new root `shell.qml` loads the UI chosen by `island on|off`. A patch from upstream that touches `quickshell/<dir>/...` applies to `quickshell/bar/<dir>/...`. `tools/sync_shell.py` moves a customised `config/config.json` or `config/layouts.json` to `bar/config/` and no longer overwrites those two files; the installer alone does not move them, so after re-running it on an existing machine copy them by hand. See `docs/shell-unification.md`. |
| `install.sh` (repository root) | `check_fonts` reads `fc-list` into a variable once instead of piping it into `grep -q`. The script runs with `set -uo pipefail`, and `grep -q` exits at its first match, which leaves `fc-list` killed by SIGPIPE and the pipeline's status at 141: the check measured where a font sat in the list, not whether it existed, so the Fonts step failed (installer exit 1) on every clean install that had otherwise worked. It now also checks the icon font as the `sddm` user, which your own session cannot show you |
| `Configs/.config/quickshell/island/scripts/sddm.py` | `install()` copies the two fonts into the theme itself (new `bundle_fonts()`, shared with `sync()`) and writes a minimal `theme.conf.user` when there is none. It used to leave that to an IPC call into the running island, which on a clean install does not exist and failed silently, so the theme fell back to font family names and the very first login screen came up with no icons (SDDM's user cannot read `~/.local/share/fonts`). It fixed itself after the first login |
| `Configs/.local/lib/hyde/theme.switch.sh`, `Configs/.local/lib/hyde/color/hypr.sh` | `GTK_THEME=Wallbash-Gtk` after the theme variables are loaded, and `__GTK_THEME=Wallbash-Gtk` after `hypr.sh` reads them: `ICON_THEME=Matugen-Icons` / `__ICON_THEME` the same way (Papirus-Dark with folders in matugen's secondary palette, written by the new `bin/matugen-icons`, which `wallbash-matugen` runs; needs `papirus-icon-theme`). A HyDE theme's own GTK theme (Ever-Blush, Nordic...) is static, so GTK apps (Thunar, Nautilus) did not follow matugen or the dark/light mode, and `gsettings` and `ui.lua` kept the theme's name. Wallbash-Gtk is built from the palette `wallbash-matugen` writes. `__COLOR_SCHEME=prefer-${dcol_mode}` in `color/hypr.sh` makes the system colour scheme follow the mode matugen chose (it stayed `prefer-dark` whatever the mode, so Electron apps such as Obsidian, libadwaita and Zed disagreed with the rest). `theme.switch.sh` ends by naming another GTK and icon theme for a moment and then ours again, because GTK apps reload a theme when its name changes, not its files (an open Thunar kept the old mode). A few lines, each with a comment |
| `Configs/.local/bin/wallbash-matugen` (not HyDE's) | the shade ramp runs 20 -> 95 in dark mode and 95 -> 20 in light, so step 1 is always next to the window background, as HyDE's own dcols have it (4xa1 nearer pry1 than 4xa9 in 431 of 459 dark and 99 of 101 light cached dcols). It ran 95 -> 20 in both modes, which gave the GTK theme dark text on a dark window and Kvantum a light base under a dark one |
| `Scripts/dots/colour.toml` | adds `papirus-icon-theme` and deploys `matugen-icons` (additive, not HyDE's file) |
| colour pipeline, grey surfaces | `wallpaper-palette` replaces matugen's tinted surface roles (`background`, `surface*`) with plain greys at fixed CIELAB lightness (dark 15-30, light 85-97) before anything reads the palette, and renders matugen's templates from that palette (`matugen json`) instead of from the image run (`--dry-run` there). The island, wallbash-matugen's dcols, GTK, Qt, kitty and the swatches all get the same neutral base; accents and text still come from the wallpaper. Not HyDE's file |
| Zed theme | `Configs/.config/matugen/templates/zed.json` (generated by `tools/gen_zed_template.py`) and a `[templates.zed]` entry in the matugen config write `~/.config/zed/themes/matugen.json`, with a dark and a light theme from the same roles as GTK. Zed's `settings.json` stays the user's: it names `Matugen Dark` / `Matugen Light` with `mode: system`. Not HyDE's |
| file manager: Thunar instead of Dolphin | `Scripts/dots/dolphin.toml` becomes `thunar.toml` (thunar, thunar-volman, gvfs, tumbler, ffmpegthumbnailer; `dots.toml` and `dots-groups/extra.toml` include it instead). `Scripts/dots/deps.toml` and `Scripts/pkg_core.lst` lose the KDE thumbnail and file-type packages (`ffmpegthumbs`, `kde-cli-tools`), `install_pst.sh` sets `thunar.desktop` as the `inode/directory` handler, `variables.lua` launches `thunar` and `window_rules.lua` adds it to the file-manager rule. Why: Thunar is GTK3, so it follows the colours matugen already writes to `gtk-3.0/`; Dolphin took its colours from HyDE's qt6ct/Kvantum files, which came out with a light base under a dark window. The Dolphin files are gone: `Configs/.config/dolphinrc`, `.local/share/{dolphin,kxmlgui5/dolphin}`, the KIO service menu `hydewallpaper.desktop`, `.local/state/dolphinstaterc`, and their lines in `restore_cfg.lst/psv` (`kdeglobals` stays, still conditioned on `dolphin` in the legacy list, which the lite installer does not read). `Scripts/dots/thunar.toml` keeps deploying `applications.menu` |
| GTK menus and popovers | the matugen `gtk.css` template styles `menu`, `menuitem`, `popover.background` and the popup border from the neutral surface roles. Wallbash-Gtk draws them with literal colours from its accent ramp (a teal body and a cyan border on a teal wallpaper), which the named colours do not reach. Not HyDE's file |
| unused leftovers of the removed apps | deleted (nothing in the repository's text refers to them; the audit is `docs/legacy-audit.md`): `Configs/.local/lib/hyde/{gpuinfo.sh,sensorsinfo.py,cpuinfo.sh}` (waybar module scripts), `rofi.{layouts,shaders,workflows}.lua` (the shells have their own ports), and `Configs/.config/wlogout/` (16 files; it was kept for an upstream test that went with the `tests` submodule). The prebuilt `hydectl` could in principle call a script by name; none of these names appears in its strings. Each is a delete/modify conflict to resolve by deleting when porting. The earlier row that kept `Configs/.config/wlogout` no longer applies |
| colour change rebuild | `wallbash-matugen` renders HyDE's templates with `color.set.sh <wallpaper>` instead of the whole `theme.switch.sh` (median 1.16 s against 2.1-2.2 s; 23 generated files byte-identical), then makes open GTK apps reload by naming another GTK and icon theme for a moment. `theme.switch.sh` stays as the fallback when `color.set.sh` is missing or fails. What decides that the work is done is `~/.cache/morphing-island/wallbash.stamp`, a hash of the palette the templates were last rebuilt from, not whether `wall.dcol` holds the right bytes: that file resolves to a per-wallpaper one HyDE generates once and never regenerates (459 dark and 101 light are cached on this machine), so a wallpaper used before already had its palette on disk and the rebuild was skipped while the templates still held another wallpaper's colours. The rebuild's outcome is no longer discarded either -- a failure is reported, the stamp is not written so the next run tries again, and the last run's result is in `~/.cache/morphing-island/wallbash.log`, because this runs detached with both streams on `/dev/null`. `--force` rebuilds regardless. Not HyDE's file |
| `Configs/.local/bin/hydectl`, `hyde-ipc` | upstream's prebuilt `hydectl` (12.8 MiB) and `hyde-ipc` (2.8 MiB), whose source is not in this repository, are gone. `hydectl` is a script written here (60 lines over `hyde-shell`: `theme next/prev/set/import`, `wallpaper next/prev/set`, `reload`, `version`); `hyde-ipc` was called by nothing (a version line in `hyde-shell`). Its zsh completion (`Configs/.config/zsh/completions/hydectl.zsh`, which called the binary's `completion` subcommand) is removed with its `zsh.toml` entry. Delete/modify conflicts on the binaries and the completion when porting |
| `Scripts/install.sh` | the six `cat <<"EOF"` ASCII banners became `banner <<"EOF"`, and a `banner` function skips them when `HYDE_LITE` is set (the lite installer prints its own header and step titles). Run alone, the script prints them as before. One word per banner, so a porting conflict is one line |
| `Configs/.local/lib/hyde/color.set.sh` | GNU `parallel` replaced by `xargs -P` when rendering the wallbash templates |
| `Configs/.local/share/wallbash/` | no `always/dunst.dcol`, `scripts/dunst.sh`, `scripts/swaync.sh`, `theme/swaync.dcol`: they render into configs of apps lite does not install, and `tests/python/check_wallbash_targets.py` fails on them |
| `dotfiles` submodule, `.gitmodules` entry | removed (the edition's gitlink to the private the owner's private dotfiles repository): CI could not clone it. D1 is still open; the root `install.sh` and `README.md` from the edition still refer to `dotfiles/` until they are decided |
| `install.sh` (repository root) | removed (the edition's stopgap, which cloned the earlier combined repository and the `dotfiles` submodule); the one-command installer is PLAN 5.1, now a new `install.sh` for a generic PC (a wrapper that runs `Scripts/install.sh` in separate steps; see the `Scripts/install.sh` row for its one edit) |
| `README.md` and documentation | `README.md` is rewritten for hyde-lite (upstream's is in the upstream repository). Removed 2026-10-14 (owner asked for a clean-up): the translated READMEs, keybinding lists and Hyprdots-to-HyDE notes under `Source/docs` and `Source/assets/keybinds`, and from the root `Hyprdots-to-HyDE.md`, `README.edition.md`, `MIGRATION-LUA.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CONTRIBUTORS.md`, `COMMIT_MESSAGE_GUIDELINES.md`, `RELEASE_POLICY.md`, `TEAM_ROLES.md`, `TESTING.md` (upstream's contribution and release process, which does not apply here). Every one is a delete/modify conflict to resolve by deleting when porting. `.github/PULL_REQUEST_TEMPLATE.md` is replaced by a short lite template, and `CREDITS.md` is rewritten (upstream's first-person text and its Ko-fi section are gone, the HyDE and hyprdots credit and the contributors link stay), and `THIRD_PARTY.md` is new: what is original, what is HyDE's, which files carry another project's notice, and which shipped assets have an unverified licence. Kept: `KEYBINDINGS.md` (referenced from `hyprland.lua`), `CREDITS.md`, `LICENSE`, and the READMEs inside the shells, `Scripts/hydevm`, wallbash and the config schema. `.github/scripts/promote_to_*.sh` and `warn-master-pr.yml` still name the removed files in message text; they belong to upstream's release flow |
| removed apps' configs | deleted (owner asked 2026-10-13): `Configs/.config/{waybar,swaync,dunst,rofi}`, `Configs/.local/share/{waybar,hyde/rofi}`, their dots (`Scripts/dots/{waybar,rofi,wlogout,dunst,swaync}.toml`), the `notification-daemon` group and the includes in `dots.toml`. 247 upstream files; each upstream change to them is now a delete/modify conflict to resolve by deleting. Still present: the `Configs/.local/lib/hyde` helpers that mention rofi (`rofiselect.sh` and others), left because other scripts call them, and the commented rofi binds in `key_binds.lua` |
| `Configs/.local/share/hypr/lua/key_binds.lua` | `F10`/`F11`/`F12` volume binds and the `SUPER (+ SHIFT) + KP_*` workspace 11-20 binds restored after the edition's cleanup (`4d31761`) removed them: the upstream bind test requires them |
| `.github/` | removed 2026-10-14 for the public release: upstream's release flow (`workflows/{ci,test,lock,refresh-release,warn-master-pr}.yml`, `scripts/promote_*`, `remind-release.py`), `FUNDING.yml` (upstream's Ko-fi), `renovate.json5`, `codecov.yml`, `.all-contributorsrc`, and two issue templates. Added: a small `workflows/ci.yml` (checks, unit tests, shellcheck, ruff, luacheck, markdownlint, gitleaks, actionlint), `ISSUE_TEMPLATE/config.yml`, and rewritten bug and feature templates. Every one is a delete/modify conflict to resolve by deleting when porting |
| `tests` submodule, `.gitmodules` | removed: it pointed at `HyDE-Project/tests`, which tests upstream's own wallbash targets and waybar/rofi-era scripts. hyde-lite's tests are `tools/tests/` (run by `tools/check.sh`) |
| `Source/assets/` | removed (35 MiB): upstream's README screenshots and logos of waybar, rofi and wlogout setups that lite does not install. `KEYBINDINGS.md` lost its banner, distro logos, dead translation links and external heading images; its text is unchanged |
| `Configs/.config/fastfetch/logo/` | six logos of anime characters removed (2 MiB, origin unknown); `hyprland.icon` stays. `fastfetch.sh logo` picks a random `*.icon` from that folder, so one is enough |
| `Source/arcs/` | `Grub_Pochita`, `Grub_Retroboot`, `Steam_Metro`, `Firefox_Extensions` and `Firefox_UserConfig` removed (21 MiB): nothing in hyde-lite's installer reads them. `Scripts/install_pre.sh` (GRUB themes, not run by lite) and `Scripts/extra/restore_app.sh` (Firefox, an optional extra) still name them and are left alone, so running those would fail on the missing archive. Kept: `Sddm_Corners` (default), `Sddm_Candy` (`--interactive`), `Gtk_Wallbash`, `Icon_Wallbash`, `Spotify_Sleek` |
| `Wallpapers/` | the 30 images taken from community themes (licences unchecked) are replaced by 7 original pixel-art wallpapers generated by `tools/gen_wallpapers.py` (CC0); `Scripts/dots/wallpapers.toml` description updated |
| `Configs/.config/hyde/wallbash/scripts/cava.sh` | one comment line removed: a `shellcheck source=` hint naming another author's home directory (the next line already disables SC1091) |
| `.luacheckrc`, `.gitignore` | new / rewritten (the old `./.*` pattern never matched anything) |
| colour pipeline | new, additive: `Scripts/dots/colour.toml` deploys `wallpaper-palette`, `wallpaper-library`, `wallbash-matugen`, `Configs/.config/matugen`, a fontconfig rule, and the `matugen.dcol` / `quickshell.dcol` wallbash templates (under `Configs/.config/hyde/wallbash/always`). Copied unchanged from the owner's private dotfiles repository at `213c2a5`, together with that commit range's shell updates (`PickPalette.qml`, `Theme.qml`, `Config.qml`, island `Palettes.qml`). No upstream HyDE file is edited |

## History

This repository starts from a tree export made on 2026-10-15; it has no earlier history. The development
repository it came from kept HyDE's whole history (about 1 GB, mostly old wallpapers) and early commits
authored with a personal e-mail address, so the tree was published fresh instead. That history stays in a
private repository. The rows above and below still say what differs from upstream HyDE at the commit this
tree was cut from, `aceb94ee` (2026-09-20, the Lua-configuration era).

## Measured

On the machine this was made on, one `color.set.sh` run (the part of a theme or wallpaper change that
renders the templates), median of three:

- upstream 1056 ms, lite 722 ms (-32 %)
- reproduced on a clean 4-vCPU container: -252 ms,
  -16.5 % median. The two machines are not comparable (other applications and target counts), so read
  the saving as "about a sixth to a third", not as one fixed number
- the 14 template targets whose paths could be resolved came out byte-identical, and a run of the
  upstream script against itself also gave zero differences, so that is not noise (owner's machine; the
  clean-container run could compare 7 of 57 targets, also 0 differences, so the 14 is not reproduced there)
- `deez deps --check` on the core group: 64 -> 61 packages

What did NOT help, measured and dropped: skipping the 32 templates that a shell replaces (volume
icons, waybar, rofi, dunst, swaync, wayle) saves about 70 ms. The templates are cheap; starting
`parallel` and a process per template was the cost. Cutting templates is not a speed-up.

A clean install from nothing, run with `tools/vm-test.sh` on the Arch cloud image in QEMU (8 GiB, 6 vCPUs,
2026-10-16, this tree, `./install.sh --island --shell zsh`):

- installer exit code 0, 3m9s wall clock. Steps: Packages 93 s, Configs and themes 78 s, Login screen and
  shell 5 s, Services 0 s, Island shell and login screen 0 s, Fonts 0 s
- 14 post-install checks passed, 0 failed. They are written in `tools/vm-test.sh`, separately from the
  installer's own report, so a step that prints a tick is not what proves it
- the same tree before the three fixes above ended every run with the Fonts step at exit 1, and the first
  login screen with no icons under the password field
- the owner logged into that VM and confirmed on screen (2026-10-17) that the icons under the password
  field are drawn on the first login screen, which is what the three fixes were for. Before them, the same
  first login screen had none

## Not tested

- A clean install on a *barebones* Arch. What ran is the Arch cloud image in a VM (see Measured), which
  comes with a user, networking and systemd already set up. A hand-partitioned install, and real hardware,
  are still untested.
- The installer's final `chsh`. `tools/vm-test.sh` gives the installer `/dev/null` on stdin so nothing can
  block on a password prompt, and the installer skips that block when stdin is not a terminal
  (`[[ -t 0 ]]`), so the login shell stayed `/bin/bash` in the VM.
- The 14 byte-identical targets are the ones whose path is a plain file; templates that only run a
  command (the volume icons, the VS Code theme, Spotify, Discord) were not compared.

## Candidates, not cut

Packages in `Scripts/dots/deps.toml` that a Quickshell setup may not want, left in because whether
they are used is the owner's call: `firefox`, `ark`, `nwg-look`, `nwg-displays`, `qt5ct`, `kvantum-qt5`,
`network-manager-applet` and `blueman` (the island answers Wi-Fi and Bluetooth prompts itself).

## Using it

```
./install.sh        # see README.md
```

## Following upstream

This repository shares no git history with HyDE, so `git rebase upstream/master` and `git merge upstream/master`
do not work. Upstream changes are ported as a patch. The base is `aceb94ee`; HyDE's own code is `Scripts/` and
`Configs/.local/lib/hyde/` (see `CONTRIBUTING.md`):

```sh
# in a clone of HyDE (a blobless one is enough: git clone --filter=blob:none https://github.com/HyDE-Project/HyDE)
git diff aceb94ee origin/master -- Scripts Configs/.local/lib/hyde > /tmp/upstream.patch

# in this repository, on a branch
git apply --reject /tmp/upstream.patch      # applies what fits, writes *.rej for the hunks that do not
git status --short                          # look for the *.rej files and fix them by hand, then delete them
```

Measured on 2026-10-15 against HyDE `master` (`fa2fd57a`, 154 commits after `aceb94ee`, tip dated 2026-10-03):
the diff of those two paths is 52 files and 178 hunks (the whole tree: 126 files); `git apply --reject` applied
42 files, skipped 3 that hyde-lite removed (`Scripts/dots-groups/notification-daemon.toml`, `Scripts/dots/swaync.toml`,
`Scripts/dots/waybar.toml`, which is the right outcome) and rejected 3 hunks in 3 files
(`Configs/.local/lib/hyde/color.set.sh`, `Scripts/dots-groups/extra.toml`, `Scripts/dots/deps.toml`: the lines this
file's table above says were cut). `git apply --3way` is not usable: the base blobs are not in this repository.
NOT TESTED: that the result installs; after porting, run `tools/check.sh` and the installer on a clean Arch system,
and move the base in this file and in `CONTRIBUTING.md` to the upstream commit you ported up to.

## Testing

The installer and the timings are checked on a clean Arch system (a VM, or a cloud session that can reach the Arch mirrors).

`tools/vm-test.sh` does that run on the owner's machine and collects the logs: it boots the Arch cloud image
with cloud-init, sends either a git ref or the local working tree, runs `./install.sh`, then runs its own
checks. `--gui` opens a window, `--boot` brings the installed disk back up to look at the login screen.
Nothing about it needs root, and the base image is cached, never written to.
