"""The polished Thunar: its colours, stylesheet and installer step (tools/thunar.sh). Run:

    python3 -I tools/tests/test_thunar.py
"""
import os
import pathlib
import re
import subprocess
import tempfile
import tomllib
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = REPO / "Configs/.config/matugen/templates/gtk.css"
STYLE = REPO / "Configs/.config/gtk-3.0/thunar.css"
MATUGEN = REPO / "Configs/.config/matugen/config.toml"
DOTS = REPO / "Scripts/dots/thunar.toml"
# names the patched Thunar looks up from C
FROM_PATCH = {"m3_primary_container", "m3_outline"}


def without_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


class Colours(unittest.TestCase):
    def test_every_m3_name_used_is_defined(self):
        used = set(re.findall(r"@(m3_[a-z_]+)", without_comments(STYLE.read_text()))) | FROM_PATCH
        defined = set(re.findall(r"@define-color (m3_[a-z_]+) \{\{colors\.[a-z_]+\.default\.hex\}\};", TEMPLATE.read_text()))
        self.assertEqual(used - defined, set())
        self.assertEqual(len(defined), 15)

    def test_stylesheet_has_no_literal_colour(self):
        self.assertEqual(re.findall(r"#[0-9a-fA-F]{3,8}\b|\brgba?\(", without_comments(STYLE.read_text())), [])

    def test_stylesheet_is_deployed(self):
        entries = tomllib.loads(DOTS.read_text())["thunar"]["files"]
        deployed = [(e.get("source_root"), p) for e in entries
                    for p in ([e["paths"]] if isinstance(e["paths"], str) else e["paths"])]
        self.assertIn(("Configs/.config", "gtk-3.0/thunar.css"), deployed)

    def test_gtk3_hook_imports_each_file_once_and_wallpaper_first(self):
        hook = tomllib.loads(MATUGEN.read_text())["templates"]["gtk3"]["post_hook"]
        for before in (None, '@import url("wallpaper.css");\n', '@import url("thunar.css");\n'):
            with self.subTest(before=before), tempfile.TemporaryDirectory() as home:
                css = pathlib.Path(home, ".config/gtk-3.0/gtk.css")
                css.parent.mkdir(parents=True)
                if before:
                    css.write_text(before)
                for _ in range(2):
                    subprocess.run(["sh", "-c", hook], env={**os.environ, "HOME": home}, check=True)
                text = css.read_text()
                self.assertEqual(text.count('@import url("wallpaper.css");'), 1)
                self.assertEqual(text.count('@import url("thunar.css");'), 1)
                if before != '@import url("thunar.css");\n':
                    self.assertLess(text.index("wallpaper.css"), text.index("thunar.css"))


if __name__ == "__main__":
    unittest.main()
