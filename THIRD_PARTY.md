# Third-party material and licences

hyde-lite is a fork of [HyDE](https://github.com/HyDE-Project/HyDE) and is distributed under the
**GNU General Public License v3.0** ([`LICENSE`](LICENSE)), the same licence as HyDE. This page says what
in the repository comes from where. It was written by reading the files in this repository on 2026-10-14;
where something could not be checked it says so.

## Original to hyde-lite

- The Morphing Island and the bar shell (`Configs/.config/morphing-island`, `Configs/.config/quickshell`), the
  colour pipeline (`Configs/.local/bin/wallpaper-palette`, `wallbash-matugen`, `wallpaper-library`,
  `Configs/.config/matugen`), the installer wrapper (`install.sh`), `tools/` and the documentation: GPL-3.0.
- `Wallpapers/`, the README logo (`docs/images/logo.gif`) and the Island banner (`docs/images/banner.gif`), generated
  by `tools/gen_wallpapers.py`, `tools/gen_logo.py` and `tools/gen_banner.py`, and the pixel-art code in those scripts:
  released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) as well as GPL-3.0.

The animated banner (`docs/images/banner.gif`, made by `tools/gen_banner.py`) is an image: its text is set in
[Inter](https://rsms.me/inter/) (SIL Open Font Licence 1.1), which permits embedding the rendered glyphs. The font
file itself is not part of this repository.

## From HyDE and hyprdots (GPL-3.0)

Everything else under `Scripts/`, `Configs/` and `Source/` started as HyDE's own files, cut at upstream commit
`aceb94ee`; [`LITE.md`](LITE.md) lists what was removed or changed. HyDE is a continuation of
[hyprdots](https://github.com/prasanthrangan/hyprdots) and carries the copyright of its contributors
([contributor list](https://github.com/HyDE-Project/HyDE/graphs/contributors)). Their notices are kept; do not
remove `LICENSE` or [`CREDITS.md`](CREDITS.md) when redistributing.

## Code from other projects, with its own notice in the file

Checked by reading the file headers. All of these are compatible with the GPL-3.0.

| File | Author and licence |
|---|---|
| `Configs/.local/lib/hyde/fzf_wrapper.py`, `Configs/.local/lib/hyde/pyutils/wrapper/fzf.py` | Jan Kubovy, MIT |
| `Configs/.local/lib/hyde/luautils/argparse.lua` | Peter Melnichenko, MIT |
| `Configs/.local/lib/hyde/luautils/json.lua` | rxi, MIT |
| `Configs/.local/lib/hyde/pyutils/xdg_base_dirs.py` | Scott Stevenson, ISC-style permission notice |
| `Configs/.local/lib/hyde/xdg-terminal-exec` | Vladimir Kudrya, GPL-3.0-or-later |
| `Configs/.config/hypr/shaders/oled-saver.frag` | BSD-3-Clause (stated in its header) |

## Shipped from upstream, licence NOT verified

These came with HyDE. They carry no licence file in this repository and I could not confirm their terms
from here. They are the first thing to check before a wider release.

| What | Where | Note |
|---|---|---|
| `Source/arcs/Sddm_Corners.tar.gz` | SDDM theme | Upstream's default: its installer step takes an empty answer as "Corners", and hyde-lite's installer answers every question with an empty line, so it is installed when `sddm` is present (not verified on a real install). No licence file inside |
| `Source/arcs/Sddm_Candy.tar.gz` | SDDM theme | Only used if `--interactive` is given and option 1 is chosen. No licence file inside |
| `Source/arcs/Gtk_Wallbash.tar.gz`, `Source/arcs/Icon_Wallbash.tar.gz` | GTK theme and icon set of HyDE's colour system | Used by the installer. Probably HyDE's own work, not confirmed. No licence file inside |
| `Source/arcs/Spotify_Sleek.tar.gz` | Spotify (spicetify) theme | Used by a wallbash script. No licence file inside |
| `Configs/.config/fastfetch/logo/hyprland.icon` | The Hyprland logo for fastfetch | The only logo kept; its origin is not stated in the file |
| Misc images | `Source/misc/nightTab_backdrop.jpg`, `Source/misc/tittu.face.icon` | Origin unknown |
| Prebuilt executables | `Configs/.local/bin/hydectl`, `Configs/.local/bin/hyde-ipc` | ELF binaries (13 MiB and 2.8 MiB) shipped by upstream; their source is not in this repository and I did not find where they are built from |
| Icons | `Configs/.config/wlogout/icons/*.png`, `Configs/.config/Kvantum/wallbash/wallbash.svg` | Origin unknown |

## Installed at install time, not shipped here

Packages from the Arch repositories and the AUR keep their own licences (see `Scripts/pkg_core.lst` and
`pkg_extra.lst`). The base theme "Nordic Blue" is downloaded from
[HyDE-Project/hyde-themes](https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue) and keeps that
repository's terms. Fonts come from packages.

## Removed because their licence could not be confirmed, or because nothing uses them

- The 30 wallpapers taken from community HyDE themes, replaced by generated ones (see
  [`Wallpapers/SOURCES.md`](Wallpapers/SOURCES.md)).
- Six fastfetch logos of anime characters (`aisaka`, `geass`, `loli`, `pochita`, `ryuzaki`, `agk_clan`; 2 MiB), of unknown
  origin.
- Five archives that nothing in hyde-lite's installer reads (21 MiB): `Grub_Pochita`, `Grub_Retroboot` (upstream's GRUB
  step is not run here), `Steam_Metro`, and `Firefox_Extensions` and `Firefox_UserConfig` (only an optional extra
  script, `Scripts/extra/restore_app.sh`, reads them).

Every file in `Source/arcs/` and `Configs/.config/fastfetch/logo/` has to be named on this page;
`tools/tests/test_repo_hygiene.py` checks it.
