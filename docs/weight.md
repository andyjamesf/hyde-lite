# What hyde-lite weighs

Measured on 2026-10-14 with the commands shown. "Tracked" means files in the git tree, not what ends up
installed.

## The repository

```sh
git ls-tree -r -l <commit> | awk '{s+=$4; n++} END {printf "%d files, %.1f MiB", n, s/1048576}'
```

| | Files | Size |
|---|---|---|
| Before the open-source clean-up (`07cabddc`) | 979 | 128.4 MiB |
| After it | 886 | 55.0 MiB |
| Now (README screenshots, logo and banner added; unused and unlicensed assets removed) | 902 | 45.0 MiB |

What the 45 MiB are now (by top-level directory, tracked bytes; `git ls-files` summed):

| Directory | MiB | What |
|---|---|---|
| `Configs` | 20.7 | `.local/bin/hydectl` (12.8) and `hyde-ipc` (2.7), prebuilt binaries from upstream; HyDE's library and data; the two shells 1.5 |
| `docs` | 15.6 | the README screenshots, the logo and the banner (`docs/images`) |
| `Source` | 8.1 | `arcs` 7.6: the SDDM themes (`Sddm_Candy` 6.0), the wallbash GTK and icon themes, a Spotify theme; `misc` 0.4 |
| `Wallpapers` | 0.2 | 7 generated pixel-art wallpapers |

The biggest single files are `hydectl` (12.8 MiB), `Sddm_Candy.tar.gz` (6.0), `hyde-ipc` (2.7) and the README
screenshots (about 2 each). Candidates for a further diet, none done because each is upstream's and would be a
porting conflict (see `CONTRIBUTING.md`):

- `Configs/.local/bin/hydectl` and `hyde-ipc`: prebuilt Rust binaries committed upstream. A public repository
  that ships binaries should say where their source is (HyDE-Project) or build them in the installer instead.
- `Source/arcs/Sddm_Candy.tar.gz`: only used with `--interactive`.
- The README images could be recompressed (`oxipng`), they are screenshots at 1920 px.

Removed on 2026-10-15: six fastfetch logos (2 MiB) and five archives nothing reads (21 MiB), see `THIRD_PARTY.md`.

## The git history

```sh
git count-objects -vH            # size-pack
git rev-list --count HEAD
```

This repository has one commit and no earlier history (see `LITE.md`, "History"). Measured on 2026-10-15 with
`time git clone https://github.com/andyjamesf/hyde-lite` into an empty directory: 2.2 s, `size-pack` 32.31 MiB,
1 commit, 1058 objects; `.git` is 33 MiB and the working tree 48 MiB. The README's install steps use a plain
clone, and `git clone --depth 1` gives the same result here. HyDE's own history is about 1 GiB (mostly old
wallpapers) and is not part of this repository.

## What gets installed

Package counts (`grep -vcE '^\s*(#|$)'`): `Scripts/pkg_core.lst` 76 entries, `Scripts/pkg_extra.lst` 19, plus the
dependencies named in `Scripts/dots/*.toml`. NOT MEASURED: installed size on disk and cold install time, which need a
real Arch system.
