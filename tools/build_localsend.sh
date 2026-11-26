#!/usr/bin/env bash
# Builds third-party/localsend-cli and installs it as ~/.local/bin/localsend-cli, where
# quickshell/shared/services/LocalSend.qml looks for it. It is our fork, with the `receive` mode the shells need,
# so the distribution's localsend package cannot stand in for it.
#
# install.sh runs this on every install. It builds only when the source changed or the binary is missing. A build
# needs the network (crates) and takes a few minutes; its directory (hundreds of MB) is removed afterwards.
# Rust is installed only when there is no cargo, so a machine with rustup keeps its own.
set -euo pipefail

root=$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")
src=$root/third-party/localsend-cli
dest=$HOME/.local/bin/localsend-cli
stamp=${XDG_STATE_HOME:-$HOME/.local/state}/hyde-lite/localsend-cli.source
# A relative XDG_CACHE_HOME is ignored, as the XDG specification says: the build runs from $src.
cache=${XDG_CACHE_HOME:-}
[[ $cache == /* ]] || cache=$HOME/.cache
build=$cache/hyde-lite/localsend-build

# "[err]" is one of the markers install.sh looks for in a step's output.
fail() { echo "[err] localsend-cli: $*"; exit 1; }

# One hash over the sources. Documentation does not change the binary.
want=$(cd "$src" && find . -path ./target -prune -o -type f ! -name '*.md' -print0 | LC_ALL=C sort -z |
    xargs -0 sha256sum | sha256sum | cut -d' ' -f1) || fail "cannot read $src"

if [[ -x $dest && -f $stamp && $(cat "$stamp") == "$want" ]]; then
    echo "localsend-cli is up to date ($dest)"
    exit 0
fi
if [[ ${flg_DryRun:-0} == 1 ]]; then
    echo "would build $src and install it as $dest"
    exit 0
fi
if ! command -v cargo >/dev/null; then
    sudo pacman -S --needed --noconfirm rust || fail "could not install rust"
fi
(cd "$src" && CARGO_TARGET_DIR=$build cargo build --release --locked -p localsend-cli) ||
    fail "the build failed (with rustup, check that a toolchain is set: rustup default stable)"
mkdir -p "$(dirname "$dest")" "$(dirname "$stamp")"
# Renamed into place, so a receiver that is running keeps the file it started from.
install -m755 "$build/release/localsend-cli" "$dest.new"
mv -f "$dest.new" "$dest"
# The stamp is written last: a run interrupted before this builds again and cleans up.
rm -rf "$build"
echo "$want" >"$stamp"
echo "localsend-cli installed in $dest (a running shell uses it after it restarts)"
