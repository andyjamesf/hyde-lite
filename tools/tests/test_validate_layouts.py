"""Tests for the layout validator (PLAN 3.2). Run: python3 -I tools/tests/test_validate_layouts.py"""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

TOOL = pathlib.Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/scripts/validate_layouts.py"
spec = importlib.util.spec_from_file_location("validate_layouts", TOOL)
vl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vl)

IDS, STYLES = vl.widget_ids(), vl.pill_styles()
OK = {"label": "T", "style": "islands", "height": 23, "left": [["workspaces"]], "center": [["clock"]],
      "right": [["tray"], ["audio", "network"]]}


def problems(**change):
    lay = {**OK, **change}
    return vl.check_layout("t", lay, IDS, STYLES)


class Validate(unittest.TestCase):
    def test_catalogue_is_read_from_the_qml(self):
        self.assertEqual(len(IDS), 20)
        self.assertIn("controlCenter", IDS)
        self.assertEqual(STYLES, {"surface", "tint", "container", "accent", "glass", "outline"})

    def test_valid_layout(self):
        self.assertEqual(problems(), [])

    def test_shipped_layouts_pass(self):
        r = subprocess.run([sys.executable, "-I", str(TOOL)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_rejections(self):
        for change, needle in [
            ({"hieght": 20}, "unknown key 'hieght'"),
            ({"style": "round"}, "t.style"),
            ({"position": "left"}, "t.position"),
            ({"height": 99}, "t.height"),
            ({"height": True}, "t.height"),
            ({"opacity": 1.5}, "t.opacity"),
            ({"pillStyle": "pink"}, "t.pillStyle"),
            ({"left": "workspaces"}, "t.left: must be a list"),
            ({"left": [[]]}, "non-empty"),
            ({"left": [["nope"]]}, "unknown widget 'nope'"),
            ({"left": [["clock"]]}, "already used"),
            ({"left": [[3]]}, "must be strings"),
        ]:
            with self.subTest(change=change):
                self.assertTrue(any(needle in m for m in problems(**change)), problems(**change))

    def test_accepts_colour_and_named_pill_style(self):
        self.assertEqual(problems(pillStyle="#aabbcc"), [])
        self.assertEqual(problems(pillStyle="#aabbcc80"), [])
        self.assertEqual(problems(pillStyle="glass"), [])

    def test_label_required(self):
        lay = dict(OK)
        del lay["label"]
        self.assertTrue(any("'label' is required" in m for m in vl.check_layout("t", lay, IDS, STYLES)))

    def test_bad_files(self):
        with tempfile.TemporaryDirectory() as d:
            for text in ["{", "[]", "{}"]:
                f = pathlib.Path(d, "l.json")
                f.write_text(text)
                self.assertTrue(vl.check_file(f, IDS, STYLES), text)
            f.write_text(json.dumps({"a": OK}))
            self.assertEqual(vl.check_file(f, IDS, STYLES), [])


if __name__ == "__main__":
    unittest.main()
