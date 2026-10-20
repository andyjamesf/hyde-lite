"""Checks for the matugen template of Zed's theme (Configs/.config/matugen/templates/zed.json). Run:

    python3 -I tools/tests/test_zed_template.py
"""
import importlib.util
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "Configs/.config/matugen/templates/zed.json"
spec = importlib.util.spec_from_file_location("gen_zed_template", ROOT / "tools/gen_zed_template.py")
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)


class ZedTemplate(unittest.TestCase):
    def test_committed_template_is_what_the_generator_writes(self):
        doc = {"$schema": "https://zed.dev/schema/themes/v0.2.0.json", "name": "Matugen", "author": "hyde-lite",
               "themes": [gen.theme("dark"), gen.theme("light")]}
        self.assertEqual(TEMPLATE.read_text(), json.dumps(doc, indent=2) + "\n",
                         "run: python3 -I tools/gen_zed_template.py")

    def test_has_a_dark_and_a_light_theme_reading_their_own_polarity(self):
        themes = json.loads(TEMPLATE.read_text())["themes"]
        self.assertEqual([(t["name"], t["appearance"]) for t in themes],
                         [("Matugen Dark", "dark"), ("Matugen Light", "light")])
        for theme in themes:
            text = json.dumps(theme)
            used = set(re.findall(r"colors\.[a-z_]+\.(\w+)\.hex", text))
            self.assertEqual(used, {theme["appearance"]})

    def test_every_placeholder_is_a_material_role(self):
        roles = set(re.findall(r"colors\.([a-z_]+)\.", TEMPLATE.read_text()))
        known = {"background", "surface_container_low", "surface_container", "surface_container_high",
                 "surface_container_highest", "on_surface", "on_surface_variant", "outline",
                 "outline_variant", "primary", "secondary", "tertiary", "error"}
        self.assertLessEqual(roles, known)


if __name__ == "__main__":
    unittest.main()
