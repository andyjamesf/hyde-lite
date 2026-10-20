#!/usr/bin/env bash
# Installs hydectl, HyDE's command-line tool (themes, wallpapers, `hydectl theme next|prev|import`), from
# HyDE-Project's GitHub release instead of from a 13 MiB binary committed here. The tarball is checked against
# a SHA-256 pinned below, so a changed or tampered release is refused, not installed.
#
#   Scripts/install_hydectl.sh            install or update ~/.local/bin/hydectl
#
# Repeatable: nothing is downloaded when the pinned release is already installed. Environment, for tests:
# HYDECTL_URL, HYDECTL_SHA256 and HYDECTL_BIN replace the release URL, its checksum and the target.
set -uo pipefail

version=26.0.0
case "$(uname -m)" in
x86_64) arch=amd64 sha256=648b962e6b2dbde10a5ee1cd6c258c232ff6a828ea9d5024ef1cc1099a6877bd ;;
aarch64 | arm64) arch=arm64 sha256=ad2adca715b0e64f77ac4ea20cc86561e3530b73e6eff5157f03f1dc882db2be ;;
*)
    echo "[err] hydectl has no release for $(uname -m)" >&2
    exit 1
    ;;
esac
name=hydectl-$version-linux-$arch
url=${HYDECTL_URL:-https://github.com/HyDE-Project/hydectl/releases/download/v$version/$name.tar.gz}
sha256=${HYDECTL_SHA256:-$sha256}
bin=${HYDECTL_BIN:-$HOME/.local/bin/hydectl}
stamp=${bin}.sha256

if [[ -x $bin && -f $stamp && $(cat "$stamp") == "$sha256" ]]; then
    echo "hydectl $version is already installed"
    exit 0
fi

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
echo "Downloading hydectl $version ($arch)"
if ! curl -fsSL --retry 3 -o "$tmp/hydectl.tar.gz" "$url"; then
    echo "[err] could not download $url" >&2
    exit 1
fi
if ! echo "$sha256  $tmp/hydectl.tar.gz" | sha256sum -c --status; then
    echo "[err] hydectl: the download does not match the pinned checksum, not installing it" >&2
    exit 1
fi
mkdir "$tmp/x"
if ! tar -xzf "$tmp/hydectl.tar.gz" -C "$tmp/x"; then
    echo "[err] hydectl: could not unpack the archive" >&2
    exit 1
fi
src=$(find "$tmp/x" -maxdepth 1 -type f -name 'hydectl*' ! -name '*.md' | head -n 1)
if [[ -z $src ]]; then
    echo "[err] hydectl: no executable in the archive" >&2
    exit 1
fi
mkdir -p "$(dirname "$bin")"
if ! { install -m 0755 "$src" "$bin.new" && mv -f "$bin.new" "$bin" && echo "$sha256" >"$stamp"; }; then
    echo "[err] hydectl: could not write $bin" >&2
    exit 1
fi
echo "hydectl $version installed in $bin"
