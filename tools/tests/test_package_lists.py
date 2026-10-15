"""Scripts/pkg_*.lst: line format, duplicates, and that what the installer reads is well formed.

    python3 -I tools/tests/test_package_lists.py

NOT TESTED here: that each package exists in the Arch repositories or the AUR (needs the network access
the cloud sandbox does not have to archlinux.org).
"""
import collections
import pathlib
import re
import tomllib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
LISTS = sorted((ROOT / "Scripts").glob("pkg_*.lst"))
# name, optionally "|<dependency>" (a package that is only installed together with another, e.g. the
# shell a prompt belongs to), then an optional trailing comment
LINE = re.compile(r"^(?P<name>[A-Za-z0-9@._+-]+)(?:\|(?P<dep>[A-Za-z0-9@._+-]+))?\s*(?:#.*)?$")


# Listed in both pkg_core.lst and pkg_extra.lst by upstream HyDE; harmless (pacman --needed), and not
# worth a diff against upstream.
KNOWN_DUPLICATES_ACROSS_LISTS = {"xdg-desktop-portal-gtk"}


def dots_packages():
    """Packages named as `pacman = [...]` dependencies in Scripts/dots*/**.toml (the dots installer)."""
    found = set()
    for path in (ROOT / "Scripts").glob("dots*/*.toml"):
        data = tomllib.loads(path.read_text(encoding="utf-8"))
        for group in data.values():
            if isinstance(group, dict):
                for dep in group.get("dependency", []):
                    found.update(dep.get("pacman", []))
    return found


def entries(path):
    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if line and not line.startswith("#"):
            yield n, raw, LINE.match(line)


class PackageLists(unittest.TestCase):
    def test_there_are_lists(self):
        self.assertTrue([p for p in LISTS if p.name in ("pkg_core.lst", "pkg_extra.lst")])

    def test_every_line_parses(self):
        for path in LISTS:
            for n, raw, m in entries(path):
                self.assertIsNotNone(m, f"{path.name}:{n}: cannot parse {raw!r}")

    def test_no_duplicate_entries_within_a_list(self):
        for path in LISTS:
            seen = collections.Counter((m["name"], m["dep"]) for _, _, m in entries(path) if m)
            dup = [k for k, v in seen.items() if v > 1]
            self.assertEqual(dup, [], f"{path.name}: duplicated {dup}")

    def test_no_package_in_both_core_and_extra(self):
        names = {p.name: {m["name"] for _, _, m in entries(p) if m} for p in LISTS}
        both = names.get("pkg_core.lst", set()) & names.get("pkg_extra.lst", set())
        self.assertEqual(both - KNOWN_DUPLICATES_ACROSS_LISTS, set(), f"in both lists: {sorted(both)}")

    def test_removed_packages_stay_removed(self):
        """The shells replace these (LITE.md); one sneaking back in would undo the point of the fork."""
        core = {m["name"] for _, _, m in entries(ROOT / "Scripts/pkg_core.lst") if m}
        self.assertEqual(core & {"waybar", "dunst", "swaync", "wlogout", "rofi-wayland", "rofi"}, set())

    def test_dots_dependency_reader_finds_matugen(self):
        self.assertIn("matugen", dots_packages())  # it is installed by Scripts/dots/colour.toml, not a list

    def test_quickshell_and_matugen_are_installed(self):
        core = {m["name"] for _, _, m in entries(ROOT / "Scripts/pkg_core.lst") if m}
        extra = {m["name"] for _, _, m in entries(ROOT / "Scripts/pkg_extra.lst") if m}
        have = core | extra | dots_packages()
        for need in ("quickshell", "matugen"):
            self.assertTrue(any(n == need or n.startswith(need + "-") for n in have), f"{need} missing")


if __name__ == "__main__":
    unittest.main()
