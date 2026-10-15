"""tools/screenshots.sh against a fake grim: scaling, README switch-on, refusal to overwrite, --list."""
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

README = """# t
<!-- ![The Morphing Island](docs/images/hero.png) -->
![bar](docs/images/bar-islands.png) <!-- hero-fallback -->
<!-- ![Launcher](docs/images/island-launcher.png) -->
"""
SPEC = """| File | What |
|---|---|
| `hero.png` | the desktop |
| `island-launcher.png` | the launcher open (`Super+A`) |
| `bar-islands.png` | the bar |
"""


@unittest.skipUnless(shutil.which("convert") or shutil.which("magick"), "ImageMagick missing")
class ScreenshotsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "tools").mkdir()
        shutil.copy(ROOT / "tools/screenshots.sh", self.tmp / "tools/screenshots.sh")
        (self.tmp / "docs/images").mkdir(parents=True)
        (self.tmp / "docs/images/README.md").write_text(SPEC)
        (self.tmp / "docs/images/bar-islands.png").write_bytes(b"x")
        (self.tmp / "README.md").write_text(README)
        bindir = self.tmp / "bin"
        bindir.mkdir()
        im = "magick" if shutil.which("magick") else "convert"
        grim = bindir / "grim"
        # the last argument is the output file; make a 3000x1800 image there
        grim.write_text(f'#!/bin/sh\nfor a; do out="$a"; done\nexec {im} -size 3000x1800 xc:navy "$out"\n')
        grim.chmod(grim.stat().st_mode | stat.S_IXUSR)
        self.env = dict(os.environ, PATH=f"{bindir}:{os.environ['PATH']}")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_script(self, *args):
        return subprocess.run(["bash", str(self.tmp / "tools/screenshots.sh"), "--delay", "0", *args],
                              env=self.env, capture_output=True, text=True, stdin=subprocess.DEVNULL)

    def test_list_marks_done_and_missing(self):
        out = self.run_script("--list").stdout
        self.assertIn("bar-islands", out)
        self.assertRegex(out, r"bar-islands\s+done")
        self.assertRegex(out, r"island-launcher\s+the launcher open")

    def test_capture_scales_and_enables_readme_line(self):
        r = self.run_script("island-launcher")
        self.assertEqual(r.returncode, 0, r.stderr)
        png = self.tmp / "docs/images/island-launcher.png"
        size = subprocess.run(["identify", "-format", "%w", str(png)], capture_output=True, text=True).stdout
        self.assertEqual(size, "1920")
        text = (self.tmp / "README.md").read_text()
        self.assertIn("\n![Launcher](docs/images/island-launcher.png)\n", text)
        self.assertIn("<!-- ![The Morphing Island]", text)  # hero untouched

    def test_hero_replaces_fallback(self):
        self.assertEqual(self.run_script("hero").returncode, 0)
        text = (self.tmp / "README.md").read_text()
        self.assertIn("\n![The Morphing Island](docs/images/hero.png)\n", text)
        self.assertNotIn("hero-fallback", text)

    def test_existing_file_is_not_replaced_without_force(self):
        before = (self.tmp / "docs/images/bar-islands.png").read_bytes()
        r = self.run_script("bar-islands")
        self.assertIn("exists", r.stdout)
        self.assertEqual((self.tmp / "docs/images/bar-islands.png").read_bytes(), before)
        self.assertEqual(self.run_script("bar-islands", "--force").returncode, 0)
        self.assertNotEqual((self.tmp / "docs/images/bar-islands.png").read_bytes(), before)

    def test_unknown_shot_fails(self):
        r = self.run_script("nope")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("unknown shot", r.stderr)

    def test_no_readme_flag_leaves_readme_alone(self):
        self.run_script("island-launcher", "--no-readme")
        self.assertEqual((self.tmp / "README.md").read_text(), README)


if __name__ == "__main__":
    unittest.main()
