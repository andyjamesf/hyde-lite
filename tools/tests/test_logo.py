"""docs/images/logo.gif: the README logo. Structure of the committed GIF, that it moves, that the loop closes, that
the letters are partly (but only partly) hidden by the city, that every shooting star finishes inside the loop,
and that the generator reproduces the committed file. Skipped without numpy and Pillow. Run:

    python3 -I tools/tests/test_logo.py
"""
import importlib.util
import pathlib
import unittest

try:
    import numpy as np
    from PIL import Image, ImageSequence
except ImportError:  # pragma: no cover
    np = None

ROOT = pathlib.Path(__file__).resolve().parents[2]
GIF = ROOT / "docs/images/logo.gif"


def load():
    spec = importlib.util.spec_from_file_location("gen_logo", ROOT / "tools/gen_logo.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def decode(path):
    with Image.open(path) as im:
        return [np.asarray(f.convert("RGB")).astype(int) for f in ImageSequence.Iterator(im)]


@unittest.skipIf(np is None, "numpy and Pillow are not installed")
class Logo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gl = load()
        cls.frames = decode(GIF)

    def test_structure(self):
        gl = self.gl
        with Image.open(GIF) as im:
            self.assertEqual(im.size, (gl.GRID_W * gl.SCALE, gl.GRID_H * gl.SCALE))
            self.assertEqual(im.info.get("loop"), 0, "must loop for ever")
            durations = [f.info["duration"] for f in ImageSequence.Iterator(im)]
        self.assertEqual(len(self.frames), gl.FRAMES)
        self.assertEqual(sum(durations), gl.FRAMES * gl.FRAME_MS)
        self.assertEqual(gl.FRAME_MS % 10, 0, "GIF counts in units of 10 ms")
        self.assertLess(GIF.stat().st_size, 1024 * 1024)

    def test_it_moves(self):
        changed = [int((np.abs(a - b).sum(axis=2) > 0).sum()) for a, b in zip(self.frames, self.frames[1:], strict=False)]
        self.assertTrue(min(changed) > 20, min(changed))
        # a shooting star is on screen around frame 14 and not at frame 40
        self.assertGreater(int((np.abs(self.frames[14] - self.frames[40]).sum(axis=2) > 0).sum()), 400)

    def test_the_loop_closes_without_a_jump(self):
        steps = [int((np.abs(a - b).sum(axis=2) > 0).sum()) for a, b in zip(self.frames, self.frames[1:], strict=False)]
        wrap = int((np.abs(self.frames[-1] - self.frames[0]).sum(axis=2) > 0).sum())
        self.assertLess(wrap, 2.5 * max(steps), (wrap, max(steps)))

    def test_every_shooting_star_finishes_inside_the_loop(self):
        for sx, sy, _vx, _vy, t0, dur in self.gl.SHOOTING:
            self.assertGreaterEqual(t0, 0)
            self.assertLessEqual(t0 + dur, self.gl.FRAMES, (sx, sy))

    def test_flicker_periods_divide_the_loop(self):
        """The window pattern repeats every 2 * period frames; that has to divide the loop or it jumps."""
        for period in (2, 3, 4, 6, 8, 12, 16):
            self.assertEqual(self.gl.FRAMES % (2 * period), 0, period)
        self.assertEqual(self.gl.FRAMES % 24, 0)  # the antenna lamps blink every 12 frames

    def test_the_letters_are_partly_hidden_behind_the_city(self):
        """The depth effect: some of the lettering is behind the buildings, but enough stays visible to read."""
        _, fg = self.gl.scene()
        letters, _, _ = self.gl.layout()
        hidden = sum(1 for x, y, _ in letters if fg[y, x, 3] > 0)
        share = hidden / len(letters)
        self.assertGreater(share, 0.03, f"nothing is behind the city ({share:.1%})")
        self.assertLess(share, 0.35, f"too much is hidden to read ({share:.1%})")

    def test_the_letters_are_in_the_picture(self):
        letters, _, _ = self.gl.layout()
        _, fg = self.gl.scene()
        sc = self.gl.SCALE
        visible = [(x, y) for x, y, _ in letters if fg[y, x, 3] == 0]
        bright = sum(1 for x, y in visible if self.frames[0][y * sc + sc // 2, x * sc + sc // 2].sum() > 450)
        self.assertGreater(bright / len(visible), 0.95)

    def test_the_generator_reproduces_the_committed_file(self):
        imgs, _ = self.gl.frames()
        # compare what a viewer sees: the quantised frames of the committed file against fresh ones
        for k in (0, 14, 50):
            fresh = np.asarray(imgs[k]).astype(int)
            diff = np.abs(fresh - self.frames[k]).max()
            self.assertLessEqual(diff, 8, (k, diff))  # the GIF palette changes colours by a few units at most


if __name__ == "__main__":
    unittest.main()
