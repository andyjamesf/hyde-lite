#!/usr/bin/env bash
# Fast static checks for the whole repository. Run from anywhere: tools/check.sh
# Needs: bash, git, python3 (3.11+). ruff is used if installed, shellcheck is not required.
set -u
root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel) || exit 2
cd "$root" || exit 2
fail=0
step() { printf '== %s\n' "$1"; }

# Shell: tracked *.sh plus extensionless files with a bash/sh shebang (zsh and fish are skipped).
step "bash -n"
n=0
while IFS= read -r -d '' f; do
    [[ -f $f ]] || continue
    if [[ $f == *.sh ]] || { IFS= read -r first <"$f" 2>/dev/null && [[ $first =~ ^#!.*(bash|[/[:space:]]sh)([[:space:]]|$) ]]; }; then
        n=$((n + 1))
        bash -n "$f" || { echo "FAIL bash -n: $f"; fail=1; }
    fi
done < <(git ls-files -z)
echo "shell: $n files"

step "python"
mapfile -d '' pyfiles < <(git ls-files -z '*.py')
if ((${#pyfiles[@]})); then
    # pycache_prefix keeps py_compile from writing __pycache__ into the tree (-I would ignore the env var).
    pyc=$(mktemp -d)
    python3 -I -X pycache_prefix="$pyc" -m py_compile "${pyfiles[@]}" || fail=1
    rm -rf "$pyc"
    echo "py_compile: ${#pyfiles[@]} files"
    if command -v ruff >/dev/null; then
        # Only real errors (syntax, undefined names): upstream style findings are not ours to fix.
        ruff check --no-cache --select E9,F63,F7,F82 "${pyfiles[@]}" || fail=1
    else
        echo "ruff: not installed, skipped"
    fi
fi

step "toml / json / includes"
python3 -I tools/check_data.py "$root" || fail=1

step "bar layouts"
python3 -I Configs/.config/quickshell/scripts/validate_layouts.py || fail=1

# Display-free unit tests of our own scripts (the upstream suite lives in the tests submodule).
step "unit tests"
for t in tools/tests/test_*.py; do
    [[ -f $t ]] || continue
    if out=$(PYTHONDONTWRITEBYTECODE=1 python3 -I "$t" 2>&1); then echo "ok $t"; else
        echo "FAIL $t"; printf '%s\n' "$out" | tail -n 15 | sed 's/^/    /'; fail=1
    fi
done

# qmllint is optional (not on every CI image, and too old on some): exit 2 means "could not run", not failure.
step "qml-lint"
if [[ -f tools/qml-lint.baseline ]]; then
    tools/qml-lint.sh; rc=$?
    case $rc in 0) ;; 2) echo "qml-lint: skipped" ;; *) fail=1 ;; esac
else
    echo "qml-lint: no tools/qml-lint.baseline yet (run tools/qml-lint.sh --baseline on Arch), skipped"
fi

((fail)) && echo "check: FAILED" || echo "check: ok"
exit "$fail"
