#!/usr/bin/env bash
# Take the README screenshots in a real Wayland (Hyprland) session.
#
#   tools/screenshots.sh --list              what is still missing
#   tools/screenshots.sh island-launcher     take one (counts down, then grabs the focused monitor)
#   tools/screenshots.sh --all               walk through every missing one, in order
#   tools/screenshots.sh --area NAME         pick a region with slurp instead of the whole monitor
#
# Options: --delay SECONDS (default 5), --force (replace an existing file), --no-readme (leave README.md alone).
#
# The list of shots and what each should show lives in docs/images/README.md (one source of truth).
# After a capture the image is scaled down to at most 1920 px wide, optimised if oxipng/optipng is
# installed, and its commented-out line in README.md is switched on.
#
# Needs: grim (and slurp for --area); hyprctl + jq to find the focused monitor; ImageMagick (magick or convert).
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
imgdir=$root/docs/images
spec=$imgdir/README.md
readme=$root/README.md

delay=5 force=0 area=0 touch_readme=1 mode=one name=
die() { echo "screenshots: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case $1 in
    --list) mode=list ;;
    --all) mode=all ;;
    --area) area=1 ;;
    --force) force=1 ;;
    --no-readme) touch_readme=0 ;;
    --delay) delay=${2:?--delay needs a number}; shift ;;
    -h | --help) sed -n '2,/^set -e/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) name=${1%.png} ;;
    esac
    shift
done

# Rows of the spec file that look like: | <name>.png in backticks | what to show |
# shellcheck disable=SC2016
shots() { sed -n 's/^| `\([a-z0-9-]*\)\.png` | \(.*\) |$/\1\t\2/p' "$spec"; }

[ -r "$spec" ] || die "missing $spec"

missing() {
    local n d
    while IFS=$'\t' read -r n d; do
        [ -e "$imgdir/$n.png" ] || printf '%s\t%s\n' "$n" "$d"
    done < <(shots)
}

if [ "$mode" = list ]; then
    printf '%-24s %s\n' "SHOT" "STATUS / WHAT TO SHOW"
    while IFS=$'\t' read -r n d; do
        if [ -e "$imgdir/$n.png" ]; then printf '%-24s done\n' "$n"; else printf '%-24s %s\n' "$n" "$d"; fi
    done < <(shots)
    exit 0
fi

command -v grim >/dev/null || die "grim is not installed (pacman -S grim)"
if command -v magick >/dev/null; then im=magick; elif command -v convert >/dev/null; then im=convert; else die "ImageMagick is not installed"; fi

focused_output() {
    command -v hyprctl >/dev/null && command -v jq >/dev/null || return 0
    hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -n1
}

enable_in_readme() {
    local n=$1
    [ "$touch_readme" = 1 ] && [ -w "$readme" ] || return 0
    # <!-- ![alt](docs/images/NAME.png) -->  ->  ![alt](docs/images/NAME.png)
    sed -i "s|^<!-- \(!\[[^]]*\](docs/images/$n\.png)\) -->\$|\1|" "$readme"
    # the hero replaces the fallback hero line
    [ "$n" = hero ] && sed -i '/<!-- hero-fallback -->$/d' "$readme"
    return 0
}

take() {
    local n=$1 desc=${2:-} out=$imgdir/$1.png tmp
    if [ -e "$out" ] && [ "$force" != 1 ]; then echo "$n: exists (use --force to replace)"; return 0; fi
    [ -n "$desc" ] || desc=$(shots | awk -F'\t' -v n="$n" '$1 == n { print $2 }')
    [ -n "$desc" ] || die "unknown shot '$n' (see --list)"
    echo
    echo "== $n: $desc"
    echo "   Privacy: no name, e-mail, notifications or private windows on screen."
    if [ -t 0 ]; then read -r -p "   Set the scene, then press Enter (Ctrl-C to skip all)... " _; fi
    for ((i = delay; i > 0; i--)); do printf '\r   capturing in %d ' "$i"; sleep 1; done
    printf '\r                      \r'
    tmp=$(mktemp --suffix=.png)
    trap 'rm -f "$tmp"' RETURN
    if [ "$area" = 1 ]; then
        command -v slurp >/dev/null || die "slurp is not installed (pacman -S slurp)"
        grim -g "$(slurp)" "$tmp"
    elif [ -n "$(focused_output)" ]; then
        grim -o "$(focused_output)" "$tmp"
    else
        grim "$tmp"
    fi
    "$im" "$tmp" -resize '1920x>' -strip "$out"
    if command -v oxipng >/dev/null; then oxipng -q -o 4 "$out"; elif command -v optipng >/dev/null; then optipng -quiet "$out"; fi
    enable_in_readme "$n"
    echo "   saved $out ($(($(stat -c %s "$out") / 1024)) kB)"
}

case $mode in
all)
    while IFS=$'\t' read -r n d; do take "$n" "$d"; done < <(missing)
    ;;
one)
    [ -n "$name" ] || die "give a shot name, or --list / --all"
    take "$name"
    ;;
esac
