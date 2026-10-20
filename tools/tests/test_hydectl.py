"""Display-free tests for Configs/.local/bin/hydectl, and a guard against committing binaries. Run:

    python3 -I tools/tests/test_hydectl.py

hydectl only calls `hyde-shell` (and `hyprctl reload`), so the tests point HYDECTL_SHELL at `echo` and read what
it would have been asked to run.
"""
import os
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Configs/.local/bin/hydectl"


def hydectl(*args):
    env = {**os.environ, "HYDECTL_SHELL": "echo"}
    return subprocess.run([str(SCRIPT), *args], env=env, capture_output=True, text=True)


class Hydectl(unittest.TestCase):
    def test_theme_next_prev_set_import(self):
        self.assertEqual(hydectl("theme", "next").stdout.strip(), "theme.switch.sh -n")
        self.assertEqual(hydectl("theme", "prev").stdout.strip(), "theme.switch.sh -p")
        self.assertEqual(hydectl("theme", "set", "Nordic Blue").stdout.strip(), "theme.switch.sh -s Nordic Blue")
        self.assertEqual(hydectl("theme", "import").stdout.strip(), "theme.import")

    def test_wallpaper_next_prev_set(self):
        self.assertEqual(hydectl("wallpaper", "next").stdout.strip(), "wallpaper.sh -n --global")
        self.assertEqual(hydectl("wallpaper", "prev").stdout.strip(), "wallpaper.sh -p --global")
        self.assertEqual(hydectl("wallpaper", "set", "/a b.png").stdout.strip(), "wallpaper.sh -s /a b.png --global")

    def test_a_missing_argument_is_an_error_not_a_silent_no_op(self):
        for args in (("theme", "set"), ("wallpaper", "set"), ("theme",), ("wallpaper", "sideways")):
            done = hydectl(*args)
            self.assertEqual(done.returncode, 2, args)
            self.assertTrue(done.stderr.startswith("hydectl:"), args)

    def test_unknown_command_and_help(self):
        self.assertEqual(hydectl("nope").returncode, 2)
        self.assertIn("hydectl theme next|prev", hydectl("help").stdout)
        self.assertEqual(hydectl().returncode, 0)

    def test_version(self):
        self.assertRegex(hydectl("version").stdout, r"^hydectl \d+\.\d+\.\d+$")


class NoBinaries(unittest.TestCase):
    def test_no_elf_executable_is_tracked(self):
        files = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True,
                               check=True).stdout.split("\0")
        elf = [f for f in files if f and (ROOT / f).is_file() and not (ROOT / f).is_symlink()
               and (ROOT / f).read_bytes()[:4] == b"\x7fELF"]
        self.assertEqual(elf, [], "write it as a script, or fetch it at install time with a pinned checksum")


if __name__ == "__main__":
    unittest.main()
