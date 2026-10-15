"""tools/export_clean.sh: a fresh tree of HEAD without history or untracked files, refused when unsafe, checked."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git(cwd, *args, check=True):
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid")
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True, env=env, check=check)


class Export(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.repo = self.tmp / "repo"
        (self.repo / "tools").mkdir(parents=True)
        (self.repo / "docs/internal").mkdir(parents=True)
        for n in ("export_clean.sh", "scan_publish.py"):
            shutil.copy(ROOT / "tools" / n, self.repo / "tools" / n)
        (self.repo / "tools/check.sh").write_text("#!/usr/bin/env bash\necho checks-ran\n")
        (self.repo / "README.md").write_text("# T\n| [`docs/internal/`](docs/internal/) | notes |\n| other | row |\n")
        (self.repo / "docs/internal/PLAN.md").write_text("notes\n")
        (self.repo / "LITE.md").write_text("see `docs/internal/PLAN.md`\n")
        git(self.tmp, "init", "-q", "-b", "main", str(self.repo))
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "one")
        self.dest = self.tmp / "out"

    def run_export(self, *args, dest=None):
        return subprocess.run(["bash", str(self.repo / "tools/export_clean.sh"), *args, str(dest or self.dest)],
                              capture_output=True, text=True, cwd=self.repo)

    def test_exports_the_committed_files_without_history_or_untracked_files(self):
        (self.repo / "untracked.txt").write_text("not committed\n")
        r = self.run_export()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.dest / "README.md").is_file())
        self.assertTrue((self.dest / "docs/internal/PLAN.md").is_file())
        self.assertFalse((self.dest / "untracked.txt").exists())
        self.assertFalse((self.dest / ".git").exists())
        self.assertIn("checks-ran", r.stdout)
        self.assertIn("0 problem(s)", r.stdout)
        self.assertIn('git -c user.name="YOUR NAME"', r.stdout)

    def test_without_internal_drops_the_folder_and_the_readme_row_and_lists_the_text_mentions(self):
        r = self.run_export("--without-internal")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse((self.dest / "docs/internal").exists())
        readme = (self.dest / "README.md").read_text()
        self.assertNotIn("docs/internal", readme)
        self.assertIn("| other | row |", readme)
        self.assertIn("LITE.md:1", r.stdout)

    def test_a_secret_in_a_committed_file_stops_the_export(self):
        (self.repo / "notes.txt").write_text("key " + "gh" + "p_" + "a" * 36 + "\n")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "oops")
        r = self.run_export()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("a GitHub token", r.stdout)
        self.assertNotIn("Clean copy ready", r.stdout)

    def test_refuses_a_dirty_tree(self):
        (self.repo / "README.md").write_text("changed\n")
        r = self.run_export()
        self.assertEqual(r.returncode, 1)
        self.assertIn("uncommitted", r.stderr)
        self.assertFalse(self.dest.exists())

    def test_refuses_a_destination_with_files_or_inside_the_repository(self):
        self.dest.mkdir()
        (self.dest / "keep.txt").write_text("mine\n")
        r = self.run_export()
        self.assertEqual(r.returncode, 1)
        self.assertIn("not empty", r.stderr)
        self.assertEqual((self.dest / "keep.txt").read_text(), "mine\n")
        r = self.run_export(dest=self.repo / "sub")
        self.assertEqual(r.returncode, 1)
        self.assertIn("outside this repository", r.stderr)

    def test_usage(self):
        r = subprocess.run(["bash", str(self.repo / "tools/export_clean.sh")], capture_output=True, text=True, cwd=self.repo)
        self.assertEqual(r.returncode, 2)
        r = subprocess.run(["bash", str(self.repo / "tools/export_clean.sh"), "--nope", "x"], capture_output=True, text=True, cwd=self.repo)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
