"""Files that exist in both UIs (quickshell/bar and quickshell/island) until they are moved to a shared folder
must not drift apart: a fix in one is a fix in the other. Run:

    python3 -I tools/tests/test_mirrored_files.py

Scripts are mirrored automatically: any file name present in both scripts/ folders must be identical.
Both files that were (ical_events.py and pick_file.py) now live in quickshell/shared/scripts, so the
check has nothing left to compare and skips; what remains in each scripts/ folder belongs to that UI
alone.
Services are mirrored only when listed here. The list is empty: PamText, the only one that was ever
byte-identical, now lives in quickshell/shared/services with the rest of the services the two UIs
share, which is the end this file was written to expect. The same-named services still sitting in
both folders (Apps, Calculator, Clipboard, Keybinds, Lock, Prefs, SysInfo) have diverged and are
NOT meant to be identical; they are the remaining candidates for the shared folder.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.config"
BAR, ISLAND = ROOT / "quickshell/bar", ROOT / "quickshell/island"
MIRRORED_SERVICES = []


def names(folder, pattern):
    return {p.name for p in folder.glob(pattern)}


class Mirrored(unittest.TestCase):
    def test_shared_scripts_are_identical(self):
        shared = sorted(names(BAR / "scripts", "*.py") & names(ISLAND / "scripts", "*.py"))
        if not shared:
            self.skipTest("no script is in both folders any more; the shared ones live in shared/scripts")
        for n in shared:
            self.assertEqual((BAR / "scripts" / n).read_bytes(), (ISLAND / "scripts" / n).read_bytes(),
                             f"scripts/{n} differs between the shells; edit one, copy it to the other")

    def test_listed_services_are_identical(self):
        if not MIRRORED_SERVICES:
            self.skipTest("no service is mirrored by hand any more; they live in shared/services")
        for n in MIRRORED_SERVICES:
            self.assertEqual((BAR / "services" / n).read_bytes(), (ISLAND / "services" / n).read_bytes(),
                             f"services/{n} differs between the shells; edit one, copy it to the other")


if __name__ == "__main__":
    unittest.main()
