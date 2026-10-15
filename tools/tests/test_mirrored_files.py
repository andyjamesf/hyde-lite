"""Files that exist in both shells because each shell is deployed on its own (~/.config/quickshell and
~/.config/morphing-island) must not drift apart: a fix in one is a fix in the other. Run:

    python3 -I tools/tests/test_mirrored_files.py

Scripts are mirrored automatically: any file name present in both scripts/ folders must be identical.
Services are mirrored only when listed here; the other same-named services (Audio, Network, ...) have
diverged on purpose or by accident and are NOT meant to be identical.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.config"
BAR, ISLAND = ROOT / "quickshell", ROOT / "morphing-island"
MIRRORED_SERVICES = ["PamText.qml"]


def names(folder, pattern):
    return {p.name for p in folder.glob(pattern)}


class Mirrored(unittest.TestCase):
    def test_shared_scripts_are_identical(self):
        shared = sorted(names(BAR / "scripts", "*.py") & names(ISLAND / "scripts", "*.py"))
        self.assertTrue(shared, "expected at least ical_events.py and pick_file.py in both")
        for n in shared:
            self.assertEqual((BAR / "scripts" / n).read_bytes(), (ISLAND / "scripts" / n).read_bytes(),
                             f"scripts/{n} differs between the shells; edit one, copy it to the other")

    def test_listed_services_are_identical(self):
        for n in MIRRORED_SERVICES:
            self.assertEqual((BAR / "services" / n).read_bytes(), (ISLAND / "services" / n).read_bytes(),
                             f"services/{n} differs between the shells; edit one, copy it to the other")


if __name__ == "__main__":
    unittest.main()
