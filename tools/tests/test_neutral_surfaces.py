"""Display-free tests for the grey surfaces of Configs/.local/bin/wallpaper-palette (neutralise, grey). Run:

    python3 -I tools/tests/test_neutral_surfaces.py
"""
import importlib.machinery
import importlib.util
import pathlib
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.local/bin/wallpaper-palette"


def load():
    loader = importlib.machinery.SourceFileLoader("wallpaper_palette", str(SCRIPT))
    spec = importlib.util.spec_from_loader("wallpaper_palette", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def entry(dark, light, chosen="dark"):
    both = {"dark": {"color": dark}, "light": {"color": light}}
    return {**both, "default": dict(both[chosen])}


class Grey(unittest.TestCase):
    mod = load()

    def test_known_lightness_values(self):
        self.assertEqual(self.mod.grey(0), "#000000")
        self.assertEqual(self.mod.grey(100), "#ffffff")
        self.assertEqual(self.mod.grey(18), "#2c2c2c")  # the sidebar grey this was modelled on
        self.assertEqual(self.mod.grey(21), "#323232")

    def test_is_monotonic_and_neutral(self):
        values = [self.mod.grey(n) for n in range(0, 101, 5)]
        self.assertEqual(values, sorted(values))
        for v in values:
            self.assertEqual(v[1:3], v[3:5])
            self.assertEqual(v[3:5], v[5:7])


class Neutralise(unittest.TestCase):
    mod = load()

    def data(self, chosen="dark"):
        return {"mode": chosen, "colors": {
            "background": entry("#121415", "#f9f9fb", chosen),
            "surface_container_low": entry("#1a1c1d", "#f3f3f5", chosen),
            "primary": entry("#a6cce5", "#355a71", chosen),
            "on_surface": entry("#e2e2e4", "#1a1c1d", chosen)}}

    def test_surfaces_become_grey_in_both_polarities(self):
        c = self.mod.neutralise(self.data())["colors"]
        self.assertEqual(c["background"]["dark"]["color"], "#2c2c2c")
        self.assertEqual(c["background"]["light"]["color"], self.mod.grey(90))
        self.assertEqual(c["surface_container_low"]["dark"]["color"], "#323232")

    def test_default_follows_the_chosen_mode(self):
        self.assertEqual(self.mod.neutralise(self.data("dark"))["colors"]["background"]["default"]["color"], "#2c2c2c")
        light = self.mod.neutralise(self.data("light"))["colors"]["background"]["default"]["color"]
        self.assertEqual(light, self.mod.grey(90))

    def test_accents_and_text_are_untouched(self):
        c = self.mod.neutralise(self.data())["colors"]
        self.assertEqual(c["primary"]["dark"]["color"], "#a6cce5")
        self.assertEqual(c["on_surface"]["light"]["color"], "#1a1c1d")

    def test_missing_roles_and_mode_are_tolerated(self):
        data = {"is_dark_mode": False, "colors": {"background": entry("#111111", "#fafafa", "light")}}
        out = self.mod.neutralise(data)["colors"]["background"]
        self.assertEqual(out["default"]["color"], self.mod.grey(90))
        self.assertEqual(self.mod.neutralise({}), {})

    def test_text_keeps_contrast_on_every_grey(self):
        def lum(h):
            r = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
            r = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in r]
            return 0.2126 * r[0] + 0.7152 * r[1] + 0.0722 * r[2]
        for polarity, text in (("dark", "#e2e2e4"), ("light", "#1a1c1d")):
            for role, level in self.mod.GREY_L[polarity].items():
                hi, lo = sorted((lum(text), lum(self.mod.grey(level))), reverse=True)
                self.assertGreaterEqual((hi + 0.05) / (lo + 0.05), 7.0, (polarity, role))


if __name__ == "__main__":
    unittest.main()
