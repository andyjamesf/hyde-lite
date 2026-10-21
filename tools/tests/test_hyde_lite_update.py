"""Configs/.local/bin/hyde-lite (the updater), against throwaway git repositories: an origin, a checkout with a
stub install.sh that only records how it was called, and stub hyprctl / island / qs. Run:

    python3 -I tools/tests/test_hyde_lite_update.py
"""
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "Configs/.local/bin/hyde-lite"
GIT_ENV = {"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
           "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid"}


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True, check=True,
                          env={**os.environ, **GIT_ENV}).stdout.strip()


def stub(path, body):
    path.write_text("#!/bin/sh\n" + body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


class Updater(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.log = self.tmp / "calls.log"
        self.state = self.tmp / "state"
        (self.state / "morphing-island").mkdir(parents=True)
        (self.state / "morphing-island/active").touch()                      # the island is in use
        bare = self.tmp / "origin.git"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
        self.work = self.tmp / "work"
        subprocess.run(["git", "clone", "-q", str(bare), str(self.work)], check=True, capture_output=True)
        stub(self.work / "install.sh", f'echo "install $@" >> {self.log}\nexit ${{STUB_RC:-0}}\n')
        (self.work / "tools/git-hooks").mkdir(parents=True)
        stub(self.work / "tools/git-hooks/post-merge",
             f'[ "$HYDE_LITE_NO_SYNC" = 1 ] || echo "hook ran" >> {self.log}\n')
        (self.work / "README.md").write_text("one\n")
        git(self.work, "checkout", "-q", "-b", "main")
        git(self.work, "add", "-A")
        git(self.work, "commit", "-q", "-m", "base")
        git(self.work, "push", "-q", "origin", "main")
        self.dir = self.tmp / "checkout"
        subprocess.run(["git", "clone", "-q", str(bare), str(self.dir)], check=True, capture_output=True)
        git(self.dir, "config", "core.hooksPath", "tools/git-hooks")
        git(self.dir, "branch", "-q", "--set-upstream-to=origin/main", "main")
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        for name in ("hyprctl", "island", "qs"):
            stub(self.bin / name, f'echo "{name} $@" >> {self.log}\n')

    def upstream(self, path, text, msg="change"):
        (self.work / path).parent.mkdir(parents=True, exist_ok=True)
        (self.work / path).write_text(text)
        git(self.work, "add", "-A")
        git(self.work, "commit", "-q", "-m", msg)
        git(self.work, "push", "-q", "origin", "main")

    def mark_installed(self):
        self.state.joinpath("hyde-lite").mkdir(exist_ok=True)
        (self.state / "hyde-lite/installed").write_text(git(self.dir, "rev-parse", "HEAD") + "\n")

    def installed(self):
        f = self.state / "hyde-lite/installed"
        return f.read_text().strip() if f.exists() else None

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def run_it(self, *args, env=None, bar=False):
        if bar:
            (self.state / "morphing-island/active").unlink()
        e = {**os.environ, "HYDE_LITE_DIR": str(self.dir), "XDG_STATE_HOME": str(self.state),
             "PATH": f"{self.bin}:{os.environ['PATH']}", **(env or {})}
        return subprocess.run(["bash", str(SCRIPT), *args], capture_output=True, text=True, env=e, stdin=subprocess.DEVNULL)

    def test_nothing_new_and_already_installed_does_nothing(self):
        self.mark_installed()
        r = self.run_it("update")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("up to date", r.stdout)
        self.assertEqual(self.calls(), [])

    def test_without_a_record_it_installs_once_to_make_one(self):
        r = self.run_it("update")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls(), ["install --island --no-services"])
        self.assertEqual(self.installed(), git(self.dir, "rev-parse", "HEAD"))
        self.assertIn("to load it: hyprctl reload", r.stdout)            # unknown what changed: both hints
        self.assertIn("island off && island on", r.stdout)

    def test_an_update_pulls_lists_installs_and_says_what_to_reload(self):
        self.mark_installed()
        self.upstream("Configs/.config/hypr/a.lua", "x\n", "hypr change")
        self.upstream("Configs/.config/quickshell/island/a.qml", "y\n", "island change")
        r = self.run_it("update")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("2 new commit(s)", r.stdout)
        self.assertIn("hypr change", r.stdout)
        self.assertEqual(self.calls(), ["install --island --no-services"])      # and no pull hook: installer does it
        self.assertEqual(git(self.dir, "rev-parse", "HEAD"), git(self.dir, "rev-parse", "origin/main"))
        self.assertEqual(self.installed(), git(self.dir, "rev-parse", "HEAD"))
        self.assertIn("to load it: hyprctl reload", r.stdout)
        self.assertIn("island off && island on", r.stdout)

    def test_restart_does_the_reloads_the_update_needs(self):
        self.mark_installed()
        self.upstream("Configs/.config/hypr/a.lua", "x\n")
        self.upstream("Configs/.config/quickshell/bar/a.qml", "y\n")
        r = self.run_it("update", "--restart")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls(), ["install --island --no-services", "hyprctl reload", "island off", "island on"])

    def test_a_bar_user_gets_bar_and_the_bar_reload(self):
        self.mark_installed()
        self.upstream("Configs/.config/quickshell/bar/a.qml", "y\n")
        r = self.run_it("update", "--restart", bar=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls(), ["install --bar --no-services", "qs ipc call shell reload"])

    def test_only_documents_changed_means_nothing_to_reload(self):
        self.mark_installed()
        self.upstream("README.md", "two\n")
        r = self.run_it("update", "--restart")
        self.assertIn("nothing to reload", r.stdout)
        self.assertEqual(self.calls(), ["install --island --no-services"])

    def test_changes_of_its_own_stop_it_before_anything_happens(self):
        self.mark_installed()
        self.upstream("README.md", "two\n")
        (self.dir / "README.md").write_text("mine\n")
        before = git(self.dir, "rev-parse", "HEAD")
        r = self.run_it("update")
        self.assertEqual(r.returncode, 1)
        self.assertIn("changes of its own", r.stderr)
        self.assertEqual(git(self.dir, "rev-parse", "HEAD"), before)
        self.assertEqual(self.calls(), [])
        self.assertEqual((self.dir / "README.md").read_text(), "mine\n")

    def test_a_diverged_main_stops_it(self):
        self.mark_installed()
        (self.dir / "local.txt").write_text("l\n")
        git(self.dir, "add", "-A")
        git(self.dir, "commit", "-q", "-m", "local only")
        self.upstream("README.md", "two\n")
        r = self.run_it("update")
        self.assertEqual(r.returncode, 1)
        self.assertIn("diverged", r.stderr)
        self.assertEqual(self.calls(), [])

    def test_another_branch_stops_it(self):
        git(self.dir, "switch", "-q", "-c", "work")
        r = self.run_it("update")
        self.assertEqual(r.returncode, 1)
        self.assertIn("not main", r.stderr)

    def test_a_failed_installer_is_not_recorded_and_runs_again_next_time(self):
        self.mark_installed()
        old = self.installed()
        self.upstream("README.md", "two\n")
        r = self.run_it("update", env={"STUB_RC": "1"})
        self.assertEqual(r.returncode, 1)
        self.assertIn("installer reported a problem", r.stderr)
        self.assertEqual(self.installed(), old)
        self.log.unlink()
        r = self.run_it("update")                      # git has nothing new, the install is still owed
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.calls(), ["install --island --no-services"])
        self.assertEqual(self.installed(), git(self.dir, "rev-parse", "HEAD"))

    def test_check_reports_and_changes_nothing(self):
        self.mark_installed()
        self.upstream("README.md", "two\n")
        before = git(self.dir, "rev-parse", "HEAD")
        r = self.run_it("update", "--check")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("1 new commit(s)", r.stdout)
        self.assertIn("run: hyde-lite update", r.stdout)
        self.assertEqual(git(self.dir, "rev-parse", "HEAD"), before)
        self.assertEqual(self.calls(), [])

    def test_where_follows_the_record_then_the_environment(self):
        r = self.run_it("where")
        self.assertEqual(r.stdout.strip(), str(self.dir))
        (self.state / "hyde-lite").mkdir()
        (self.state / "hyde-lite/repo").write_text("/somewhere/else\n")
        e = {**os.environ, "XDG_STATE_HOME": str(self.state), "PATH": os.environ["PATH"]}
        e.pop("HYDE_LITE_DIR", None)
        r = subprocess.run(["bash", str(SCRIPT), "where"], capture_output=True, text=True, env=e)
        self.assertEqual(r.stdout.strip(), "/somewhere/else")

    def test_an_unknown_option_and_no_arguments(self):
        self.assertEqual(self.run_it("update", "--nope").returncode, 1)
        r = self.run_it()
        self.assertEqual(r.returncode, 0)
        self.assertIn("hyde-lite update", r.stdout)


if __name__ == "__main__":
    unittest.main()
