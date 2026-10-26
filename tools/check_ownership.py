#!/usr/bin/env python3
"""Say which files a dotfiles checkout and this repository both own.

hyde-lite deploys files by copying them (Scripts/dots/*.toml: `sync` overwrites, `preserve` leaves a
file the owner already has). A dotfiles repository links files into $HOME with stow. When both name
the same path the result depends on which ran last, and a `sync` can write through a stow symlink
into the other repository. The rule is one owner per file, so this lists every shared path:

  duplicate   identical, and hyde-lite's action is `sync`: delete it from the dotfiles
  pinned      identical, and the action is `preserve`: harmless, the owner keeps their own copy
  override    differs, and the action is `preserve`: the owner's version is meant to win
  CONFLICT    differs, and the action is `sync`: hyde-lite will overwrite the owner's version
              (through the stow symlink, into the dotfiles repository)

    python3 tools/check_ownership.py ~/dotfiles          report; exit 1 on a duplicate or a conflict
"""
import pathlib
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV = {"${HOME}": "", "${XDG_CONFIG_HOME}": "/.config", "${XDG_DATA_HOME}": "/.local/share",
       "${XDG_STATE_HOME}": "/.local/state", "${XDG_CACHE_HOME}": "/.cache"}


def target_dir(text):
    for k, v in ENV.items():
        text = text.replace(k, v)
    return text.strip("/")


def deployed(root=ROOT):
    """{path relative to $HOME: (toml name, action)} for every file the .toml files copy."""
    out = {}
    for toml in sorted((root / "Scripts/dots").glob("*.toml")):
        for group in tomllib.loads(toml.read_text(encoding="utf-8")).values():
            if not isinstance(group, dict):
                continue
            for entry in group.get("files", []):
                if "source_root" not in entry:
                    continue
                paths = entry["paths"]
                paths = [paths] if isinstance(paths, str) else paths
                src_root = root / entry["source_root"]
                for p in paths:
                    src = src_root / p
                    files = [src] if src.is_file() else sorted(x for x in src.rglob("*") if x.is_file())
                    for f in files:
                        rel = f.relative_to(src_root)
                        out[str(pathlib.PurePosixPath(target_dir(entry["target_root"])) / rel)] = (
                            toml.name, entry.get("action", "sync"), f)
    return out


def owned(dotfiles):
    """{path relative to $HOME: file} for everything the dotfiles repository stows."""
    out = {}
    bases = [dotfiles / "shared/home", dotfiles / "shared/home-folded"]
    bases += sorted((dotfiles / "machines").glob("*/home")) + sorted((dotfiles / "machines").glob("*/home-folded"))
    for base in bases:
        for f in base.rglob("*"):
            if f.is_file():
                out[str(f.relative_to(base))] = f
    return out


def classify(root, dotfiles):
    mine, ours = owned(dotfiles), deployed(root)
    rows = []
    for rel in sorted(set(mine) & set(ours)):
        toml, action, src = ours[rel]
        same = src.read_bytes() == mine[rel].read_bytes()
        if same:
            kind = "pinned" if action == "preserve" else "duplicate"
        else:
            kind = "override" if action == "preserve" else "CONFLICT"
        rows.append((kind, rel, toml, action))
    return rows


def main(argv):
    if len(argv) != 2:
        sys.exit(__doc__)
    rows = classify(ROOT, pathlib.Path(argv[1]).expanduser())
    for kind, rel, toml, action in rows:
        print("%-9s %-45s %s (%s)" % (kind, rel, toml, action))
    bad = [r for r in rows if r[0] in ("duplicate", "CONFLICT")]
    print("%d shared, %d need attention" % (len(rows), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
