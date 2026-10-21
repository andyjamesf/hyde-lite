"""tools/qml-lint.sh --raw / --since, with a fake qmllint (the real one needs Qt 6.5+ and Quickshell)."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "qml-lint.sh"

# Prints "Warning: FILE:LINE:1: msg [unqualified]" for every line of the file that contains "WARN".
FAKE = r"""#!/usr/bin/env bash
if [ "$1" = --version ]; then echo "qmllint 6.5.0"; exit 0; fi
f=${@: -1}
grep -n WARN "$f" | while IFS=: read -r n rest; do echo "Warning: $f:$n:1: $rest [unqualified]"; done
exit 0
"""


def git(cwd, *args):
    subprocess.run(["git", "-C", str(cwd), "-c", "user.name=t", "-c", "user.email=t@example.invalid", *args],
                   check=True, capture_output=True)


class QmlLintSince(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.repo = self.tmp / "repo"
        for shell in ("bar", "island"):
            d = self.repo / "Configs" / ".config" / "quickshell" / shell
            d.mkdir(parents=True)
            (d / "A.qml").write_text("Item {\n  // WARN old\n}\n")
        (self.repo / "tools").mkdir()
        shutil.copy(SCRIPT, self.repo / "tools" / "qml-lint.sh")
        (self.repo / "tools" / "qml-lint.baseline").write_text("# x\n")
        git(self.repo.parent, "init", "-q", str(self.repo))
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "base")
        self.fake = self.tmp / "qmllint"
        self.fake.write_text(FAKE)
        self.fake.chmod(0o755)
        (self.tmp / "qt").mkdir()
        (self.tmp / "qs").mkdir()

    def run_lint(self, *args):
        env = dict(os.environ, QMLLINT=str(self.fake), QT_QML=str(self.tmp / "qt"), QS_TYPES=str(self.tmp / "qs"))
        env.pop("QML_LINT_REPO", None)
        return subprocess.run(["bash", str(self.repo / "tools" / "qml-lint.sh"), *args],
                              capture_output=True, text=True, env=env, cwd=self.repo)

    def test_raw_lists_every_warning_with_relative_path(self):
        r = self.run_lint("--raw")
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = r.stdout.splitlines()
        self.assertEqual(len(lines), 2, r.stdout)
        self.assertTrue(all(l.startswith("Warning: Configs/.config/") for l in lines), r.stdout)

    def test_since_reports_only_new_warnings_and_ignores_moved_lines(self):
        a = self.repo / "Configs/.config/quickshell/bar/A.qml"
        # one line added above the old warning (moves it) plus one new warning
        a.write_text("// header\nItem {\n  // WARN old\n  // WARN brand new\n}\n")
        r = self.run_lint("--since", "HEAD")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("brand new", r.stdout)
        # the line number of the new warning is shown (it is line 4 now)
        self.assertRegex(r.stdout, r"A\.qml:4:1:.*brand new")
        body = [l for l in r.stdout.splitlines()[1:] if l.strip()]
        self.assertEqual(len(body), 1, r.stdout)
        self.assertNotIn("old", body[0])

    def test_since_counts_duplicates(self):
        a = self.repo / "Configs/.config/quickshell/bar/A.qml"
        a.write_text("Item {\n  // WARN old\n  // WARN old\n  // WARN old\n}\n")  # one before, three now
        body = [l for l in self.run_lint("--since", "HEAD").stdout.splitlines()[1:] if l.strip()]
        self.assertEqual(len(body), 2, body)

    def test_rewriting_the_baseline_keeps_the_accepted_increase_records(self):
        base = self.repo / "tools" / "qml-lint.baseline"
        note = "#! accepted 2026-10-15 bar import 0->1 Configs/.config/quickshell/bar/A.qml: kept across rewrites, a long enough reason"
        base.write_text(f"# old header\n{note}\nbar 9 unqualified\n")
        r = self.run_lint("--baseline")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = base.read_text()
        self.assertIn(note, text)
        self.assertNotIn("# old header", text)
        self.assertIn("bar 1 unqualified", text)   # the fake lint reports one warning per shell

    def test_since_without_changes_prints_nothing_new(self):
        r = self.run_lint("--since", "HEAD")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip().splitlines()[1:], [], r.stdout)

    def test_since_default_revision_is_last_baseline_commit(self):
        (self.repo / "Configs/.config/quickshell/island/A.qml").write_text("Item {\n  // WARN old\n  // WARN later\n}\n")
        r = self.run_lint("--since")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("later", r.stdout)


if __name__ == "__main__":
    unittest.main()
