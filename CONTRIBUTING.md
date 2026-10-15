# Contributing to hyde-lite

Thanks for taking an interest. hyde-lite is a small fork of [HyDE](https://github.com/HyDE-Project/HyDE)
with two Quickshell shells. It stays small on purpose, so the best contributions fix something, remove
something or make something easier to understand.

## Before you start

- **Open an issue first for anything bigger than a fix.** A feature has to earn its weight: say what it
  replaces or why it is worth the extra code.
- **Hardware belongs under `machines/<name>/`, nowhere else.** The installer must work on an unknown PC.
- **Colour comes from matugen only.** `theme.mode` and `theme.scheme` are the single source; HyDE's own
  `enableWallDcol` is written from them.

## Keep the difference from upstream small

This repository is HyDE at commit `aceb94ee` plus the changes listed in [`LITE.md`](LITE.md). Every edit to
HyDE's own code (`Scripts/`, `Configs/.local/lib/hyde/`) is a future rebase conflict, so:

- prefer removing a line from a list over editing the middle of an upstream script;
- put the reason in a comment next to the change;
- add a row to `LITE.md` saying what changed and why.

The two shells (`Configs/.config/morphing-island`, `Configs/.config/quickshell`), the colour pipeline and the
installer wrapper are this project's own; change them freely.

## Running the checks

```sh
bash tools/check.sh
```

This runs shell syntax checks, `py_compile`, TOML/JSON validation, the bar-layout validator, the unit tests
in `tools/tests/` and (when Qt 6.5+ is installed) `qmllint`. CI runs the same plus `shellcheck`, `ruff`,
`luacheck`, `markdownlint` and a secret scan. Please run it before opening a pull request.

Unit tests are plain `unittest` files, run on their own with `python3 -I tools/tests/test_<name>.py`.

### The qmllint baseline

`tools/qml-lint.sh` counts qmllint warnings per shell and category and compares them with
`tools/qml-lint.baseline`. A count that grows past its number fails the check. `tools/qml-lint.sh --since` lists
the new warnings with file, line and column, so you can fix what you added.

- Lower a number when you fix something; never raise one to make the check pass.
- The one exception is an increase the maintainer has decided to accept (for example a warning that every window
  or every singleton file gets). It is written into the baseline as a `#!` line giving the date, the entry
  (`FROM->TO`), the file and why it is inherent and how it could go, and `tools/tests/test_qml_baseline.py` checks
  that the record and the numbers agree. `tools/qml-lint.sh --baseline` keeps those lines when it rewrites the file.
- qmllint 6.5 or newer (and the `quickshell` package) is needed; CI runs it on Arch. Older versions skip the check.

## Pull requests

- Branch from `main`, one topic per pull request, small is better.
- Describe **what changed and why**, and give the **command and output** behind any claim ("faster",
  "fixes", "works"). If you could not test something, say so under **NOT TESTED**, with the reason.
- Anything visual should say whether you saw it on a screen, and attach a screenshot if you did.
- No secrets, tokens or personal paths in commits. The history is public and permanent.
- Write code, comments, docs and commit messages in English.

## Screenshots

`docs/images/README.md` lists the screenshots the README wants. `tools/screenshots.sh` takes them in a real
Wayland session; no personal data on screen, please.

## Licence

By contributing you agree that your contribution is licensed under the GPL-3.0, like the rest of the project.
