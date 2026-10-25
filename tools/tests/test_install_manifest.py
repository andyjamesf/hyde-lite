"""Scripts/restore_cfg.psv must name every file a fresh install needs. Run:

    python3 -I tools/tests/test_install_manifest.py

The manifest lists the targets one by one rather than whole trees, so a directory added to
Configs/ is simply not installed until someone remembers to add it here, and nothing says so: the
machine comes up with a shell that is missing a module and the error only shows at runtime. That
happened to shared/, the first directory added to the Quickshell configuration in a long time.

This checks both directions for ${HOME}/.config/quickshell: every target listed exists, and every
file in the configuration is covered by some target. A target covers a path when it is that path
or one of its parents, which is how restore_cfg.sh copies them.

NOT TESTED here: the other lines of the manifest, and whether restore_cfg.sh does what it says.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Scripts/restore_cfg.psv"
CONFIG = "${HOME}/.config/quickshell"
SOURCE = ROOT / "Configs/.config/quickshell"
# Caches and the owner's own settings, which the P line keeps out of the way on purpose.
IGNORED = {"__pycache__"}


def targets():
    """Every target listed for the Quickshell configuration, from all of its lines."""
    out = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if line.startswith("#") or line.count("|") != 3:
            continue
        _flag, path, target, _dep = line.split("|")
        if path == CONFIG:
            out += target.split()
    return out


def covered(rel, listed):
    return any(rel == t or rel.startswith(t + "/") for t in listed)


class Manifest(unittest.TestCase):
    def test_every_target_exists(self):
        listed = targets()
        self.assertTrue(listed, "no line for %s" % CONFIG)
        missing = [t for t in listed if not (SOURCE / t).exists()]
        self.assertEqual(missing, [], "listed in the manifest but not in Configs/")

    def test_every_file_is_covered(self):
        listed = targets()
        uncovered = []

        def walk(d, prefix):
            for child in sorted(d.iterdir()):
                if child.name in IGNORED:
                    continue
                rel = prefix + child.name
                if covered(rel, listed):
                    continue
                if child.is_dir():
                    walk(child, rel + "/")
                else:
                    uncovered.append(rel)

        walk(SOURCE, "")
        self.assertEqual(uncovered, [], "in Configs/ but no install target names it")


if __name__ == "__main__":
    unittest.main()
