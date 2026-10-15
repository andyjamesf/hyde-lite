"""The README banner and the wallpapers: structure of the committed GIF, the animation timeline, and that the
wallpaper generator still reproduces the committed pictures. Skipped without numpy and Pillow. Run:

    python3 -I tools/tests/test_banner.py

NOT TESTED here: that tools/gen_banner.py reproduces the committed GIF byte for byte (needs the Inter font,
and glyph rendering differs between Pillow and FreeType versions).
"""
import importlib.util
import pathlib
import tempfile
import unittest

try:
    import numpy as np
    from PIL import Image, ImageSequence
except ImportError:  # pragma: no cover
    np = None

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools"
GIF = ROOT / "docs/images/banner.gif"


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@unittest.skipIf(np is None, "numpy and Pillow are not installed")
class Timeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gb = load("gen_banner")
        cls.steps = cls.gb.timeline()

    def test_total_is_whole_skyline_loops(self):
        """Otherwise the stars and windows would jump every time the GIF repeats."""
        total = sum(s[0] for s in self.steps)
        self.assertEqual(total % (self.gb.FRAMES * self.gb.FRAME_MS), 0, total)

    def test_durations_survive_the_gif_format(self):
        """GIF counts in 10 ms units; anything else is silently rounded and the loop drifts."""
        self.assertEqual([s[0] for s in self.steps if s[0] % 10], [])

    def test_every_state_is_shown_and_the_show_closes(self):
        shown = [s[1] for s in self.steps if s[1] == s[2]]
        self.assertEqual(sorted(set(shown)), sorted(self.gb.ORDER))
        morphs = {(s[1], s[2]) for s in self.steps if s[1] != s[2]}
        expected = {(a, self.gb.ORDER[(i + 1) % len(self.gb.ORDER)]) for i, a in enumerate(self.gb.ORDER)}
        self.assertEqual(morphs, expected)

    def test_morph_progress_ends_at_one(self):
        for a, b in {(s[1], s[2]) for s in self.steps if s[1] != s[2]}:
            progress = [s[3] for s in self.steps if (s[1], s[2]) == (a, b)]
            self.assertEqual(progress, sorted(progress))
            self.assertEqual(progress[-1], 1.0)

    def test_easing_is_monotonic_and_pinned(self):
        values = [self.gb.ease(i / 20) for i in range(21)]
        self.assertEqual((values[0], values[-1]), (0, 1))
        self.assertEqual(values, sorted(values))


@unittest.skipIf(np is None, "numpy and Pillow are not installed")
class CommittedGif(unittest.TestCase):
    def test_structure(self):
        gb = load("gen_banner")
        with Image.open(GIF) as im:
            self.assertEqual(im.size, (gb.W, gb.H))
            self.assertEqual(im.info.get("loop"), 0, "must loop for ever")
            durations = [f.info["duration"] for f in ImageSequence.Iterator(im)]
        self.assertGreater(len(durations), 60)
        self.assertEqual(sum(durations), sum(s[0] for s in gb.timeline()))

    def test_it_moves(self):
        with Image.open(GIF) as im:
            frames = [np.asarray(f.convert("RGB")).astype(int) for f in ImageSequence.Iterator(im)][::10]
        changed = [int((np.abs(a - b).sum(axis=2) > 0).sum()) for a, b in zip(frames, frames[1:], strict=False)]
        self.assertTrue(all(c > 100 for c in changed), changed)

    def test_size_is_reasonable_for_a_readme(self):
        self.assertLess(GIF.stat().st_size, 1024 * 1024)


@unittest.skipIf(np is None, "numpy and Pillow are not installed")
class Wallpapers(unittest.TestCase):
    def test_generator_still_reproduces_a_committed_wallpaper(self):
        """height_scale was added for the banner; its default must leave the wallpapers untouched."""
        gw = load("gen_wallpapers")
        name = "City Midnight"
        img = gw.SPECS[name]().resize((gw.PW * gw.SCALE, gw.PH * gw.SCALE), Image.NEAREST)
        committed = Image.open(ROOT / "Wallpapers" / f"{name}.png").convert("RGB")
        self.assertEqual(img.size, committed.size)
        self.assertTrue(np.array_equal(np.asarray(img.convert("RGB")), np.asarray(committed)))

    def test_every_wallpaper_is_documented(self):
        listed = (ROOT / "Wallpapers/SOURCES.md").read_text(encoding="utf-8")
        for png in sorted((ROOT / "Wallpapers").glob("*.png")):
            self.assertIn(png.name, listed)

    def test_generator_writes_to_a_directory(self):
        gw = load("gen_wallpapers")
        with tempfile.TemporaryDirectory() as d:
            img = gw.SPECS["City Day"]()
            self.assertEqual(img.size, (gw.PW, gw.PH))
            img.save(pathlib.Path(d) / "x.png")


if __name__ == "__main__":
    unittest.main()
