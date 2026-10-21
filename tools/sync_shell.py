#!/usr/bin/env python3
"""Bring the installed Quickshell configuration up to date with this repository without running the installer.

    tools/sync_shell.py                 show what would change (nothing is written)
    tools/sync_shell.py --diff          ... with the differences of the changed files
    tools/sync_shell.py --apply         back up the target, then copy new and changed files
    tools/sync_shell.py --target DIR    another target (default: ~/.config/quickshell)
    tools/sync_shell.py --apply --quiet --keep 5    one summary line, and only the newest 5 backups stay

The source is Configs/.config/quickshell (shell.qml, island/, bar/). The default target is where ~/.config/quickshell
really points, so a link into a dotfiles repository is followed and the files change there.

It only ever adds and overwrites: a file that exists in the target but not here is left alone. Before the first
write the whole target is copied to a backup folder (default ~/.local/state/hyde-lite/backups/), and its path
and the command to put it back are printed. Settings (prefs.json, layouts.json) live outside these folders and are
not touched.
"""
import argparse
import datetime
import filecmp
import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
NAME = "quickshell"
SKIP_DIRS = {"__pycache__"}


def files(root):
    """Relative paths of the regular files under root, without caches."""
    out = []
    for dirpath, dirnames, names in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for n in sorted(names):
            p = Path(dirpath, n)
            if p.is_file() and p.suffix != ".pyc":
                out.append(p.relative_to(root))
    return out


def plan(src, dst):
    """(new, changed, same, only_in_target), each a sorted list of relative paths."""
    new, changed, same = [], [], []
    for rel in files(src):
        other = dst / rel
        if not other.exists():
            new.append(rel)
        elif filecmp.cmp(src / rel, other, shallow=False):
            same.append(rel)
        else:
            changed.append(rel)
    mine = set(files(src))
    extra = [r for r in files(dst) if r not in mine]
    return new, changed, same, extra


def apply(src, dst, backup):
    """Copy dst to backup, then add and overwrite files from src. Returns (new, changed)."""
    new, changed, _, _ = plan(src, dst)
    backup.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(dst, backup, symlinks=True)
    for rel in new + changed:
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, target)
    return new, changed


def prune_backups(folder, name, keep):
    """Delete the oldest backups of `name` in `folder` beyond the newest `keep`. Only real folders called
    <name>-YYYYMMDD-HHMMSS are considered; anything else in there is left alone. Returns the removed paths."""
    pattern = re.compile(rf"^{re.escape(name)}-\d{{8}}-\d{{6}}$")
    mine = sorted(p for p in folder.iterdir() if pattern.match(p.name) and p.is_dir() and not p.is_symlink())
    doomed = mine[:max(0, len(mine) - keep)]
    for p in doomed:
        shutil.rmtree(p)
    return doomed


def default_target():
    return Path(os.path.expanduser(f"~/.config/{NAME}"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--target", help=f"folder to update (default: ~/.config/{NAME}, links followed)")
    ap.add_argument("--apply", action="store_true", help="write the changes (after a backup)")
    ap.add_argument("--diff", action="store_true", help="show the differences of the changed files")
    ap.add_argument("--quiet", action="store_true", help="print one summary line instead of the file list")
    ap.add_argument("--keep", type=int, metavar="N", help="after the backup, delete older backups beyond the newest N")
    ap.add_argument("--backup-dir", help="where the backup goes (default under ~/.local/state/hyde-lite/backups)")
    args = ap.parse_args(argv)

    name = NAME
    src = REPO / "Configs/.config" / name
    given = Path(args.target) if args.target else default_target()
    if not given.exists():
        print(f"sync_shell: {given} does not exist", file=sys.stderr)
        return 2
    dst = given.resolve()
    if not dst.is_dir():
        print(f"sync_shell: {dst} is not a folder", file=sys.stderr)
        return 2
    if dst == src.resolve():
        print(f"sync_shell: the target is this repository's own copy ({dst}); nothing to do", file=sys.stderr)
        return 2

    new, changed, same, extra = plan(src, dst)
    if not args.quiet:
        print(f"from {src}\n  to {dst}" + (f"  (via {given})" if given != dst else ""))
        print(f"{len(new)} new, {len(changed)} changed, {len(same)} identical, {len(extra)} only in the target (left alone)")
        for label, lst in (("new", new), ("changed", changed), ("only in the target", extra)):
            for rel in lst:
                print(f"  {label:>18}: {rel}")
    if args.diff:
        import difflib
        for rel in changed:
            a = (dst / rel).read_text(errors="replace").splitlines(keepends=True)
            b = (src / rel).read_text(errors="replace").splitlines(keepends=True)
            sys.stdout.writelines(difflib.unified_diff(a, b, f"target/{rel}", f"repo/{rel}"))
    if not args.apply:
        if args.quiet:
            print(f"{name}: {len(new)} new, {len(changed)} changed (dry run)")
            return 0
        print("dry run: nothing written. Add --apply to copy the new and changed files (a backup is made first).")
        return 0
    if not new and not changed:
        print(f"{name}: already up to date" if args.quiet else "already up to date")
        return 0
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = Path(args.backup_dir) if args.backup_dir else Path(os.path.expanduser(f"~/.local/state/hyde-lite/backups/{name}-{stamp}"))
    apply(src, dst, backup)
    pruned = prune_backups(backup.parent, name, args.keep) if args.keep is not None else []
    if args.quiet:
        print(f"{name}: updated ({len(new)} added, {len(changed)} overwritten); backup {backup}")
        return 0
    print(f"done: {len(new)} added, {len(changed)} overwritten.\nbackup of the old folder: {backup}")
    if pruned:
        print(f"removed {len(pruned)} older backup(s), keeping the newest {args.keep}")
    print(f"to undo: cp -a {backup}/. {dst}/   (files that were added stay; remove them by hand if you want)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
