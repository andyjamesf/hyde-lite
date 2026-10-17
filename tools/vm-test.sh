#!/usr/bin/env bash
# Clean-install test for hyde-lite in a throwaway Arch VM (QEMU/KVM, headless, driven over SSH).
#
# Why this exists next to Scripts/hydevm: hydevm is upstream's tool. It clones HyDE-Project/HyDE and
# runs Scripts/install.sh, and its first run has to be typed into a VM window by hand. This one clones
# hyde-lite, runs the repository's own one-command installer (./install.sh), and needs no typing: the
# VM is seeded with cloud-init, so the whole run is a script and the logs come back to the host.
#
#   tools/vm-test.sh                    # clone the public repository, install, report
#   tools/vm-test.sh --local            # install the local working tree instead
#   tools/vm-test.sh --fresh            # throw the VM disk away and start from the base image
#   tools/vm-test.sh --gui              # same, with a VM window (to see Hyprland and the shells)
#   tools/vm-test.sh --shell            # boot the VM and open a shell in it, install nothing
#   tools/vm-test.sh --boot --gui       # boot the VM from the last run and leave it up, with a window
#                                       #   (to log into SDDM and look at Hyprland and the shells)
#
# The base image is downloaded once and never written to; every run works on a qcow2 overlay, so
# --fresh is a clean machine again in a second.
#
# Two things about the cloud image, so they are not mistaken for hyde-lite's doing: it ships with
# systemd-timesyncd and systemd-time-wait-sync enabled, and the latter holds sysinit.target (so also
# SDDM) until NTP answers, which behind QEMU's user networking took 36 s of a 40 s boot
# ("Wait Until Kernel Time Synchronized"; `systemd-analyze blame` shows it). `sudo systemctl disable
# systemd-time-wait-sync` inside the VM removes the wait. And the image boots multi-user before
# hyde-lite is installed, so after the first install the login screen needs `systemctl start sddm`
# or a reboot.
set -uo pipefail

# --- defaults -------------------------------------------------------------------------------------
REPO_DEFAULT="https://github.com/andyjamesf/hyde-lite.git"
repo=$REPO_DEFAULT ref=main local_tree=0 fresh=0 gui=0 shell_only=0 keep=0 boot_only=0
# --args is passed to ./install.sh as words, not as one argument, so it is written into the remote
# command unquoted on purpose: "--island --shell zsh" has to arrive as three arguments.
install_args="--island --shell zsh"
mem=8G cpus=6 disk=40G port=2222 install_timeout=60
IMAGE_URL="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"

root=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)
cache=${XDG_CACHE_HOME:-$HOME/.cache}/hyde-lite-vm
base=$cache/base.qcow2
overlay=$cache/disk.qcow2
seed=$cache/seed.iso
key=$cache/id_ed25519
serial=$cache/serial.log
pidfile=$cache/qemu.pid

usage() { sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; exit "${1:-0}"; }

while (($#)); do
    case $1 in
    --repo) repo=${2:?}; shift ;;
    --ref) ref=${2:?}; shift ;;
    --local) local_tree=1 ;;
    --args) install_args=${2:?}; shift ;;
    --fresh) fresh=1 ;;
    --gui) gui=1 ;;
    --shell) shell_only=1 ;;
    --boot) boot_only=1; keep=1 ;;
    --keep) keep=1 ;;
    --mem) mem=${2:?}; shift ;;
    --cpus) cpus=${2:?}; shift ;;
    --disk) disk=${2:?}; shift ;;
    --port) port=${2:?}; shift ;;
    --timeout) install_timeout=${2:?}; shift ;;
    -h | --help) usage 0 ;;
    *) echo "vm-test.sh: unknown option '$1' (see --help)" >&2; exit 2 ;;
    esac
    shift
done

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    c_step=$'\033[1;38;5;117m' c_err=$'\033[1;31m' c_ok=$'\033[1;32m' c_dim=$'\033[2m' c_off=$'\033[0m'
else
    c_step='' c_err='' c_ok='' c_dim='' c_off=''
fi
say() { printf '\n%s::%s %s%s%s\n' "$c_step" "$c_off" "$c_step" "$*" "$c_off"; }
info() { printf '%s   %s%s\n' "$c_dim" "$*" "$c_off"; }
die() { printf '%s[x] %s%s\n' "$c_err" "$*" "$c_off" >&2; exit 1; }

# --- host checks ----------------------------------------------------------------------------------
for t in qemu-system-x86_64 qemu-img xorriso curl ssh ssh-keygen; do
    command -v "$t" >/dev/null || die "missing host tool: $t (pacman -S qemu-desktop xorriso openssh)"
done
[[ -r /dev/kvm ]] || die "/dev/kvm is not readable; add yourself to the kvm group and log in again"
((boot_only && fresh)) && die "--boot shows the machine the last run installed; --fresh would wipe it"
((boot_only)) && [[ ! -f $overlay ]] && die "no VM disk yet: run tools/vm-test.sh first to install into one"
mkdir -p "$cache" || die "could not create $cache"

# A VM from an earlier run still holding the forwarded port would make every ssh below talk to it.
if [[ -f $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    die "a VM from an earlier run is still up (pid $(cat "$pidfile")); stop it with: kill $(cat "$pidfile")"
fi
rm -f "$pidfile"

# --- base image -----------------------------------------------------------------------------------
if [[ ! -f $base ]]; then
    say "Base image (Arch cloud image, ~550 MB, downloaded once)"
    curl -fL# -C - "$IMAGE_URL" -o "$base.part" || die "could not download $IMAGE_URL"
    mv "$base.part" "$base"
fi
info "base: $base ($(du -h "$base" | cut -f1))"

# --- ssh key --------------------------------------------------------------------------------------
# Only ever used to reach this throwaway VM.
if [[ ! -f $key ]]; then
    ssh-keygen -q -t ed25519 -N '' -C hyde-lite-vm -f "$key" || die "could not create an ssh key"
fi

# --- cloud-init seed ------------------------------------------------------------------------------
# Rebuilt every run: it is tiny and it keeps the key and the seed in step.
say "cloud-init seed"
seeddir=$(mktemp -d) || die "mktemp failed"
trap 'rm -rf "$seeddir"' EXIT
cat >"$seeddir/meta-data" <<EOF
instance-id: hyde-lite-vm
local-hostname: hyde-lite-vm
EOF
cat >"$seeddir/user-data" <<EOF
#cloud-config
users:
  - name: arch
    groups: [wheel]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - $(cat "$key.pub")
chpasswd:
  expire: false
  list: |
    arch:arch
    root:arch
# Key only over ssh. The passwords above stay for the VM window (the login screen is the point of
# --gui), but the forwarded port is not a way in, not even for another account on this host.
ssh_pwauth: false
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true
runcmd:
  - [systemctl, enable, --now, sshd]
  - [touch, /var/lib/cloud-init-done]
EOF
xorriso -as mkisofs -quiet -V CIDATA -J -r -o "$seed" "$seeddir" || die "could not build the seed ISO"
info "seed: $seed"

# --- disk overlay ---------------------------------------------------------------------------------
if ((fresh)) && [[ -f $overlay ]]; then
    rm -f "$overlay"
    info "old VM disk discarded (--fresh)"
fi
if [[ ! -f $overlay ]]; then
    say "VM disk (overlay on the base image, $disk)"
    qemu-img create -q -f qcow2 -F qcow2 -b "$base" "$overlay" "$disk" || die "could not create the overlay"
    first_boot=1
else
    info "reusing the VM disk from the last run (--fresh for a clean one)"
    first_boot=0
fi

# --- boot -----------------------------------------------------------------------------------------
say "Booting the VM (${cpus} vCPU, ${mem} RAM, headless$( ((gui)) && echo ', with a window'))"
qemu_args=(
    -machine q35 -enable-kvm -cpu host
    -m "$mem" -smp "$cpus"
    -drive "file=$overlay,format=qcow2,if=virtio"
    -drive "file=$seed,media=cdrom,readonly=on"
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$port-:22"
    -device "virtio-net,netdev=net0"
    -device "virtio-rng-pci"
    -serial "file:$serial"
)
if ((gui)); then
    qemu_args+=(-device "virtio-vga-gl" -display "gtk,gl=on,grab-on-hover=on")
else
    qemu_args+=(-display none -vga none)
fi
: >"$serial"
qemu-system-x86_64 "${qemu_args[@]}" &
qemu_pid=$!
echo "$qemu_pid" >"$pidfile"
cleanup() {
    if ((keep)); then
        printf '\n%sVM left running%s (pid %s). Shell: ssh -i %s -p %s arch@127.0.0.1 — stop it: kill %s\n' \
            "$c_dim" "$c_off" "$qemu_pid" "$key" "$port" "$qemu_pid"
        return
    fi
    if kill -0 "$qemu_pid" 2>/dev/null; then
        ssh_vm 'sudo poweroff' >/dev/null 2>&1 || true
        for _ in $(seq 1 20); do kill -0 "$qemu_pid" 2>/dev/null || break; sleep 1; done
        kill -0 "$qemu_pid" 2>/dev/null && kill "$qemu_pid" 2>/dev/null
    fi
    rm -f "$pidfile"
}
trap 'cleanup; rm -rf "$seeddir"' EXIT

ssh_opts=(-i "$key" -p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR -o ConnectTimeout=5)
ssh_vm() { ssh "${ssh_opts[@]}" arch@127.0.0.1 "$@"; }

# First boot has to grow the root filesystem and run cloud-init, so it is the slow one.
budget=$(( first_boot ? 300 : 120 ))
printf '   waiting for ssh (up to %ss)' "$budget"
ready=0
for _ in $(seq 1 "$budget"); do
    if ! kill -0 "$qemu_pid" 2>/dev/null; then
        printf '\n'
        die "QEMU died during boot; the serial console is in $serial"
    fi
    if ssh_vm true 2>/dev/null; then ready=1; printf ' ok\n'; break; fi
    printf '.'
    sleep 1
done
((ready)) || { printf '\n'; die "no ssh after ${budget}s; the serial console is in $serial"; }
info "guest: $(ssh_vm 'source /etc/os-release; echo "$PRETTY_NAME, kernel $(uname -r)"')"
info "disk:  $(ssh_vm "df -h / | awk 'NR==2{print \$2\" total, \"\$4\" free\"}'")"

if ((boot_only)); then
    say "VM is up"
    info "the window shows the login screen; log in as arch / arch"
    info "shell:   ssh -i $key -p $port -o StrictHostKeyChecking=no arch@127.0.0.1"
    info "stop it: kill $qemu_pid"
    exit 0
fi

if ((shell_only)); then
    say "Shell in the VM (exit to shut it down, or run this with --keep to leave it up)"
    ssh -t "${ssh_opts[@]}" arch@127.0.0.1
    exit 0
fi

# --- get the repository into the VM ---------------------------------------------------------------
if ((local_tree)); then
    say "Sending the local working tree ($root)"
    ssh_vm 'rm -rf ~/hyde-lite && mkdir -p ~/hyde-lite' || die "could not prepare ~/hyde-lite in the VM"
    tar -C "$root" --exclude=.git --exclude=__pycache__ --exclude='*.pyc' -cf - . |
        ssh_vm 'tar -C ~/hyde-lite -xf -' || die "could not send the working tree"
    info "sent $(ssh_vm 'find ~/hyde-lite -type f | wc -l') files"
else
    say "Cloning $repo ($ref)"
    # Quoted for the remote shell: these come from the command line of whoever runs this, so they
    # are not hostile, but a branch name with a space or a quote in it should fail, not run.
    ssh_vm "sudo pacman -Sy --needed --noconfirm git >/dev/null 2>&1; rm -rf ~/hyde-lite &&
        git clone --depth 1 --branch $(printf %q "$ref") $(printf %q "$repo") ~/hyde-lite" ||
        die "could not clone the repository"
    info "cloned $(ssh_vm 'git -C ~/hyde-lite rev-parse --short HEAD') ($(ssh_vm 'find ~/hyde-lite -type f | wc -l') files)"
fi

# A reused disk (--keep, --boot) can still hold the theme's fonts/ from an earlier install, and the
# "login screen theme bundles fonts" check below only looks for the file: cleared here so a ✓ can
# only have come from this run.
ssh_vm 'sudo rm -rf /usr/share/sddm/themes/morphing-island/fonts' >/dev/null 2>&1

# --- run the installer ----------------------------------------------------------------------------
# Run under "script" so stdout is a pty and the installer's own output path is the real one, but give
# the installer's stdin /dev/null rather than the pty. Two things went wrong before this shape:
#   * stdin from "yes ''" — the pty echoes back everything written to it, so script logged its own
#     echo forever: 7.5 GB in 11 s, and the guest OOM-killed it.
#   * stdin left on the pty with nothing feeding it — a pty read does not see EOF while script holds
#     the master open, so the installer's final "chsh" sat on its password prompt for ever.
# With /dev/null every read returns EOF at once, which is the default answer to each question. The
# cost is that [[ -t 0 ]] is false, so the installer skips its own chsh step; the login shell is
# checked separately below.
# The timeout is the backstop: a future hang has to fail loudly instead of hanging the harness.
say "Running ./install.sh $install_args"
info "this takes a while (packages, AUR builds); the log streams below"
started=$(date +%s)
ssh -n "${ssh_opts[@]}" arch@127.0.0.1 \
    "cd ~/hyde-lite && timeout --foreground ${install_timeout}m \
        script -q -e -c './install.sh $install_args </dev/null' ~/install.log </dev/null" 2>&1 |
    sed 's/^/   /'
rc=${PIPESTATUS[0]}
elapsed=$(( $(date +%s) - started ))

# --- collect ---------------------------------------------------------------------------------------
say "Collecting logs"
out=$cache/run-$(date +%y%m%d_%H%M%S)
mkdir -p "$out"
ssh_vm 'cat ~/install.log' >"$out/install.log" 2>/dev/null
ssh_vm 'tar -C "$HOME/.local/state" -cf - hyde-lite-install 2>/dev/null' | tar -C "$out" -xf - 2>/dev/null
ssh_vm 'tar -C "$HOME/.cache/hyde" -cf - logs 2>/dev/null' | tar -C "$out" -xf - 2>/dev/null
cp -f "$serial" "$out/serial.log" 2>/dev/null
# Hard evidence for the questions a failing font or package check raises: was it installed at all,
# and what family name does it really provide? Reading this off the installer's log is unreliable
# because the dependency resolver overwrites its own lines with a spinner.
{
    echo "# pacman -Q for the packages the shells need"
    ssh_vm 'pacman -Q quickshell hyprland sddm matugen inter-font ttf-jetbrains-mono-nerd \
        ttf-material-symbols-variable-git 2>&1'
    echo
    echo "# login shell. NOT TESTED as a check: the installer only runs chsh when stdin is a"
    echo "# terminal, and this harness gives it /dev/null so nothing can block on a password"
    echo "# prompt. Verify it by hand in a --boot --gui session."
    ssh_vm 'getent passwd arch | cut -d: -f7'
    echo
    echo "# font families fontconfig reports"
    ssh_vm "fc-list : family | tr ',' '\n' | sort -u"
} >"$out/packages-and-fonts.txt" 2>&1
info "logs: $out"

# What a clean install has to have produced, checked from outside the installer's own reporting.
say "Post-install checks"
checks=(
    "hyprland binary|command -v Hyprland"
    "quickshell binary|command -v qs || command -v quickshell"
    "matugen binary|command -v matugen"
    "hyprland.lua|test -f ~/.config/hypr/hyprland.lua"
    "hyde config|test -f ~/.config/hyde/config.toml || test -f ~/.config/hyde/hyde.conf"
    "island shell|test -d ~/.config/morphing-island || test -d ~/.config/quickshell"
    "wallpapers|test -n \"\$(ls ~/.config/hyde/wallpapers 2>/dev/null || ls ~/Pictures/Wallpapers 2>/dev/null)\""
    "theme state|test -f ~/.cache/hyde/wall.dcol"
    "sddm service|systemctl is-enabled sddm"
    "hyprland session|test -f /usr/share/wayland-sessions/hyprland.desktop"
    # Anchored the way install.sh checks: an unanchored grep for the icon font passes on
    # "JetBrainsMono Nerd Font Mono", which is a different family from the one the shells ask for.
    "jetbrains nerd font|fc-list : family | grep -qiE -- '(^|,)JetBrainsMono Nerd Font(,|\$)'"
    "inter font|fc-list : family | grep -qiE -- '(^|,)Inter(,|\$)'"
    # The one that matters for the first login screen: SDDM runs as its own user and cannot read
    # the installing user's home, so a font deployed only to ~/.local/share/fonts is not there.
    "login screen icon font|sudo -n -u sddm env HOME=/var/lib/sddm fc-list : family | grep -qiE -- '(^|,)JetBrainsMono Nerd Font(,|\$)'"
    # The theme's fonts/ is deleted before the installer runs, so this file can only be this run's.
    "login screen theme bundles fonts|test -f /usr/share/sddm/themes/morphing-island/fonts/Icons.ttf"
)
pass=0 fail=0
for c in "${checks[@]}"; do
    name=${c%%|*} cmd=${c#*|}
    if ssh_vm "$cmd" >/dev/null 2>&1; then
        printf '  %s✓%s %s\n' "$c_ok" "$c_off" "$name"; ((pass++))
    else
        printf '  %s✗%s %s\n' "$c_err" "$c_off" "$name"; ((fail++))
    fi
done

say "Result"
rc_note=""
((rc == 124)) && rc_note=" (TIMED OUT after ${install_timeout}m)"
printf '  installer exit code : %s%s\n' "$rc" "$rc_note"
printf '  wall clock          : %sm%ss\n' "$((elapsed / 60))" "$((elapsed % 60))"
printf '  post-install checks : %s passed, %s failed\n' "$pass" "$fail"
printf '  logs                : %s\n' "$out"
if ((rc == 0 && fail == 0)); then
    printf '\n%sClean install worked.%s Re-run with --gui --keep to look at the session on screen.\n' "$c_ok" "$c_off"
    exit 0
fi
printf '\n%sSomething failed.%s Read %s/install.log, then re-run after fixing (--fresh for a clean machine).\n' \
    "$c_err" "$c_off" "$out"
exit 1
