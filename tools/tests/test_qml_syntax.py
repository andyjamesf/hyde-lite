"""Every QML file of the two shells must at least parse. This needs only a qmllint binary (any Qt 6), not
Quickshell, so it can run where the full tools/qml-lint.sh cannot. Run:

    python3 -I tools/tests/test_qml_syntax.py

Parse errors are lines like `file.qml:11:14: Expected token ':'`. Import and type warnings are ignored on
purpose: without Quickshell's metadata they are all noise.

A file using `override property` is skipped: that keyword is newer than Qt 6.4 (Ubuntu 24.04's qmllint,
which CI uses here) although the Qt that Quickshell runs on accepts it. NOT TESTED by this file: types,
bindings and everything else tools/qml-lint.sh checks (needs qmllint 6.5+ and the quickshell package).
"""
import concurrent.futures
import pathlib
import re
import shutil
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def _qt6_qmllint():
    """The first qmllint that is Qt 6's. Arch can have Qt 5's on PATH as plain `qmllint` ("qmllint 1.0": it
    prints `file:5 : Unexpected token` and cannot parse Qt 6 QML), so every candidate is asked its version."""
    for cand in (shutil.which("qmllint6"), shutil.which("qmllint-qt6"), "/usr/lib/qt6/bin/qmllint",
                 shutil.which("qmllint"), "/usr/lib/qt/bin/qmllint"):
        if not cand or not pathlib.Path(cand).exists():
            continue
        out = subprocess.run([cand, "--version"], capture_output=True, text=True, check=False).stdout
        m = re.search(r"(\d+)\.\d+", out)
        if m and int(m.group(1)) >= 6:
            return cand
    return None


QMLLINT = _qt6_qmllint()
# Qt 6.4 words a syntax error "file:3:14: Expected token ..."; qmllint from 6.5 on also tags it "[syntax]". Either counts.
PARSE_ERROR = re.compile(r":\d+:\d+: (Expected|Unexpected|Syntax|Invalid|Unterminated)|\[syntax\]")
NEWER_QT = re.compile(r"^\s*override\s+property\b", re.M)


def qml_files():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z", "--", "Configs/*.qml"],
                         capture_output=True, check=True).stdout.decode()
    return [f for f in out.split("\0") if f]


def parse_errors(path):
    r = subprocess.run([QMLLINT, str(path)], capture_output=True, text=True, check=False, timeout=60)
    return [line for line in (r.stdout + r.stderr).splitlines() if PARSE_ERROR.search(line)]


@unittest.skipUnless(QMLLINT, "no Qt 6 qmllint (pacman -S qt6-declarative / apt install qt6-declarative-dev-tools)")
class QmlSyntax(unittest.TestCase):
    def test_the_checker_catches_a_parse_error(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            bad = pathlib.Path(d) / "bad.qml"
            bad.write_text('import QtQuick\nItem {\n  Rectangle { color: "red"\n}\n')
            self.assertTrue(parse_errors(bad))

    def test_every_shell_file_parses(self):
        files = [f for f in qml_files() if not NEWER_QT.search((ROOT / f).read_text(encoding="utf-8", errors="replace"))]
        self.assertGreater(len(files), 250)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda f: (f, parse_errors(ROOT / f)), files))
        bad = {f: errs[:2] for f, errs in results if errs}
        self.assertEqual(bad, {})


if __name__ == "__main__":
    unittest.main()
