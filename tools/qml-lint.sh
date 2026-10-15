#!/usr/bin/env bash
# qmllint for the two Quickshell shells (Configs/.config/quickshell and Configs/.config/morphing-island).
#
# qmllint does not know what `import qs.services` means: Quickshell maps `qs.<dir>` onto the shell's
# own subdirectories at runtime and supplies the module metadata itself. Without that metadata every
# singleton is an unknown name and almost every property read is reported as an unqualified access,
# which buries everything real. So this builds a throwaway import tree per shell: one directory per
# qs.<path> module (nested directories become qs.modules.bar and so on), symlinks to the real .qml
# files, and a generated qmldir declaring each type, with the `pragma Singleton` ones marked.
#
#   tools/qml-lint.sh              both shells, counts compared against tools/qml-lint.baseline
#   tools/qml-lint.sh FILE...      only those files, only the categories that must stay at zero
#   tools/qml-lint.sh --baseline   rewrite the baseline from the current trees
#   tools/qml-lint.sh --raw        every warning of both shells, one per line, paths relative to the repo
#   tools/qml-lint.sh --since [REV]  warnings that exist now and did not at REV (default: the commit that
#                                  last changed the baseline); line numbers are ignored when matching
#
# QML_LINT_REPO=DIR lints another checkout (--since uses it for the old tree).
#
# sddm/ is left out: that theme runs inside SDDM's own QML environment, so its imports do not resolve.
# Needs the `quickshell` package (its qmltypes): without it every `required` and `import` finding is an
# artifact (30 false `required` warnings measured on Arch without it, none with it).
set -uo pipefail

REPO=${QML_LINT_REPO:-$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)} || exit 2
SHELLS=(quickshell morphing-island)
BASELINE=$REPO/tools/qml-lint.baseline
ZERO_CATEGORIES="unused-imports id-shadows-member required"

# Qt 6 first: on Arch a plain `qmllint` on PATH can be Qt 5's (it prints "qmllint 1.0" and cannot parse Qt 6 QML).
QMLLINT=${QMLLINT:-$(command -v qmllint6 || command -v qmllint-qt6 || true)}
[ -n "$QMLLINT" ] || for c in /usr/lib/qt6/bin/qmllint /usr/lib/qt/bin/qmllint; do [ -x "$c" ] && QMLLINT=$c && break; done
[ -n "$QMLLINT" ] || QMLLINT=$(command -v qmllint || true)
QT_QML=${QT_QML:-}
if [ -z "$QT_QML" ]; then
    for c in /usr/lib/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml; do [ -d "$c" ] && QT_QML=$c && break; done
fi
[ -x "${QMLLINT:-}" ] || { echo "qml-lint: qmllint not found (pacman -S qt6-declarative / apt install qt6-declarative-dev-tools)" >&2; exit 2; }

# Warnings carry their [category] tag only from qmllint 6.5 on; 6.4 (Ubuntu 24.04) prints none, so every
# count would be zero. Refuse to produce numbers that mean nothing.
ver=$("$QMLLINT" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
if [ "$(printf '%s\n6.5\n' "$ver" | sort -V | head -1)" != 6.5 ]; then
    echo "qml-lint: qmllint $ver does not tag warning categories (needs 6.5+); skipped" >&2; exit 2
fi

QS_TYPES=${QS_TYPES:-/usr/lib/qt6/qml/Quickshell}
[ -d "$QS_TYPES" ] || { echo "qml-lint: Quickshell types not found at $QS_TYPES (pacman -S quickshell); skipped" >&2; exit 2; }

TREE=$(mktemp -d) || exit 2
trap 'rm -rf -- "$TREE"' EXIT

# make_tree SHELL -> $TREE/SHELL/qs/... import tree; prints nothing
make_tree() {
    python3 -I - "$REPO/Configs/.config/$1" "$TREE/$1" <<'PY'
import pathlib, sys
src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
for d in sorted(p for p in src.rglob("*") if p.is_dir() and "sddm" not in p.relative_to(src).parts):
    files = sorted(d.glob("*.qml"))
    rel = d.relative_to(src)
    if not files or not rel.parts:
        continue
    mod = ".".join(rel.parts)
    od = out / "qs" / pathlib.Path(*rel.parts)
    od.mkdir(parents=True, exist_ok=True)
    lines = [f"module qs.{mod}"]
    for f in files:
        (od / f.name).symlink_to(f)
        singleton = f.read_text(errors="replace").lstrip().startswith("pragma Singleton")
        lines.append(f"{'singleton ' if singleton else ''}{f.stem} 1.0 {f.name}")
    (od / "qmldir").write_text("\n".join(lines) + "\n")
PY
}
for s in "${SHELLS[@]}"; do make_tree "$s"; done

shell_of() {  # file -> shell name
    case $1 in */Configs/.config/quickshell/*) echo quickshell ;; */Configs/.config/morphing-island/*) echo morphing-island ;; *) echo "" ;; esac
}
run_lint() {  # SHELL files... -> warning lines on stdout
    local s=$1; shift
    local args=(-I "$TREE/$s"); [ -n "$QT_QML" ] && args=(-I "$QT_QML" "${args[@]}")
    # One file per call: a crash in qmllint (6.4 segfaults on some files) then costs one file, not the run.
    local f out rc
    for f in "$@"; do
        out=$("$QMLLINT" "${args[@]}" "$f" 2>&1); rc=$?
        printf '%s\n' "$out"
        [ "$rc" -gt 128 ] && [ "$rc" -le 159 ] && echo "Warning: $f: qmllint crashed (signal $((rc - 128))) [crash]"
    done
    return 0
}
shell_files() { find "$REPO/Configs/.config/$1" -name '*.qml' -not -path '*/sddm/*' | sort; }
counts() { grep -oE '\[[a-z-]+\]$' | tr -d '[]' | sort | uniq -c | awk '{print $1, $2}'; }
lint_shell() { mapfile -t f < <(shell_files "$1"); run_lint "$1" "${f[@]}" | counts | sed "s/^/$1 /"; }

# One warning per line, repo-relative path, "file.qml:LINE:COL:" kept (raw) or reduced to "file.qml:" (norm).
# Every occurrence of the repo path goes: some messages carry a second one ("component in /path/File.qml"), and
# if it stayed, --since would list that warning as new just because the old tree lives in another directory.
raw_all() {
    local s f
    for s in "${SHELLS[@]}"; do
        mapfile -t f < <(shell_files "$s"); run_lint "$s" "${f[@]}"
    done | grep -E '\[[a-z-]+\]$' | sed "s#$REPO/##g"
}
norm() { sed -E 's/\.qml:[0-9]+:[0-9]+:/.qml:/' | sort; }

if [ "${1:-}" = "--raw" ]; then raw_all; exit 0; fi

if [ "${1:-}" = "--since" ]; then
    rev=${2:-$(git -C "$REPO" log -1 --format=%H -- tools/qml-lint.baseline)}
    [ -n "$rev" ] || { echo "qml-lint: no revision to compare with" >&2; exit 2; }
    OLD=$(mktemp -d) || exit 2
    git -C "$REPO" worktree add --detach -q "$OLD/tree" "$rev" || exit 2
    trap 'git -C "$REPO" worktree remove --force "$OLD/tree" 2>/dev/null; rm -rf -- "$OLD" "$TREE"' EXIT
    QML_LINT_REPO=$OLD/tree bash "${BASH_SOURCE[0]}" --raw | norm > "$OLD/old"
    raw_all > "$OLD/new"
    echo "qml-lint: warnings present now and not at ${rev:0:8} (with line:col, so they can be found):"
    # Multiset difference: a key present N times before hides the first N of its copies now; the rest are printed
    # as they came out of qmllint, line numbers included.
    awk 'NR == FNR { seen[$0]++; next }
         { k = $0; sub(/\.qml:[0-9]+:[0-9]+:/, ".qml:", k); if (seen[k] > 0) seen[k]--; else print "  " $0 }' "$OLD/old" "$OLD/new"
    exit 0
fi

if [ "${1:-}" = "--baseline" ]; then
    # The "#!" lines are the record of accepted increases (see the header of the baseline): keep them.
    notes=$(grep '^#!' "$BASELINE" 2>/dev/null || true)
    {
        echo "# qmllint counts per shell and category, as of the last update."
        echo "# tools/qml-lint.sh fails when a count grows past its number here."
        echo "# Lower a number whenever you fix something. Never raise one to make the check pass, with one exception:"
        echo "# an increase the owner has decided to accept, recorded below as a '#!' line with its reason"
        echo "# (tools/tests/test_qml_baseline.py checks the record). Rewriting the baseline keeps those lines."
        [ -n "$notes" ] && printf '%s\n' "$notes"
        for s in "${SHELLS[@]}"; do lint_shell "$s"; done
    } > "$BASELINE"
    echo "qml-lint: baseline written to ${BASELINE#"$REPO"/}"; sed '/^#/d;s/^/  /' "$BASELINE"
    exit 0
fi

if [ "$#" -gt 0 ]; then
    bad=0
    for s in "${SHELLS[@]}"; do
        sel=()
        for f in "$@"; do f=$(realpath -- "$f"); [ "$(shell_of "$f")" = "$s" ] && sel+=("$f"); done
        [ "${#sel[@]}" -gt 0 ] || continue
        out=$(run_lint "$s" "${sel[@]}")
        for cat in $ZERO_CATEGORIES; do
            if grep -qE "\[$cat\]$" <<<"$out"; then
                echo "qml-lint: [$cat] must stay at zero:" >&2
                printf '%s\n' "$out" | grep -E "\[$cat\]$" | sed 's/^/  /' >&2; bad=1
            fi
        done
        if grep -qE '^Error:' <<<"$out"; then
            echo "qml-lint: a file did not parse:" >&2
            printf '%s\n' "$out" | grep -E '^Error:' | sed 's/^/  /' >&2; bad=1
        fi
    done
    [ "$bad" -eq 0 ] && echo "qml-lint: $# file(s) ok"
    exit "$bad"
fi

[ -f "$BASELINE" ] || { echo "qml-lint: no baseline yet, run: tools/qml-lint.sh --baseline" >&2; exit 2; }
now=$(for s in "${SHELLS[@]}"; do lint_shell "$s"; done)
bad=0
printf '%-16s %-24s %6s %9s\n' shell category now baseline
while read -r sh n cat; do
    was=$(awk -v s="$sh" -v c="$cat" '$1 == s && $3 == c { print $2 }' "$BASELINE"); was=${was:-0}
    mark=""
    if [ "$n" -gt "$was" ]; then mark="  <-- grew"; bad=1
    elif [ "$n" -lt "$was" ]; then mark="  <-- fixed, lower the baseline"; fi
    printf '%-16s %-24s %6s %9s%s\n' "$sh" "$cat" "$n" "$was" "$mark"
done <<< "$now"
# (grep -q on a here-string, not a pipe: under pipefail grep exiting early SIGPIPEs printf and the test lies.)
# A zero category must also be zero in the tree, whatever the baseline says.
for cat in $ZERO_CATEGORIES; do
    n=$(printf '%s\n' "$now" | awk -v c="$cat" '$3 == c { s += $2 } END { print s + 0 }')
    [ "$n" -gt 0 ] && { echo "qml-lint: $n x [$cat], which must stay at zero" >&2; bad=1; }
done
[ "$bad" -ne 0 ] && { echo "qml-lint: something grew. See which warnings are new with: tools/qml-lint.sh --since. Fix them. A count may only be raised for an increase the owner accepted, recorded as a #! line in the baseline." >&2; exit 1; }
echo "qml-lint: nothing grew"
