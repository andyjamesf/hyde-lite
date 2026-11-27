#!/usr/bin/env bash
# Builds third-party/thunar-hyde-lite (Thunar with hyde-lite's selection and spacing changes), installs it over
# the distribution's thunar, and sets the file manager's defaults.
#
# install.sh runs this on every install. It builds only when the recipe's pkgver-pkgrel differs from what is
# installed; a build needs the network and a few minutes. When it fails, the distribution's Thunar stays (or is
# installed), so the machine always has a file manager. The defaults are set once: what the user changes later
# is never overwritten.
set -uo pipefail

self=$(realpath "${BASH_SOURCE[0]}")
src=$(dirname "$(dirname "$self")")/third-party/thunar-hyde-lite
state=${XDG_STATE_HOME:-$HOME/.local/state}/hyde-lite
marker=$state/thunar-defaults.applied
# A relative XDG_CACHE_HOME is ignored, as the XDG specification says.
cache=${XDG_CACHE_HOME:-}
[[ $cache == /* ]] || cache=$HOME/.cache
build=$cache/hyde-lite/thunar-build
dry=${flg_DryRun:-0}

# "[err]" is one of the markers install.sh looks for in a step's output.
err() { echo "[err] thunar: $*"; }

set_defaults() {
    local entry name type value
    for entry in \
        "last-separator-position int 210" \
        "shortcuts-icon-size string THUNAR_ICON_SIZE_16" \
        "misc-symbolic-icons-in-sidepane bool true" \
        "last-menubar-visible bool false" \
        "last-statusbar-visible bool false"; do
        read -r name type value <<<"$entry"
        xfconf-query -c thunar -p "/$name" -n -t "$type" -s "$value" || return 1
    done
}

# Run again by apply_defaults inside a private session bus.
if [[ ${1:-} == --set-defaults ]]; then
    set_defaults
    exit
fi

apply_defaults() {
    [[ -f $marker ]] && return 0
    if [[ $dry == 1 ]]; then
        echo "would set Thunar's defaults"
        return 0
    fi
    # Without a session bus (an install from a console) one private bus serves all the settings.
    local bus=()
    [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || bus=(dbus-run-session --)
    if "${bus[@]}" bash "$self" --set-defaults; then
        { mkdir -p "$state" && : >"$marker"; } || { err "defaults applied, but $marker cannot be written"; return 1; }
        echo "Thunar's defaults set"
    else
        err "could not set the defaults; the next install tries again"
        return 1
    fi
}

install_package() {
    local want installed package
    # shellcheck disable=SC1091
    want=$(source "$src/PKGBUILD" && printf '%s-%s' "${pkgver:?}" "${pkgrel:?}") || { err "cannot read $src/PKGBUILD"; return 1; }
    installed=$(pacman -Q thunar-hyde-lite 2>/dev/null | awk '{print $2}')
    if [[ $installed == "$want" ]]; then
        echo "thunar-hyde-lite $want is up to date"
        return 0
    fi
    if [[ $dry == 1 ]]; then
        echo "would build and install thunar-hyde-lite $want"
        return 0
    fi
    # makepkg comes with pacman; the compiler and the other build tools come with base-devel.
    if ! pacman -Q base-devel >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm base-devel || { err "could not install base-devel"; return 1; }
    fi
    rm -rf "$build"
    { mkdir -p "$build" && cp "$src/PKGBUILD" "$src/thunar-hyde-lite.patch" "$build/"; } || { err "cannot write $build"; return 1; }
    (cd "$build" && PKGDEST=$build BUILDDIR=$build/work SRCDEST=$build makepkg -s -f -c --noconfirm) ||
        { err "the build failed (its files are in $build)"; return 1; }
    local files=("$build/thunar-hyde-lite-$want"-*.pkg.tar*)
    package=${files[0]}
    [[ -f $package ]] || { err "the build produced no package in $build"; return 1; }
    # --ask 4 accepts the removal of the conflicting "thunar", which --noconfirm alone refuses.
    sudo pacman -U --noconfirm --ask 4 "$package" || { err "could not install $package"; return 1; }
    rm -rf "$build"
    echo "thunar-hyde-lite $want installed (open Thunar windows use it after 'thunar -q')"
}

# wallpaper-palette skips a run for a wallpaper it has already rendered, so a machine that only received the new
# template and stylesheet needs a forced one. Before the first wallpaper there is nothing to render yet.
render_colours() {
    local gtk=$HOME/.config/gtk-3.0 palette
    [[ $dry == 1 ]] && return 0
    grep -qs thunar.css "$gtk/gtk.css" && grep -qs m3_primary_container "$gtk/wallpaper.css" && return 0
    palette=$(command -v wallpaper-palette) || palette=$HOME/.local/bin/wallpaper-palette
    [[ -x $palette ]] || return 0
    "$palette" apply --force >/dev/null 2>&1 || echo "thunar: its colours follow at the next wallpaper change"
}

rc=0
if ! install_package; then
    rc=1
    # pacman -Q also answers for a package that provides thunar.
    pacman -Q thunar >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm thunar || err "no file manager installed"
fi
apply_defaults || rc=1
render_colours
exit "$rc"
