#!/usr/bin/env bash
# Watches a Quickshell instance and, when it keeps a CPU core busy, saves a snapshot of what it is doing.
#
# A runaway shell is hard to catch by hand: it starts on its own, hours into a session, and a restart cures it.
# Leave this running (see docs/troubleshooting.md); it costs almost nothing while the shell is quiet.
#
#   tools/qs-watch.sh [CONFIG_DIR] [options]
#
#   CONFIG_DIR        the shell to watch, as given to `qs -p` (default ~/.config/morphing-island)
#   --threshold N     CPU percent of one core that counts as busy (default 60)
#   --hits N          how many busy samples in a row make a runaway (default 2)
#   --interval S      seconds between samples (default 15)
#   --window S        seconds over which each sample is measured (default 5)
#   --out DIR         where the snapshot and the log go (default $HOME)
#   --max-loops N     give up after N samples (default 0: never)
#   -h, --help        this text
#
# On a runaway it writes DIR/qs-snap-<time>.txt (the process, its threads sorted by CPU, children, open files,
# the most repeated lines of the instance's log and its last lines) and exits 0. Every sample goes to
# DIR/qs-watch.log. Exit 1: gave up after --max-loops without seeing one. Exit 2: bad usage.
set -u

cfg=${XDG_CONFIG_HOME:-$HOME/.config}/morphing-island
threshold=60 hits=2 interval=15 window=5 out=$HOME maxloops=0

usage() { sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; }
die() { echo "qs-watch: $*" >&2; exit 2; }
num() { [[ ${2:-} =~ ^[0-9]+$ ]] || die "$1 needs a whole number"; }

while (($#)); do
    case $1 in
    --threshold) num "$1" "${2:-}"; threshold=$2; shift ;;
    --hits) num "$1" "${2:-}"; hits=$2; shift ;;
    --interval) num "$1" "${2:-}"; interval=$2; shift ;;
    --window) num "$1" "${2:-}"; window=$2; shift ;;
    --max-loops) num "$1" "${2:-}"; maxloops=$2; shift ;;
    --out) [[ -n ${2:-} ]] || die "--out needs a directory"; out=$2; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) die "unknown option $1 (see --help)" ;;
    *) cfg=$1 ;;
    esac
    shift
done
((window > 0)) || die "--window must be at least 1"
mkdir -p "$out" || die "cannot create $out"
log=$out/qs-watch.log
tck=$(getconf CLK_TCK)

# utime + stime of a process, in clock ticks. The command name in /proc/PID/stat may hold spaces and
# parentheses, so everything up to the last ") " is dropped first.
ticks() { awk '{ sub(/^.*\) /, ""); print $12 + $13 }' "/proc/$1/stat" 2>/dev/null; }

find_pid() { pgrep -f -- "qs -p $cfg" | head -n 1; }

snapshot() {
    local pid=$1 f
    f=$out/qs-snap-$(date +%Y%m%d-%H%M%S).txt
    {
        date
        ps -o pid,etime,time,rss,nlwp,args -p "$pid"
        echo
        echo "--- threads by CPU"
        top -H -b -n 1 -p "$pid" 2>/dev/null | head -n 20
        echo
        echo "open files: $(ls "/proc/$pid/fd" 2>/dev/null | wc -l)    children: $(pgrep -P "$pid" | wc -l)"
        ps --ppid "$pid" -o pid,etime,stat,args 2>/dev/null | head -n 25
        echo
        echo "--- most repeated lines of the log"
        qs -p "$cfg" log 2>&1 | sed 's/^[0-9: .-]*//' | sort | uniq -c | sort -rn | head -n 25
        echo
        echo "--- last lines of the log"
        qs -p "$cfg" log -t 40 2>&1
    } >"$f" 2>&1
    echo "$f"
}

busy=0 loops=0
while :; do
    loops=$((loops + 1))
    pid=$(find_pid)
    if [[ -n $pid ]]; then
        a=$(ticks "$pid"); sleep "$window"; b=$(ticks "$pid")
        if [[ -n $a && -n $b ]]; then
            cpu=$(((b - a) * 100 / (window * tck)))
            echo "$(date +%T) pid=$pid cpu=${cpu}%" >>"$log"
            if ((cpu > threshold)); then busy=$((busy + 1)); else busy=0; fi
            if ((busy >= hits)); then
                snap=$(snapshot "$pid")
                echo "$(date +%T) snapshot: $snap" >>"$log"
                echo "$snap"
                exit 0
            fi
        fi
    fi
    if ((maxloops > 0 && loops >= maxloops)); then
        echo "$(date +%T) gave up after $loops samples" >>"$log"
        exit 1
    fi
    sleep "$interval"
done
