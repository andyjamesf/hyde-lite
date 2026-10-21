"""Configs/.local/bin/wallpaper-library: the links into the theme wallpapers, and --own, which makes them files of
the folder (hard links) so the wallpapers survive the removal of a theme. Run:

    python3 -I tools/tests/test_wallpaper_library.py
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "Configs/.local/bin/wallpaper-library"


class Library(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.themes = self.tmp / "hyde/themes"
        self.pics = self.tmp / "Pictures"
        for theme, names in {"Alpha": ["a1.png", "wallpaper-1.png"], "Beta": ["wallpaper-1.png", "b1.jpg"]}.items():
            for n in names:
                f = self.themes / theme / "wallpapers" / n
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_bytes(f"{theme}/{n}".encode())
        self.dest = self.pics / "Wallpapers"
        self.dest.mkdir(parents=True)

    def run_lib(self, *args):
        env = dict(os.environ, HYDE_CONFIG_HOME=str(self.tmp / "hyde"), XDG_PICTURES_DIR=str(self.pics),
                   XDG_CACHE_HOME=str(self.tmp / "cache"))
        return subprocess.run(["bash", str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def names(self):
        return sorted(p.name for p in self.dest.iterdir())

    def test_links_are_named_theme_dash_file_and_idempotent(self):
        r = self.run_lib()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.names(), ["Alpha - a1.png", "Alpha - wallpaper-1.png", "Beta - b1.jpg", "Beta - wallpaper-1.png"])
        self.assertIn("4 new, 4 wallpapers", r.stdout)
        self.assertIn("0 new, 4 wallpapers", self.run_lib().stdout)

    def test_own_turns_links_into_hard_links_with_the_same_names_and_data(self):
        self.run_lib()
        r = self.run_lib("--own")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("4 links in", r.stdout)
        for p in self.dest.iterdir():
            self.assertFalse(p.is_symlink(), p.name)
        src = self.themes / "Beta/wallpapers/b1.jpg"
        mine = self.dest / "Beta - b1.jpg"
        self.assertEqual(mine.read_bytes(), b"Beta/b1.jpg")
        self.assertTrue(os.path.samefile(src, mine))             # one copy of the data on disk
        self.assertEqual(os.stat(mine).st_nlink, 2)

    def test_the_wallpapers_survive_removing_the_themes(self):
        self.run_lib()
        self.run_lib("--own")
        shutil.rmtree(self.themes)
        self.assertEqual((self.dest / "Alpha - a1.png").read_bytes(), b"Alpha/a1.png")
        self.assertEqual(len(self.names()), 4)
        r = self.run_lib()                                       # nothing to drop, nothing to add
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.names()), 4)

    def test_own_is_idempotent_and_a_later_default_run_adds_no_link(self):
        self.run_lib()
        self.run_lib("--own")
        self.assertIn("0 links in", self.run_lib("--own").stdout)
        self.assertIn("0 new, 4 wallpapers", self.run_lib().stdout)
        self.assertEqual([p for p in self.dest.iterdir() if p.is_symlink()], [])

    def test_own_leaves_a_broken_link_and_a_file_of_the_user_alone(self):
        self.run_lib()
        (self.dest / "mine.png").write_bytes(b"user's own")
        (self.themes / "Alpha/wallpapers/a1.png").unlink()       # its link is now broken
        r = self.run_lib("--own")
        self.assertIn("1 broken left as they are", r.stdout)
        self.assertTrue((self.dest / "Alpha - a1.png").is_symlink())
        self.assertEqual((self.dest / "mine.png").read_bytes(), b"user's own")
        self.assertEqual(os.stat(self.dest / "mine.png").st_nlink, 1)

    def test_own_removes_what_an_interrupted_run_left(self):
        self.run_lib()
        (self.dest / ".own.AbC123").write_bytes(b"half")
        self.run_lib("--own")
        self.assertFalse((self.dest / ".own.AbC123").exists())

    def test_clean_removes_only_links_not_owned_files(self):
        self.run_lib()
        self.run_lib("--own")
        self.run_lib("--clean")
        self.assertEqual(len(self.names()), 4)                   # files of the folder are never touched

    def test_unknown_option_prints_the_help_with_every_mode(self):
        r = self.run_lib("--nope")
        self.assertEqual(r.returncode, 2)
        for word in ("--own", "--clean", "next | prev | random"):
            self.assertIn(word, r.stderr + r.stdout)


if __name__ == "__main__":
    unittest.main()
