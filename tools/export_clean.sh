#!/usr/bin/env bash
# Make a clean copy of this repository for publishing as a NEW repository: the committed files of HEAD, no history, no
# untracked or ignored files, checked for secrets and personal data. It does not commit or push anything.
#
#   bash tools/export_clean.sh DEST                    DEST must not exist, or be empty
#   bash tools/export_clean.sh --without-internal DEST also leave out docs/internal (the maintainer's work notes)
#
# Why a fresh tree and not this history: 23 of the hyde-lite commits carry a personal e-mail address as author and
# the history is about 1 GB (HyDE's). See docs/internal/PUBLISHING.md.
set -euo pipefail

internal=1
while [ $# -gt 0 ]; do
    case $1 in
    --without-internal) internal=0 ;;
    -h | --help) sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    -*) echo "export_clean: unknown option $1" >&2; exit 2 ;;
    *) dest=${dest:-$1} ;;
    esac
    shift
done
[ -n "${dest:-}" ] || { echo "usage: bash tools/export_clean.sh [--without-internal] DEST" >&2; exit 2; }

root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
cd "$root"
git diff --quiet && git diff --cached --quiet || { echo "export_clean: the working tree has uncommitted changes; commit or stash them first" >&2; exit 1; }
if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
    echo "export_clean: $dest exists and is not empty" >&2; exit 1
fi
mkdir -p "$dest"
dest=$(cd "$dest" && pwd)
case $dest/ in "$root"/*) echo "export_clean: DEST must be outside this repository" >&2; exit 1 ;; esac

git archive --format=tar HEAD | tar -x -C "$dest"
if [ "$internal" = 0 ]; then
    rm -rf "$dest/docs/internal"
    sed -i '/(docs\/internal\/)/d' "$dest/README.md"   # the README table row that links the folder
fi
if [ "$internal" = 0 ] && grep -rn "docs/internal" "$dest" --include='*.md' -l | grep -q .; then
    echo "note: these files still mention docs/internal in text (not as links); edit them before publishing:"
    grep -rn "docs/internal" "$dest" --include='*.md' | sed "s#^$dest/#  #" | cut -c1-140
fi
echo "exported $(git -C "$root" rev-parse --short HEAD) to $dest ($(find "$dest" -type f | wc -l) files, $(du -sh "$dest" | cut -f1))"

echo "== scan for secrets and personal data"
python3 -I "$dest/tools/scan_publish.py" "$dest"

echo "== the repository's own checks, on the copy"
git -C "$dest" init -q -b main
git -C "$dest" add -A
(cd "$dest" && bash tools/check.sh) || { echo "export_clean: the checks failed on the copy" >&2; exit 1; }
rm -rf "$dest/.git"

cat <<MSG

Clean copy ready in $dest (no .git). To publish it as a new repository, once, with the identity you want shown:

  cd "$dest"
  git init -b main
  git add -A
  git -c user.name="YOUR NAME" -c user.email="ID+USERNAME@users.noreply.github.com" commit -m "Initial commit: hyde-lite, a fork of HyDE (GPL-3.0)"
  git remote add origin git@github.com:YOU/NEW-REPO.git
  git push -u origin main

Then on GitHub: turn on private vulnerability reporting (SECURITY.md points to it), add topics, and replace the old
repository name in README.md. Keep LICENSE, CREDITS.md and THIRD_PARTY.md: the licence requires it.
MSG
