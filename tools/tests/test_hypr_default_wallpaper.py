"""Configs/.local/bin/hypr-default-wallpaper: points Hyprland's three default pictures at the user's wallpaper,
keeps the originals, writes a pacman hook that never runs a file of the user's, and puts everything back. All
paths are under HDW_ROOT, so nothing outside a temporary folder is touched. Run:

    python3 -I tools/tests/test_hypr_default_wallpaper.py
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "Configs/.local/bin/hypr-default-wallpaper"
WALLS = ["wall0.png", "wall1.png", "wall2.png"]


class DefaultWallpaper(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.root = self.tmp / "root"
        self.share = self.root / "usr/share/hypr"
        self.share.mkdir(parents=True)
        for w in WALLS:
            (self.share / w).write_bytes(f"original {w}".encode())
        self.image = self.tmp / "home/cache/wall.set"
        self.image.parent.mkdir(parents=True)
        self.image.write_bytes(b"the wallpaper")
        self.hook = self.root / "etc/pacman.d/hooks/hypr-default-wallpaper.hook"
        self.state = self.root / "var/lib/hypr-default-wallpaper"

    def run_script(self, *args, root=True):
        env = dict(os.environ, HOME=str(self.tmp / "home"))
        env.pop("HDW_ROOT", None)
        if root:
            env["HDW_ROOT"] = str(self.root)
        return subprocess.run(["bash", str(SCRIPT), *args], capture_output=True, text=True, env=env)

    def install(self, image=None):
        r = self.run_script("install", str(image or self.image))
        self.assertEqual(r.returncode, 0, r.stderr)
        return r

    def test_install_links_the_three_files_and_keeps_the_originals(self):
        self.install()
        for w in WALLS:
            self.assertTrue((self.share / w).is_symlink(), w)
            self.assertEqual((self.share / w).read_bytes(), b"the wallpaper")
            self.assertEqual((self.state / w).read_bytes(), f"original {w}".encode())

    def test_the_link_follows_the_image_when_it_changes(self):
        self.install()
        self.image.write_bytes(b"another one")
        self.assertEqual((self.share / "wall1.png").read_bytes(), b"another one")

    def test_a_second_install_does_not_replace_the_backup_with_a_link(self):
        self.install()
        self.install()
        self.assertEqual((self.state / "wall0.png").read_bytes(), b"original wall0.png")

    def test_the_hook_runs_ln_with_absolute_paths_and_no_file_of_the_user(self):
        self.install()
        text = self.hook.read_text()
        self.assertIn("Target = hyprland", text)
        self.assertIn("When = PostTransaction", text)
        exec_line = next(l for l in text.splitlines() if l.startswith("Exec"))
        self.assertEqual(exec_line.split("=", 1)[1].split("'")[0].strip(), "/usr/bin/sh -c")
        for w in WALLS:
            self.assertIn(f"/usr/share/hypr/{w}", exec_line)
        self.assertIn(f"ln -sf {self.image}", exec_line)
        self.assertNotIn("hypr-default-wallpaper ", exec_line)        # the script itself is not what root runs

    def test_uninstall_puts_everything_back(self):
        self.install()
        r = self.run_script("uninstall")
        self.assertEqual(r.returncode, 0, r.stderr)
        for w in WALLS:
            self.assertFalse((self.share / w).is_symlink())
            self.assertEqual((self.share / w).read_bytes(), f"original {w}".encode())
        self.assertFalse(self.hook.exists())
        self.assertFalse(self.state.exists())

    def test_it_refuses_a_missing_image_a_relative_one_and_a_path_with_spaces(self):
        for image in (self.tmp / "nope", "relative.png", self.tmp / "a b.png"):
            r = self.run_script("install", str(image))
            self.assertEqual(r.returncode, 1, image)
        self.assertFalse(self.hook.exists())
        self.assertFalse((self.share / "wall0.png").is_symlink())

    def test_without_root_it_says_to_use_sudo_and_writes_nothing(self):
        r = self.run_script("install", str(self.image), root=False)
        if os.geteuid() != 0:
            self.assertEqual(r.returncode, 1)
            self.assertIn("sudo", r.stderr)

    def test_status_says_what_each_file_is(self):
        out = self.run_script("status").stdout
        self.assertIn("wall0.png: the package's own picture", out)
        self.assertIn("pacman hook: not installed", out)
        self.install()
        out = self.run_script("status").stdout
        self.assertIn("(file: wall.set)", out)
        self.assertIn("pacman hook: installed", out)
        self.image.unlink()
        self.assertIn("MISSING TARGET", self.run_script("status").stdout)


if __name__ == "__main__":
    unittest.main()
