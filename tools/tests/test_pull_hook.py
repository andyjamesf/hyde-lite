"""tools/git-hooks (post-merge / post-rewrite): a real `git pull` in a throwaway clone updates the installed configuration."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHELL = "Configs/.config/quickshell"


def git(cwd, *args, env=None, check=True):
    e = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.invalid",
             GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid", **(env or {}))
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True, env=e, check=check)


class PullHook(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.target = self.tmp / "installed"
        self.target.mkdir()
        (self.target / "a.qml").write_text("v1\n")
        (self.target / "mine.qml").write_text("mine\n")
        # the "upstream": a work repo that pushes to a bare remote; the clone is what the owner pulls in
        self.bare = self.tmp / "remote.git"
        git(self.tmp, "init", "-q", "--bare", "-b", "main", str(self.bare))
        self.work = self.tmp / "work"
        git(self.tmp, "clone", "-q", str(self.bare), str(self.work))
        (self.work / SHELL).mkdir(parents=True)
        (self.work / SHELL / "a.qml").write_text("v1\n")
        (self.work / "docs").mkdir()
        (self.work / "docs/x.md").write_text("x\n")
        (self.work / "tools").mkdir()
        shutil.copytree(ROOT / "tools/git-hooks", self.work / "tools/git-hooks")
        shutil.copy(ROOT / "tools/sync_shell.py", self.work / "tools/sync_shell.py")
        git(self.work, "checkout", "-q", "-b", "main")
        git(self.work, "add", "-A")
        git(self.work, "commit", "-q", "-m", "base")
        git(self.work, "push", "-q", "origin", "main")
        self.clone = self.tmp / "clone"
        git(self.tmp, "clone", "-q", str(self.bare), str(self.clone))
        git(self.clone, "config", "core.hooksPath", "tools/git-hooks")
        self.env = {"HOME": str(self.home), "HYDE_LITE_SHELL_TARGET": str(self.target)}

    def upstream(self, path, text, msg="change"):
        (self.work / path).parent.mkdir(parents=True, exist_ok=True)
        (self.work / path).write_text(text)
        git(self.work, "add", "-A")
        git(self.work, "commit", "-q", "-m", msg)
        git(self.work, "push", "-q", "origin", "main")

    def pull(self, *args, env=None):
        return git(self.clone, "pull", "-q", *args, env={**self.env, **(env or {})}, check=False)

    def backups(self):
        d = self.home / ".local/state/hyde-lite/backups"
        return sorted(p.name for p in d.iterdir()) if d.exists() else []

    def test_a_pull_that_changes_the_shell_updates_the_installed_copy(self):
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        self.upstream(f"{SHELL}/new.qml", "new\n")
        r = self.pull()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "a.qml").read_text(), "v2\n")
        self.assertEqual((self.target / "new.qml").read_text(), "new\n")
        self.assertEqual((self.target / "mine.qml").read_text(), "mine\n")   # never deleted
        self.assertEqual(len(self.backups()), 1)
        self.assertIn("restart", r.stdout + r.stderr)

    def test_a_pull_that_does_not_touch_the_shell_does_nothing(self):
        (self.target / "a.qml").write_text("edited by hand\n")
        self.upstream("docs/x.md", "y\n")
        r = self.pull()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "a.qml").read_text(), "edited by hand\n")
        self.assertEqual(self.backups(), [])

    def test_opt_out_for_one_pull(self):
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        r = self.pull(env={"HYDE_LITE_NO_SYNC": "1"})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "a.qml").read_text(), "v1\n")

    def test_a_missing_target_does_not_fail_the_pull(self):
        shutil.rmtree(self.target)
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        r = self.pull()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.clone / SHELL / "a.qml").read_text(), "v2\n")

    def test_a_failing_sync_does_not_fail_the_pull(self):
        shutil.rmtree(self.target)
        self.target.write_text("a file, not a folder\n")
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        r = self.pull()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("failed", r.stderr)
        self.assertEqual((self.clone / SHELL / "a.qml").read_text(), "v2\n")

    def test_a_pull_with_rebase_runs_it_too(self):
        (self.clone / "docs/local.md").write_text("local\n")
        git(self.clone, "add", "-A")
        git(self.clone, "commit", "-q", "-m", "local work")
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        r = self.pull("--rebase")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "a.qml").read_text(), "v2\n")

    def test_amend_is_not_a_pull(self):
        # a pull first, so ORIG_HEAD exists and the range ORIG_HEAD..HEAD will contain the amended shell edit
        self.upstream("docs/x.md", "y\n")
        self.pull()
        (self.clone / SHELL / "a.qml").write_text("local edit\n")
        git(self.clone, "add", "-A")
        r = git(self.clone, "commit", "-q", "--amend", "-m", "amended", env=self.env, check=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.target / "a.qml").read_text(), "v1\n")
        self.assertEqual(self.backups(), [])

    def test_the_hook_itself_exits_zero_when_the_sync_fails(self):
        # git ignores post-merge's status, so ask the script directly
        shutil.rmtree(self.target)
        self.target.write_text("a file, not a folder\n")
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        self.pull()
        r = subprocess.run(["bash", "tools/git-hooks/post-merge"], cwd=self.clone, capture_output=True, text=True,
                           env={**os.environ, **self.env})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("failed", r.stderr)

    def test_old_backups_are_pruned_to_five(self):
        d = self.home / ".local/state/hyde-lite/backups"
        d.mkdir(parents=True)
        for i in range(7):
            (d / f"quickshell-2020010{i + 1}-000000").mkdir()
        (d / "something-else").mkdir()
        self.upstream(f"{SHELL}/a.qml", "v2\n")
        self.pull()
        names = self.backups()
        self.assertIn("something-else", names)
        mine = [n for n in names if n.startswith("quickshell-")]
        self.assertEqual(len(mine), 5)
        self.assertNotIn("quickshell-20200101-000000", mine)    # the oldest went
        self.assertTrue(any(n > "quickshell-2021" for n in mine))  # the new one is there


if __name__ == "__main__":
    unittest.main()
