#!/usr/bin/env bash
# HyDE LiTE installer for a generic Arch Linux PC: one command, no questions, safe to run again.
#
#   git clone <this repository> && cd hyde-lite && ./install.sh
#
# It installs only what this repository ships (HyDE LiTE, the two Quickshell shells, the matugen colour
# pipeline, the starter wallpapers). It does not know your apps or settings, and it assumes no hardware:
# monitors are detected by Hyprland and Nvidia drivers are installed only with --nvidia.
#
# It runs the upstream installer (Scripts/install.sh) in three separate steps (packages, configs,
# services) and carries on after a step fails, so one problem does not hide the others. The summary at
# the end lists each step and what is left to do by hand.
#
# Options:
#   --nvidia             also install the Nvidia driver when an Nvidia GPU is found
#   --shell zsh|fish     login shell to set up (default: zsh)
#   --aur-helper NAME    AUR helper to build (default: yay-bin, a prebuilt release)
#   --island | --bar     the first shell and its login screen: the Morphing Island, or the bar shell
#                        (islands and pills; --hyde-shell is the old name of --bar). Without either option the installer asks
#                        at the very end (on a terminal) and picks the Island when it cannot ask.
#                        Switch later with `island on|off` (login: `island login install|uninstall`).
#   --no-services        do not enable system services
#   --interactive        let the upstream installer ask its questions (Chaotic AUR, shell, ...)
#   --dry-run            show what would happen; installs nothing, but still creates HyDE's working
#                        directories under $HOME (~/Clone, ~/.cache/hyde, ~/.config/hyde, ...)
#   -h, --help           this text
set -uo pipefail

root=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)
upstream="$root/Scripts/install.sh"
nvidia=0 services=1 interactive=0 dry=0 island=ask shell=zsh aur=yay-bin

while (($#)); do
    case $1 in
    --nvidia) nvidia=1 ;;
    --no-services) services=0 ;;
    --island) island=1 ;;
    --bar | --hyde-shell) island=0 ;;
    --interactive) interactive=1 ;;
    --dry-run) dry=1 ;;
    --shell) shell=${2:-}; shift ;;
    --aur-helper) aur=${2:-}; shift ;;
    -h | --help) sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done
case $shell in zsh | fish) ;; *) echo "install.sh: --shell must be zsh or fish" >&2; exit 2 ;; esac
[[ $aur =~ ^[a-z0-9-]+$ ]] || { echo "install.sh: bad --aur-helper" >&2; exit 2; }

# Colours only on a terminal (and not with NO_COLOR). is_tty is read once here because inside $(...) the
# output is a pipe and -t 1 would always be false.
is_tty=0
[[ -t 1 ]] && is_tty=1
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    c_logo=$'\033[1;38;5;111m' c_step=$'\033[1;38;5;117m' c_dim=$'\033[2m' c_err=$'\033[1;31m' c_ok=$'\033[1;32m' c_off=$'\033[0m'
else
    c_logo='' c_step='' c_dim='' c_err='' c_ok='' c_off=''
fi
say() { printf '\n%s::%s %s%s%s\n' "$c_step" "$c_off" "$c_step" "$*" "$c_off"; }
die() { printf '%s[x] %s%s\n' "$c_err" "$*" "$c_off" >&2; exit 1; }

# The title (the upstream installer's own banners are switched off with HYDE_LITE, see Scripts/install.sh).
export HYDE_LITE=1
# Left padding that centres a line of $1 columns on the terminal. 0 when the output is not a terminal (logs
# and pipes stay plain), when the line does not fit, or when the width is not a number.
center_pad() {
    local cols
    ((is_tty)) || { echo 0; return; }
    cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
    [[ $cols =~ ^[0-9]+$ ]] || cols=80
    if ((cols > $1)); then echo $(((cols - $1) / 2)); else echo 0; fi
}
header() {
    local pad line text rev
    pad=$(center_pad 65) # the logo is 65 columns wide
    printf '%s' "$c_logo"
    while IFS= read -r line; do printf '%*s%s\n' "$pad" '' "$line"; done <<'LOGO'
██╗  ██╗██╗   ██╗██████╗ ███████╗    ██╗     ██╗████████╗███████╗
██║  ██║╚██╗ ██╔╝██╔══██╗██╔════╝    ██║     ██║╚══██╔══╝██╔════╝
███████║ ╚████╔╝ ██║  ██║█████╗      ██║     ██║   ██║   █████╗  
██╔══██║  ╚██╔╝  ██║  ██║██╔══╝      ██║     ██║   ██║   ██╔══╝  
██║  ██║   ██║   ██████╔╝███████╗    ███████╗██║   ██║   ███████╗
╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚══════╝    ╚══════╝╚═╝   ╚═╝   ╚══════╝
LOGO
    printf '%s' "$c_off"
    rev=$(git -C "$root" rev-parse --short HEAD 2>/dev/null || true)
    text="HyDE without the clutter: Hyprland, two Quickshell shells, one colour pipeline"
    pad=$(center_pad "${#text}")
    ((pad)) || pad=2 # not centred: the two-space indent the lines always had
    printf '%s%*s%s%s\n' "$c_dim" "$pad" '' "$text" "$c_off"
    text="installer${rev:+ · $rev}$( ((dry)) && echo ' · dry run')"
    pad=$(center_pad "${#text}")
    ((pad)) || pad=2
    printf '%s%*s%s%s\n' "$c_dim" "$pad" '' "$text" "$c_off"
}
header

# --- checks ---------------------------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "run as your normal user (with sudo), not as root"
[[ -f /etc/arch-release ]] || die "this installer supports Arch Linux only"
[[ -x $upstream || -f $upstream ]] || die "Scripts/install.sh not found next to this script"
command -v sudo >/dev/null || die "sudo is needed (as root: pacman -S sudo, then add your user to the wheel group)"
if ((!dry)); then
    sudo -v || die "sudo did not accept your password"
    curl -fsS --max-time 15 -o /dev/null https://archlinux.org || die "no internet (could not reach archlinux.org)"
fi

# --- base tools -----------------------------------------------------------------------------------
say "Base tools (git, base-devel)"
if ((dry)); then
    echo "would run: sudo pacman -Syu --needed --noconfirm git base-devel"
else
    # -Syu, not -S: the official cloud image ships an old package database, and the mirror no longer has
    # the files it lists (404), so installing without a refresh and upgrade fails on a fresh image.
    sudo pacman -Syu --needed --noconfirm git base-devel || die "could not update the system and install git and base-devel"
fi

# A login session normally provides the runtime directory; a bare TTY or a container may not, and the
# theme step then produces an empty theme without saying why.
if [[ -z ${XDG_RUNTIME_DIR:-} || ! -d ${XDG_RUNTIME_DIR:-} ]]; then
    XDG_RUNTIME_DIR=/run/user/$(id -u)
    if ((!dry)) && [[ ! -d $XDG_RUNTIME_DIR ]]; then
        sudo install -d -m 700 -o "$(id -un)" "$XDG_RUNTIME_DIR" || die "could not create $XDG_RUNTIME_DIR"
    fi
    export XDG_RUNTIME_DIR
fi

# Answers for the upstream installer's own questions: the helper and the shell are fixed here, so only
# the confirmations are left, and an empty answer is the default for each of them.
export getAur=$aur myShell=$shell

# Scripts/restore_shl.sh runs chsh, which needs your password and fails without a terminal (exit 1 on
# every non-interactive run). chsh is shadowed for the install steps and done below, on the terminal.
# ZSH is set because the oh-my-zsh upgrade script, run through "zsh -c", cannot find its own checkout
# and fails on every re-run.
shimdir=$(mktemp -d)
trap 'rm -rf "$shimdir"' EXIT
printf '#!/bin/sh\necho "chsh skipped here: install.sh changes the login shell at the end"\n' >"$shimdir/chsh"
chmod +x "$shimdir/chsh"
export ZSH=$HOME/.oh-my-zsh

nv=(-n)
((nvidia)) && nv=()
((dry)) && nv+=(-t)

# Every step is logged, and the log is scanned afterwards: the upstream installer exits 0 even when a
# package failed to install, which would otherwise end in a green summary.
logdir=${XDG_STATE_HOME:-$HOME/.local/state}/hyde-lite-install
mkdir -p "$logdir"
HYDE_LOG=$(date +'%y%m%d_%Hh%Mm%Ss')
export HYDE_LOG flg_DryRun=$dry
markers='Failed to install|\[err\]|Manual intervention|deployed with failures|installation failed|oh-my-zsh update failed'

# Runs a command with the answers to its questions: an empty line is the default of every upstream
# question, including pacman's provider choice (any other answer makes pacman ask again, forever).
answered() {
    if ((interactive)); then
        "$@" 2>&1
    else
        yes "" 2>/dev/null | "$@" 2>&1
        return "${PIPESTATUS[1]}"
    fi
}

steps=() results=() problems=()
run_step() {
    local name=$1 log start rc found
    shift
    log=$logdir/${name// /-}.log
    say "$name"
    start=$SECONDS
    PATH=$shimdir:$PATH answered "$@" | tee "$log"
    rc=${PIPESTATUS[0]}
    found=$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "$markers" | cut -c1-160 | sort -u | head -n 5)
    steps+=("$name")
    results+=("$rc ($((SECONDS - start)) s)")
    problems+=("$found")
    return 0
}

if ((dry)) && ! command -v git >/dev/null; then
    # The package step needs git, which a dry run does not install.
    steps+=("Packages") results+=("0 (skipped: dry run, git is not installed)") problems+=("")
else
    run_step "Packages" "$upstream" -d -i "${nv[@]}"
fi
run_step "Configs and themes" "$upstream" -r "${nv[@]}"
# Login screen theme, default file manager and shell setup: the upstream installer only runs this script
# after a combined install and restore, which would also run its pre-install script (Chaotic AUR, boot
# loader and pacman.conf changes) and is not wanted here.
run_step "Login screen and shell" "$root/Scripts/install_pst.sh"
((services)) && run_step "Services" "$upstream" -s "${nv[@]}"

# The Morphing Island as the first shell: the "active" file is what hyprland.lua (island.lua) reads at login,
# and its login screen is an SDDM theme (asks for sudo once).
island_default() {
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/morphing-island" &&
        touch "${XDG_STATE_HOME:-$HOME/.local/state}/morphing-island/active" &&
        echo "The Morphing Island starts at the next login." &&
        "$HOME/.local/bin/island" login install
}
bar_default() {
    rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/morphing-island/active" &&
        echo "The bar shell starts at the next login, with the island's login and lock screens." &&
        "$HOME/.local/bin/island" login install
}
# The choice comes last: everything above is the same for both shells.
if ((!dry)); then
    if [[ $island == ask ]]; then
        island=1
        if [[ -t 0 ]]; then
            say "Which shell do you want at the first login?"
            echo "  1) Morphing Island (one pill that expands, with its own login screen)  [default]"
            echo "  2) Bar shell (islands and pills; same login and lock screens, with a fade instead of the pill)"
            read -r -p "Choice [1/2]: " pick
            [[ $pick == 2 ]] && island=0
        fi
    fi
    if ((island)); then
        run_step "Island shell and login screen" island_default
    else
        run_step "Bar shell and login screen" bar_default
    fi
fi

# The shells draw their icons and text with three fonts; without them icons show as empty boxes. The packages
# bring them, this step checks that fontconfig really sees them, so a missing one is reported, not found later.
check_fonts() {
    local missing=0 f families sddm_families
    # fc-list is read into a variable once and the tests run against that, not through a pipe. This
    # script runs with pipefail, and "grep -q" exits at the first match, which leaves fc-list killed
    # by SIGPIPE and the pipeline's status at 141 even though the font was found. A font matching
    # early in the list was reported missing and only one matching on the last line passed, so every
    # clean install ended with the fonts marked missing and the installer exiting 1.
    families=$(fc-list : family)
    for f in "JetBrainsMono Nerd Font" "Inter" "Material Symbols Rounded"; do
        if grep -qiE -- "(^|,)$f(,|$)" <<<"$families"; then
            echo "font ok: $f"
        else
            echo "[err] font missing: $f"
            missing=1
        fi
    done
    # Checked separately as SDDM's own user, which cannot read your home: an icon font deployed only
    # to ~/.local/share/fonts is there for the session but not for the login screen, and the icons
    # under the password field come up blank. Your own session cannot show that.
    if id -u sddm >/dev/null 2>&1; then
        # A sudo that is declined (-n, no cached authorisation) prints nothing, which is not the
        # same answer as "the font is not there": reported as unchecked, never as a failure, so a
        # good install is not rejected over a question that could not be asked.
        if sddm_families=$(sudo -n -u sddm env HOME=/var/lib/sddm fc-list : family 2>/dev/null) &&
            [[ -n $sddm_families ]]; then
            if grep -qiE -- '(^|,)JetBrainsMono Nerd Font(,|$)' <<<"$sddm_families"; then
                echo "font ok: JetBrainsMono Nerd Font (login screen)"
            else
                echo "[err] font missing for the login screen: JetBrainsMono Nerd Font"
                missing=1
            fi
        else
            echo "[warn] could not read fontconfig as the sddm user; login screen font NOT CHECKED"
        fi
    fi
    return "$missing"
}
if ((!dry)); then
    run_step "Fonts" check_fonts
fi

# The login shell needs your password. The upstream step cannot ask for it here, so ask now, on the terminal.
if ((!dry)) && [[ -t 0 ]]; then
    want=$(command -v "$shell" || true)
    if [[ -n $want && $(getent passwd "$(id -un)" | cut -d: -f7) != "$want" ]]; then
        say "Login shell: $shell"
        chsh -s "$want" || echo "chsh did not work; later: chsh -s $want"
    fi
fi

# --- summary --------------------------------------------------------------------------------------
say "Summary"
failed=0
for i in "${!steps[@]}"; do
    if [[ ${results[$i]} == 0\ * && -z ${problems[$i]} ]]; then
        printf '  %s✓%s %-26s %s\n' "$c_ok" "$c_off" "${steps[$i]}" "${results[$i]}"
    else
        printf '  %s✗%s %-26s exit %s\n' "$c_err" "$c_off" "${steps[$i]}" "${results[$i]}"
    fi
    [[ ${results[$i]} == 0\ * ]] || failed=1
    if [[ -n ${problems[$i]} ]]; then
        failed=1
        while IFS= read -r line; do echo "      ! $line"; done <<<"${problems[$i]}"
    fi
done
echo "  logs: $logdir"
if ((failed)); then
    cat <<EOF

At least one step failed or reported a problem (lines marked "!"). Read the log of that step, fix the
cause and run ./install.sh again: every step can be repeated.
EOF
    exit 1
fi
echo
printf '%sDone.%s Log out and choose the Hyprland session in your login manager, or reboot.\n' "$c_ok" "$c_off"
