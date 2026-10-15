#!/usr/bin/env bash
# Turn on the repository's git hooks (tools/git-hooks): after a `git pull` the installed island is updated from
# this checkout by tools/sync_shell.py (a backup first, nothing deleted). One-time, safe to repeat.
#
#   bash tools/install_hooks.sh            turn on
#   bash tools/install_hooks.sh --off      turn off again
set -euo pipefail
root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
cd "$root"
current=$(git config --local --get core.hooksPath || true)
if [ "${1:-}" = --off ]; then
    if [ "$current" = tools/git-hooks ]; then git config --local --unset core.hooksPath; echo "hooks off"; else echo "hooks were not on"; fi
    exit 0
fi
if [ -n "$current" ] && [ "$current" != tools/git-hooks ]; then
    echo "core.hooksPath is already set to '$current'; not changing it. Call tools/git-hooks/post-merge from your own hook instead." >&2
    exit 1
fi
chmod +x tools/git-hooks/post-merge tools/git-hooks/post-rewrite
git config --local core.hooksPath tools/git-hooks
echo "hooks on: after git pull, the installed island is updated from this checkout."
echo "  skip once:  HYDE_LITE_NO_SYNC=1 git pull"
echo "  turn off:   bash tools/install_hooks.sh --off"
