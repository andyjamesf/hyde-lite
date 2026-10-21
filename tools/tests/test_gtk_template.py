"""Checks for the matugen template of the GTK colours (Configs/.config/matugen/templates/gtk.css). Run:

    python3 -I tools/tests/test_gtk_template.py

GTK3 parses the rendered file at the start of every app and only logs a warning on a mistake, so a slip
(a comment closed early by a stray "*/", an unbalanced brace) shows up as a theme that half works.
"""
import pathlib
import re
import unittest

TEMPLATE = pathlib.Path(__file__).resolve().parents[2] / "Configs/.config/matugen/templates/gtk.css"
ROLES = {"background", "on_background", "surface_container_lowest", "surface_container_low", "surface_container",
         "surface_container_high", "surface_container_highest", "on_surface", "on_surface_variant", "outline",
         "outline_variant", "primary", "on_primary", "primary_container", "on_primary_container", "secondary",
         "tertiary", "error", "on_error"}


class GtkTemplate(unittest.TestCase):
    text = TEMPLATE.read_text()

    def test_comments_are_closed_once_and_not_early(self):
        for block in re.findall(r"/\*(.*?)\*/", self.text, re.S):
            self.assertNotIn("/*", block)
        self.assertEqual(self.text.count("/*"), self.text.count("*/"), "a comment contains '*/' or is not closed")

    def test_braces_balance_outside_placeholders(self):
        css = re.sub(r"/\*.*?\*/", "", self.text, flags=re.S)
        css = re.sub(r"\{\{.*?\}\}", "", css)
        self.assertEqual(css.count("{"), css.count("}"))

    def test_every_placeholder_is_a_known_role_and_renders_a_hex(self):
        used = re.findall(r"\{\{colors\.([a-z_]+)\.default\.hex\}\}", self.text)
        self.assertEqual(len(used), self.text.count("{{"))
        self.assertLessEqual(set(used), ROLES)

    def test_menus_and_popovers_are_styled_from_the_neutral_surfaces(self):
        for selector in ("menu, .menu, .context-menu {", "menu menuitem:hover", "popover.background list"):
            self.assertIn(selector, self.text)


class WallbashGtk4Template(unittest.TestCase):
    """Wallbash rewrites gtk-4.0/gtk.css on every colour change from this template, so the import of matugen's
    wallpaper.css has to be in it: matugen's post_hook appends the line only when matugen runs, and the next
    rewrite dropped it (selected text light on a light background, measured with GTK 4.24 on 2026-10-21)."""
    dcol = pathlib.Path(__file__).resolve().parents[2] / "Configs/.local/share/wallbash/theme/gtk/gtk4.dcol"

    def test_it_ends_by_importing_the_matugen_file_after_the_wallbash_colours(self):
        text = self.dcol.read_text()
        imports = [m.start() for m in re.finditer(r'(?m)^@import url\("wallpaper\.css"\);$', text)]
        self.assertEqual(len(imports), 1)
        self.assertGreater(imports[0], text.rindex("@define-color"), "the import must come after every Wallbash colour")

    def test_the_import_matches_what_the_matugen_hook_looks_for(self):
        config = (pathlib.Path(__file__).resolve().parents[2] / "Configs/.config/matugen/config.toml").read_text()
        self.assertIn("grep -qs wallpaper.css ~/.config/gtk-4.0/gtk.css", config)   # finds the line, appends nothing twice


if __name__ == "__main__":
    unittest.main()
