"""tools/sync_shell.py: dry run writes nothing, apply backs up first, never deletes, follows a link, skips caches."""
import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("sync_shell", Path(__file__).resolve().parents[1] / "sync_shell.py")
sync = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sync)


def write(p, text):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


class Sync(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__("shutil").rmtree(self.tmp, ignore_errors=True))
        self.src = self.tmp / "src"
        self.dst = self.tmp / "dst"
        write(self.src / "a.qml", "new a\n")
        write(self.src / "sub/b.qml", "same b\n")
        write(self.src / "c.qml", "brand new c\n")
        write(self.src / "__pycache__/x.txt", "junk")
        write(self.dst / "a.qml", "old a\n")
        write(self.dst / "sub/b.qml", "same b\n")
        write(self.dst / "mine.qml", "only mine\n")

    def test_plan_classifies_and_skips_caches(self):
        new, changed, same, extra = sync.plan(self.src, self.dst)
        self.assertEqual([str(p) for p in new], ["c.qml"])
        self.assertEqual([str(p) for p in changed], ["a.qml"])
        self.assertEqual([str(p) for p in same], [os.path.join("sub", "b.qml")])
        self.assertEqual([str(p) for p in extra], ["mine.qml"])

    def test_apply_backs_up_first_and_never_deletes(self):
        backup = self.tmp / "bk"
        sync.apply(self.src, self.dst, backup)
        self.assertEqual((backup / "a.qml").read_text(), "old a\n")           # the old content is kept
        self.assertEqual((backup / "mine.qml").read_text(), "only mine\n")
        self.assertFalse((backup / "c.qml").exists())                         # taken before anything was added
        self.assertEqual((self.dst / "a.qml").read_text(), "new a\n")
        self.assertEqual((self.dst / "c.qml").read_text(), "brand new c\n")
        self.assertEqual((self.dst / "mine.qml").read_text(), "only mine\n")  # not deleted
        self.assertFalse((self.dst / "__pycache__").exists())

    def run_main(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            sync.REPO = self.tmp / "repo"
            rc = sync.main(list(args))
        return rc, out.getvalue(), err.getvalue()

    def fake_repo(self):
        repo = self.tmp / "repo/Configs/.config/quickshell"
        repo.parent.mkdir(parents=True)
        os.symlink(self.src, repo)

    def test_dry_run_writes_nothing(self):
        self.fake_repo()
        rc, out, _ = self.run_main("--target", str(self.dst), "--backup-dir", str(self.tmp / "bk"))
        self.assertEqual(rc, 0)
        self.assertIn("1 new, 1 changed", out)
        self.assertEqual((self.dst / "a.qml").read_text(), "old a\n")
        self.assertFalse((self.dst / "c.qml").exists())
        self.assertFalse((self.tmp / "bk").exists())

    def test_apply_then_apply_again_is_a_noop(self):
        self.fake_repo()
        rc, out, _ = self.run_main("--target", str(self.dst), "--apply", "--backup-dir", str(self.tmp / "bk"))
        self.assertEqual(rc, 0)
        self.assertIn("1 added, 1 overwritten", out)
        self.assertIn("to undo: cp -a", out)
        rc, out, _ = self.run_main("--target", str(self.dst), "--apply", "--backup-dir", str(self.tmp / "bk2"))
        self.assertIn("already up to date", out)
        self.assertFalse((self.tmp / "bk2").exists())

    def test_a_linked_target_is_followed(self):
        self.fake_repo()
        link = self.tmp / "link"
        os.symlink(self.dst, link)
        rc, out, _ = self.run_main("--target", str(link), "--apply", "--backup-dir", str(self.tmp / "bk"))
        self.assertEqual(rc, 0)
        self.assertTrue(link.is_symlink())                       # the link itself is untouched
        self.assertEqual((self.dst / "a.qml").read_text(), "new a\n")
        self.assertIn("via", out)

    def test_refuses_its_own_copy_and_a_missing_target(self):
        self.fake_repo()
        rc, _, err = self.run_main("--target", str(self.src))
        self.assertEqual(rc, 2)
        self.assertIn("own copy", err)
        rc, _, err = self.run_main("--target", str(self.tmp / "nope"))
        self.assertEqual(rc, 2)

    def test_quiet_prints_one_line(self):
        self.fake_repo()
        rc, out, _ = self.run_main("--target", str(self.dst), "--apply", "--quiet", "--backup-dir", str(self.tmp / "bk"))
        self.assertEqual(rc, 0)
        self.assertEqual(len(out.strip().splitlines()), 1, out)
        self.assertIn("updated (1 added, 1 overwritten)", out)
        rc, out, _ = self.run_main("--target", str(self.dst), "--apply", "--quiet", "--backup-dir", str(self.tmp / "bk2"))
        self.assertEqual(out.strip(), "quickshell: already up to date")

    def test_prune_keeps_the_newest_and_leaves_other_things(self):
        d = self.tmp / "backups"
        for i in range(1, 8):
            (d / f"quickshell-2020010{i}-000000").mkdir(parents=True)
        (d / "morphing-island-20200101-000000").mkdir()              # a backup from before the two shells merged
        (d / "quickshell-notes").mkdir()
        (d / "quickshell-20200108-000000").write_text("a file with a matching name")
        gone = sync.prune_backups(d, "quickshell", 3)
        self.assertEqual([p.name for p in gone], [f"quickshell-2020010{i}-000000" for i in (1, 2, 3, 4)])
        left = sorted(p.name for p in d.iterdir())
        self.assertIn("morphing-island-20200101-000000", left)
        self.assertIn("quickshell-notes", left)
        self.assertIn("quickshell-20200108-000000", left)            # a file is not a backup folder
        self.assertEqual(sync.prune_backups(d, "quickshell", 10), [])

    def test_apply_with_keep_prunes_after_the_backup(self):
        self.fake_repo()
        bk = self.tmp / "backups"
        for i in range(1, 4):
            (bk / f"quickshell-2020010{i}-000000").mkdir(parents=True)
        rc, out, _ = self.run_main("--target", str(self.dst), "--apply", "--keep", "2",
                                   "--backup-dir", str(bk / "quickshell-20300101-000000"))
        self.assertEqual(rc, 0)
        self.assertEqual(sorted(p.name for p in bk.iterdir()), ["quickshell-20200103-000000", "quickshell-20300101-000000"])
        self.assertIn("removed 2 older backup", out)

    def test_diff_shows_changed_files(self):
        self.fake_repo()
        rc, out, _ = self.run_main("--target", str(self.dst), "--diff")
        self.assertIn("-old a", out)
        self.assertIn("+new a", out)


if __name__ == "__main__":
    unittest.main()
