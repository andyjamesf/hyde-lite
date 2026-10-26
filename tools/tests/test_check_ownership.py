"""tools/check_ownership.py: a path both repositories own is a duplicate, pinned, an override or a conflict."""
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("check_ownership", ROOT / "tools/check_ownership.py")
co = importlib.util.module_from_spec(spec)
spec.loader.exec_module(co)

TOML = """
[x]
[[x.files]]
action = "%s"
source_root = "Configs/.config"
target_root = "${XDG_CONFIG_HOME}"
paths = "%s"
"""


def build(tmp, action, mine, ours="same\n"):
    repo, dots = tmp / "repo", tmp / "dots"
    (repo / "Scripts/dots").mkdir(parents=True)
    (repo / "Configs/.config/app").mkdir(parents=True)
    (repo / "Configs/.config/app/a.conf").write_text(ours)
    (repo / "Scripts/dots/x.toml").write_text(TOML % (action, "app"))
    (dots / "shared/home/.config/app").mkdir(parents=True)
    (dots / "shared/home/.config/app/a.conf").write_text(mine)
    return repo, dots


class Ownership(unittest.TestCase):
    def kind(self, action, mine):
        with tempfile.TemporaryDirectory() as t:
            repo, dots = build(pathlib.Path(t), action, mine)
            rows = co.classify(repo, dots)
        self.assertEqual(len(rows), 1)
        return rows[0][0]

    def test_identical_and_synced_is_a_duplicate(self):
        self.assertEqual(self.kind("sync", "same\n"), "duplicate")

    def test_identical_and_preserved_is_pinned(self):
        self.assertEqual(self.kind("preserve", "same\n"), "pinned")

    def test_different_and_preserved_is_an_override(self):
        self.assertEqual(self.kind("preserve", "mine\n"), "override")

    def test_different_and_synced_is_a_conflict(self):
        self.assertEqual(self.kind("sync", "mine\n"), "CONFLICT")

    def test_a_file_only_one_repository_has_is_not_listed(self):
        with tempfile.TemporaryDirectory() as t:
            repo, dots = build(pathlib.Path(t), "sync", "same\n")
            (dots / "shared/home/.config/app/a.conf").rename(dots / "shared/home/.config/app/b.conf")
            self.assertEqual(co.classify(repo, dots), [])


if __name__ == "__main__":
    unittest.main()
