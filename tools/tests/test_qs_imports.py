"""Every `import qs.<path>` in the Quickshell configuration names a folder that has .qml files, and the root
shell.qml imports both UI folders. Quickshell only reports a wrong import at run time, and only for the UI that
is loaded, so a typo in the other one would go unseen. Run:

    python3 -I tools/tests/test_qs_imports.py
"""
import re
import unittest
from pathlib import Path

CONFIG = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
IMPORT = re.compile(r"^\s*import\s+qs\.([A-Za-z0-9_.]+)", re.M)


def qml_files():
    # sddm/ runs inside SDDM, with its own imports.
    return [p for p in CONFIG.rglob("*.qml") if "sddm" not in p.relative_to(CONFIG).parts]


class QsImports(unittest.TestCase):
    def test_every_import_names_a_folder_with_qml_files(self):
        bad = []
        for f in qml_files():
            for m in IMPORT.finditer(f.read_text()):
                folder = CONFIG.joinpath(*m.group(1).split("."))
                if not folder.is_dir() or not list(folder.glob("*.qml")):
                    bad.append(f"{f.relative_to(CONFIG)}: import qs.{m.group(1)}")
        self.assertEqual(bad, [])

    def test_a_ui_imports_only_its_own_folders(self):
        bad = []
        for ui in ("bar", "island"):
            other = "island" if ui == "bar" else "bar"
            for f in (CONFIG / ui).rglob("*.qml"):
                if "sddm" in f.relative_to(CONFIG).parts:
                    continue
                for m in IMPORT.finditer(f.read_text()):
                    if m.group(1).split(".")[0] == other:
                        bad.append(f"{f.relative_to(CONFIG)}: import qs.{m.group(1)}")
        self.assertEqual(bad, [], "neither UI may import the other; what they share goes to quickshell/shared")

    def test_the_root_registers_both_uis_and_each_has_a_shell(self):
        root = (CONFIG / "shell.qml").read_text()
        for ui in ("bar", "island"):
            self.assertRegex(root, rf"(?m)^import qs\.{ui}\b", f"shell.qml must import qs.{ui} (see the comment there)")
            self.assertTrue((CONFIG / ui / "Shell.qml").is_file(), f"{ui}/Shell.qml is what shell.qml loads")
            self.assertIn(f'root.ui = "{ui}"', root, f"shell.qml never selects {ui}")

    def test_entry_points_import_only_the_island_and_the_shared_folder(self):
        # They run the island's lock and login-screen sync on their own, so they may reach the
        # island and quickshell/shared, and nothing else — the bar least of all.
        for name in ("lock.qml", "sync.qml"):
            mods = {m.group(1).split(".")[0] for m in IMPORT.finditer((CONFIG / name).read_text())}
            self.assertTrue(mods <= {"island", "shared"}, f"{name}: {sorted(mods)}")
            self.assertIn("island", mods, name)


if __name__ == "__main__":
    unittest.main()
