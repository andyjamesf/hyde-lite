# HyDE LiTE

A branch of HyDE with what a Quickshell setup does not need taken out, and one change to make
colour changes faster. It is meant to be rebased on upstream: every cut is a line removed from a list,
not an edit inside a script, so an update brings few conflicts.

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
| `Scripts/pkg_core.lst` (addition) | `ttf-jetbrains-mono-nerd`: the island's icon font (and the login screen's, which copies it) used to come only from an archive download that lite does not run, so the icons showed as boxes on a clean install |
| `Scripts/install.sh` | the six `cat <<"EOF"` ASCII banners became `banner <<"EOF"`, and a `banner` function skips them when `HYDE_LITE` is set (the lite installer prints its own header and step titles). Run alone, the script prints them as before. One word per banner, so a rebase conflict is one line |
| `Configs/.local/lib/hyde/color.set.sh` | GNU `parallel` replaced by `xargs -P` when rendering the wallbash templates |
| `Configs/.local/share/wallbash/` | no `always/dunst.dcol`, `scripts/dunst.sh`, `scripts/swaync.sh`, `theme/swaync.dcol`: they render into configs of apps lite does not install, and `tests/python/check_wallbash_targets.py` fails on them |
| `dotfiles` submodule, `.gitmodules` entry | removed (the edition's gitlink to the private the owner's private dotfiles repository): CI could not clone it. D1 is still open; the root `install.sh` and `README.md` from the edition still refer to `dotfiles/` until they are decided |
| `install.sh` (repository root) | removed (the edition's stopgap, which cloned the earlier combined repository and the `dotfiles` submodule); the one-command installer is PLAN 5.1, now a new `install.sh` for a generic PC (a wrapper that runs `Scripts/install.sh` in separate steps; see the `Scripts/install.sh` row for its one edit) |
| `README.md` and documentation | `README.md` is rewritten for hyde-lite (upstream's is in the upstream repository). Removed 2026-10-14 (owner asked for a clean-up): the translated READMEs, keybinding lists and Hyprdots-to-HyDE notes under `Source/docs` and `Source/assets/keybinds`, and from the root `Hyprdots-to-HyDE.md`, `README.edition.md`, `MIGRATION-LUA.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CONTRIBUTORS.md`, `COMMIT_MESSAGE_GUIDELINES.md`, `RELEASE_POLICY.md`, `TEAM_ROLES.md`, `TESTING.md` (upstream's contribution and release process, which does not apply here). Every one is a delete/modify conflict to resolve by deleting on a rebase. `.github/PULL_REQUEST_TEMPLATE.md` is replaced by a short lite template, and `CREDITS.md` is rewritten (upstream's first-person text and its Ko-fi section are gone, the HyDE and hyprdots credit and the contributors link stay), and `THIRD_PARTY.md` is new: what is original, what is HyDE's, which files carry another project's notice, and which shipped assets have an unverified licence. Kept: `KEYBINDINGS.md` (referenced from `hyprland.lua`), `CREDITS.md`, `LICENSE`, and the READMEs inside the shells, `Scripts/hydevm`, wallbash and the config schema. `.github/scripts/promote_to_*.sh` and `warn-master-pr.yml` still name the removed files in message text; they belong to upstream's release flow |
| removed apps' configs | deleted (owner asked 2026-10-13): `Configs/.config/{waybar,swaync,dunst,rofi}`, `Configs/.local/share/{waybar,hyde/rofi}`, their dots (`Scripts/dots/{waybar,rofi,wlogout,dunst,swaync}.toml`), the `notification-daemon` group and the includes in `dots.toml`. 247 upstream files; each upstream change to them is now a delete/modify conflict to resolve by deleting. Still present: `Configs/.config/wlogout` (the upstream `test_monitor_scale` reads its layout and style, so removing it turns CI red), and the `Configs/.local/lib/hyde` helpers that mention rofi (`rofiselect.sh` and others), left because other scripts call them, and the commented rofi binds in `key_binds.lua` |
| `Configs/.local/share/hypr/lua/key_binds.lua` | `F10`/`F11`/`F12` volume binds and the `SUPER (+ SHIFT) + KP_*` workspace 11-20 binds restored after the edition's cleanup (`4d31761`) removed them: the upstream bind test requires them |
| `.github/` | removed 2026-10-14 for the public release: upstream's release flow (`workflows/{ci,test,lock,refresh-release,warn-master-pr}.yml`, `scripts/promote_*`, `remind-release.py`), `FUNDING.yml` (upstream's Ko-fi), `renovate.json5`, `codecov.yml`, `.all-contributorsrc`, and two issue templates. Added: a small `workflows/ci.yml` (checks, unit tests, shellcheck, ruff, luacheck, markdownlint, gitleaks, actionlint), `ISSUE_TEMPLATE/config.yml`, and rewritten bug and feature templates. Every one is a delete/modify conflict to resolve by deleting on a rebase |
| `tests` submodule, `.gitmodules` | removed: it pointed at `HyDE-Project/tests`, which tests upstream's own wallbash targets and waybar/rofi-era scripts. hyde-lite's tests are `tools/tests/` (run by `tools/check.sh`) |
| `Source/assets/` | removed (35 MiB): upstream's README screenshots and logos of waybar, rofi and wlogout setups that lite does not install. `KEYBINDINGS.md` lost its banner, distro logos, dead translation links and external heading images; its text is unchanged |
| `Configs/.config/fastfetch/logo/` | six logos of anime characters removed (2 MiB, origin unknown); `hyprland.icon` stays. `fastfetch.sh logo` picks a random `*.icon` from that folder, so one is enough |
| `Source/arcs/` | `Grub_Pochita`, `Grub_Retroboot`, `Steam_Metro`, `Firefox_Extensions` and `Firefox_UserConfig` removed (21 MiB): nothing in hyde-lite's installer reads them. `Scripts/install_pre.sh` (GRUB themes, not run by lite) and `Scripts/extra/restore_app.sh` (Firefox, an optional extra) still name them and are left alone, so running those would fail on the missing archive. Kept: `Sddm_Corners` (default), `Sddm_Candy` (`--interactive`), `Gtk_Wallbash`, `Icon_Wallbash`, `Spotify_Sleek` |
| `Wallpapers/` | the 30 images taken from community themes (licences unchecked) are replaced by 7 original pixel-art wallpapers generated by `tools/gen_wallpapers.py` (CC0); `Scripts/dots/wallpapers.toml` description updated |
| `Configs/.config/hyde/wallbash/scripts/cava.sh` | one comment line removed: a `shellcheck source=` hint naming another author's home directory (the next line already disables SC1091) |
| `.luacheckrc`, `.gitignore` | new / rewritten (the old `./.*` pattern never matched anything) |
| colour pipeline | new, additive: `Scripts/dots/colour.toml` deploys `wallpaper-palette`, `wallpaper-library`, `wallbash-matugen`, `Configs/.config/matugen`, a fontconfig rule, and the `matugen.dcol` / `quickshell.dcol` wallbash templates (under `Configs/.config/hyde/wallbash/always`). Copied unchanged from the owner's private dotfiles repository at `213c2a5`, together with that commit range's shell updates (`PickPalette.qml`, `Theme.qml`, `Config.qml`, island `Palettes.qml`). No upstream HyDE file is edited |

## The Quickshell Edition commits

The 19 code commits of the earlier combined repository (`origin/edition`, `git log aceb94ee..origin/edition
--no-merges`, without the `dotfiles: <sha>` bumps) are cherry-picked with `-x`, so each message names its
source. Two conflicts, both resolved by keeping the lite cuts: `core.toml` and `pkg_core.lst` lost the
edition's `rofi` lines. One follow-up commit adds `python` to `pkg_core.lst` (the shell's calendar reader;
`quickshell.toml` already had it) and fixes the comment in `quickshell.toml` that said rofi stays installed.
The edition's shell copy under `Configs/.config/quickshell/` is stale and is replaced when the shells are
imported (PLAN 1.2).

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

## Not tested

- A clean install on a barebones Arch. `deez deps --check` and the shell scripts were exercised on a
  machine that already had HyDE, not from nothing. Use a VM (`Scripts/hydevm`) before trusting it.
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

To follow upstream (`upstream` is HyDE itself and pushing to it is disabled; `origin` is this repository):

```
git fetch upstream && git rebase upstream/master
```

This branch was cut from upstream `aceb94e`, the commit the owner's `hyde.lock` pins. Upstream has moved on
since (it was 154 commits ahead when this repository was created), so rebasing is a deliberate step, not
something to do blindly: re-run the installer and the timing checks on a clean Arch system afterwards.

## Testing

The installer and the timings are checked on a clean Arch system (a VM, or a cloud session that can reach the Arch mirrors).
