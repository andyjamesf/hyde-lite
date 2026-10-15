# Credits

hyde-lite exists because of [HyDE](https://github.com/HyDE-Project/HyDE) and the people behind it.
Licences are in the repositories referenced here; [`THIRD_PARTY.md`](THIRD_PARTY.md) says what in this
repository comes from where.

## HyDE and its contributors

hyde-lite is a fork of HyDE, cut at upstream commit `aceb94ee`, and keeps HyDE's GPL-3.0 licence.
HyDE's contributors are listed in the
[upstream repository](https://github.com/HyDE-Project/HyDE/graphs/contributors).

## Libraries and tools bundled with HyDE

- [xdg-terminal-exec](https://github.com/Vladimir-csp/xdg-terminal-exec) - reference implementation of the XDG Default Terminal Execution Specification, bundled in `Configs/.local/lib/hyde/`
- Third-party code with its own notice (fzf wrapper, argparse.lua, json.lua, xdg_base_dirs.py, a shader) is listed in [`THIRD_PARTY.md`](THIRD_PARTY.md)
- [app2unit](https://github.com/Vladimir-csp/app2unit) - launches desktop entries as systemd user units (used through `hyde-shell app`; installed, not bundled)

All packages installed via the package manager are referenced in:

- [Core packages](./Scripts/pkg_core.lst)
- [Extra packages](./Scripts/pkg_extra.lst)

## Built on

- [HyDE](https://github.com/HyDE-Project/HyDE), a continuation of [hyprdots](https://github.com/prasanthrangan/hyprdots) by @prasanthrangan / @Tittu
- [Hyprland](https://hyprland.org) and [Quickshell](https://quickshell.org) for the compositor and the shells
- [matugen](https://github.com/InioX/matugen) for the colour pipeline

## Inspirations

- Derived hyprlock ideas, from [MrVivekRajan/Hypr-Dots](https://github.com/MrVivekRajan/Hypr-Dots) (as credited by HyDE)

---

If something is missing or wrong here, please open an issue or a pull request.
