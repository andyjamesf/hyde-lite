"""Display-free tests for Configs/.local/bin/matugen-icons (Papirus-Dark folders in the wallpaper colour).

Each test imports a fresh copy under a throwaway HOME and points SRC at a tiny fake Papirus. Run:

    python3 -I tools/tests/test_matugen_icons.py
"""
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.local/bin/matugen-icons"
FOLDER = '<svg><path fill="#5294e2"/><path fill="#4877b1"/><path fill="#1d344f"/><path fill="#ffffff"/></svg>'


class MatugenIcons(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = pathlib.Path(tmp.name)
        patcher = mock.patch.dict(os.environ, {"HOME": str(self.home)})
        patcher.start()
        self.addCleanup(patcher.stop)
        for var in ("XDG_CACHE_HOME", "XDG_DATA_HOME"):
            os.environ.pop(var, None)
        loader = importlib.machinery.SourceFileLoader("matugen_icons", str(SCRIPT))
        spec = importlib.util.spec_from_loader("matugen_icons", loader)
        self.mod = importlib.util.module_from_spec(spec)
        loader.exec_module(self.mod)
        self.mod.SRC = self.home / "papirus"
        places = self.mod.SRC / "48x48/places"
        places.mkdir(parents=True)
        (places / "folder-blue.svg").write_text(FOLDER)
        (places / "folder-blue-documents.svg").write_text(FOLDER)
        (places / "user-blue-home.svg").write_text(FOLDER)
        (places / "folder-bluegrey.svg").write_text(FOLDER)  # another colour: must not be copied
        (places / "folder-red.svg").write_text(FOLDER)
        self.palette(("#aa0000", "#bb0000", "#cc0000"))

    def palette(self, colours):
        pal = {"secondary": {t: {"color": c} for t, c in zip(("60", "50", "20"), colours)}}
        self.mod.MATUGEN.parent.mkdir(parents=True, exist_ok=True)
        self.mod.MATUGEN.write_text(json.dumps({"palettes": pal}))

    def run_main(self, *args):
        with mock.patch.object(sys, "argv", ["matugen-icons", *args]):
            self.mod.main()

    def test_copies_the_blue_folders_under_their_plain_names(self):
        self.run_main()
        names = sorted(p.name for p in (self.mod.OUT / "48x48/places").iterdir())
        self.assertEqual(names, ["folder-documents.svg", "folder.svg", "user-home.svg"])

    def test_swaps_the_three_papirus_colours_and_keeps_the_rest(self):
        self.run_main()
        text = (self.mod.OUT / "48x48/places/folder.svg").read_text()
        for colour in ("#aa0000", "#bb0000", "#cc0000", "#ffffff"):
            self.assertIn(colour, text)
        self.assertNotIn("#5294e2", text)

    def test_index_theme_inherits_papirus_dark(self):
        self.run_main()
        index = (self.mod.OUT / "index.theme").read_text()
        self.assertIn("Inherits=Papirus-Dark,Papirus", index)
        self.assertIn("[48x48/places]", index)

    def test_same_colours_do_nothing_and_new_colours_rewrite(self):
        self.run_main()
        marker = self.mod.OUT / "marker"
        marker.write_text("x")
        self.run_main()
        self.assertTrue(marker.exists())
        self.palette(("#112233", "#445566", "#778899"))
        self.run_main()
        self.assertFalse(marker.exists())
        self.assertIn("#112233", (self.mod.OUT / "48x48/places/folder.svg").read_text())

    def test_without_papirus_or_palette_it_exits(self):
        self.mod.MATUGEN.unlink()
        with self.assertRaises(SystemExit):
            self.run_main()
        self.mod.SRC = self.home / "missing"
        with self.assertRaises(SystemExit):
            self.run_main()


if __name__ == "__main__":
    unittest.main()
