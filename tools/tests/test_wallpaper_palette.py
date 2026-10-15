"""Display-free tests for Configs/.local/bin/wallpaper-palette (PLAN 2.2).

The script runs as a subprocess against a throwaway HOME, with fake `matugen`, `magick` and
`wallbash-matugen` first on PATH. The fakes only count their calls, so what is checked is the script's
own logic: which mode/flag it writes, when it skips work, and what it caches. Run:

    python3 -I tools/tests/test_wallpaper_palette.py
"""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.local/bin/wallpaper-palette"

MATUGEN = """#!/bin/sh
echo "$*" >> "$STUB_LOG/matugen"
cat <<'JSON'
{"is_dark_mode": true, "colors": {
 "surface":   {"default": {"color": "#101010"}, "dark": {"color": "#101010"}, "light": {"color": "#f0f0f0"}},
 "primary":   {"default": {"color": "#aa0000"}, "dark": {"color": "#aa0000"}, "light": {"color": "#550000"}},
 "secondary": {"default": {"color": "#00aa00"}, "dark": {"color": "#00aa00"}, "light": {"color": "#005500"}},
 "tertiary":  {"default": {"color": "#0000aa"}, "dark": {"color": "#0000aa"}, "light": {"color": "#000055"}}}}
JSON
"""
MAGICK = """#!/bin/sh
echo "$*" >> "$STUB_LOG/magick"
for last; do :; done
: > "$last"
"""
REBUILD = """#!/bin/sh
echo run >> "$STUB_LOG/wallbash-matugen"
"""


class PaletteTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(self.tmp.name)
        self.home = root / "home"
        self.log = root / "log"
        bindir = root / "bin"
        for d in (self.home, self.log, bindir):
            d.mkdir()
        for name, body in (("matugen", MATUGEN), ("magick", MAGICK), ("wallbash-matugen", REBUILD)):
            (bindir / name).write_text(body)
            (bindir / name).chmod(0o755)
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{bindir}:/usr/bin:/bin",
            "STUB_LOG": str(self.log),
        }
        cache = self.home / ".cache"
        (cache / "hyde").mkdir(parents=True)
        self.wall = root / "wall.png"
        self.wall.write_bytes(b"not really an image")
        (cache / "hyde" / "wall.set").symlink_to(self.wall)
        self.staterc = self.home / ".local/state/hyde/staterc"
        self.prefs = self.home / ".local/state/morphing-island/prefs.json"

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, *args):
        done = subprocess.run([sys.executable, "-I", str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        return done.stdout.strip()

    def calls(self, name):
        f = self.log / name
        return len(f.read_text().splitlines()) if f.exists() else 0

    def write_flag(self, value):
        self.staterc.parent.mkdir(parents=True, exist_ok=True)
        self.staterc.write_text(f'hydeTheme="x"\nenableWallDcol="{value}"\nother=1\n')

    def flag(self):
        for line in self.staterc.read_text().splitlines():
            if line.startswith("enableWallDcol="):
                return line.split("=", 1)[1].strip('"')

    def test_mode_and_flag_stay_in_step(self):
        self.write_flag(1)
        self.run_script("mode", "light")
        self.assertEqual(json.loads(self.prefs.read_text())["theme.mode"], "light")
        self.assertEqual(self.flag(), "3")
        self.run_script("mode", "dark")
        self.assertEqual(self.flag(), "2")
        self.run_script("mode", "auto")
        self.assertEqual(self.flag(), "1")
        self.assertIn("other=1", self.staterc.read_text())

    def test_flag_at_zero_is_left_alone(self):
        self.write_flag(0)
        self.run_script("mode", "light")
        self.assertEqual(json.loads(self.prefs.read_text())["theme.mode"], "light")
        self.assertEqual(self.flag(), "0")

    def test_missing_staterc_is_not_an_error(self):
        self.run_script("mode", "dark")
        self.assertFalse(self.staterc.exists())

    def test_second_apply_with_same_inputs_does_nothing(self):
        self.run_script("apply")
        self.assertEqual(self.calls("matugen"), 1)
        self.run_script("apply")
        self.assertEqual(self.calls("matugen"), 1)
        self.run_script("apply", "--force")
        self.assertEqual(self.calls("matugen"), 2)

    def test_changed_input_regenerates(self):
        self.run_script("apply")
        self.run_script("mode", "light")
        self.assertEqual(self.calls("matugen"), 2)
        self.run_script("next")
        self.assertEqual(self.calls("matugen"), 3)

    def test_auto_asks_matugen_for_smart_and_modes_pass_through(self):
        self.run_script("apply")
        self.run_script("mode", "light")
        lines = (self.log / "matugen").read_text().splitlines()
        self.assertIn("-m smart", lines[0])
        self.assertIn("-m light", lines[1])

    def test_preview_caches_per_wallpaper_not_per_mode(self):
        self.run_script("mode", "dark")
        before = self.calls("matugen")
        out = self.run_script("preview").splitlines()
        self.assertEqual(out[0].split("\t")[0], "@@CURRENT@@")
        self.assertEqual(len(out) - 1, 10)
        self.assertEqual(self.calls("matugen") - before, 10)
        # Same wallpaper, other mode: the swatches already hold both polarities.
        self.run_script("mode", "light")
        after_mode = self.calls("matugen")
        self.run_script("preview")
        self.assertEqual(self.calls("matugen"), after_mode)
        # A different wallpaper is a new cache entry.
        self.wall.write_bytes(b"another, longer, fake image")
        self.run_script("preview")
        self.assertEqual(self.calls("matugen") - after_mode, 10)

    def test_unknown_scheme_is_refused(self):
        done = subprocess.run([sys.executable, "-I", str(SCRIPT), "set", "scheme-nope"], env=self.env,
                              capture_output=True, text=True)
        self.assertNotEqual(done.returncode, 0)


if __name__ == "__main__":
    os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
    unittest.main(verbosity=1)
