"""Checks on the tracked tree that matter for a public repository: no personal data or secret-looking
files, no accidental large files, and Markdown links that resolve. Needs a git checkout. Run:

    python3 -I tools/tests/test_repo_hygiene.py

This is a tripwire, not a secret scanner: CI also runs gitleaks over the whole history.
"""
import pathlib
import re
import subprocess
import sys
import unittest
from urllib.parse import unquote

ROOT = pathlib.Path(__file__).resolve().parents[2]

# The rules live in tools/scan_publish.py (one list for this test and for the export script)
sys.path.insert(0, str(ROOT / "tools"))
import scan_publish  # noqa: E402

FORBIDDEN_TEXT = scan_publish.FORBIDDEN_TEXT
TEXT_EXEMPT = scan_publish.TEXT_EXEMPT
SECRET_FILE_NAMES = scan_publish.SECRET_FILE_NAMES
MAX_BYTES = 4 * 1024 * 1024
LARGE_ALLOWED = re.compile(
    r"^(Source/arcs/.*\.tar\.gz"  # upstream's theme and font archives
    r"|docs/images/.*\.png|Wallpapers/.*\.png"
    r"|Configs/\.local/bin/hydectl)$"  # upstream's prebuilt helper (13 MB ELF); see docs/weight.md
)
# upstream READMEs whose links are already broken upstream (they omit the .md extension)
LINK_EXEMPT = {"Configs/.config/hyde/wallbash/README.md"}


def tracked():
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, check=True).stdout
    return [f for f in out.decode().split("\0") if f and (ROOT / f).is_file()]


def read_text(rel):
    data = (ROOT / rel).read_bytes()
    if b"\0" in data[:4096]:
        return None
    return data.decode("utf-8", "replace")


class Hygiene(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = tracked()

    def test_no_forbidden_text(self):
        hits = []
        for rel in self.files:
            if rel in TEXT_EXEMPT:
                continue
            text = read_text(rel)
            if text is None:
                continue
            for pattern, why in FORBIDDEN_TEXT.items():
                m = re.search(pattern, text)
                if m:
                    hits.append(f"{rel}: {why} ({m.group(0)[:30]!r})")
        self.assertEqual(hits, [])

    def test_no_secret_file_names(self):
        self.assertEqual([f for f in self.files if SECRET_FILE_NAMES.search(f)], [])

    def test_no_large_files_outside_the_allowed_places(self):
        big = [f"{f} ({(ROOT / f).stat().st_size // 1024} kB)" for f in self.files
               if (ROOT / f).stat().st_size > MAX_BYTES and not LARGE_ALLOWED.match(f)]
        self.assertEqual(big, [])

    def test_file_names_are_sane(self):
        """A stray shell redirect or a bad sed once created a file named after its own command line."""
        odd = [f for f in self.files if re.search(r'["|<>*?\\\n\t`$;]', f) or f != f.strip() or len(f) > 150]
        self.assertEqual(odd, [])

    def test_no_broken_submodule_leftovers(self):
        self.assertFalse((ROOT / ".gitmodules").exists(), ".gitmodules without submodules")

    def test_licence_and_community_files_exist(self):
        for name in ("LICENSE", "README.md", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md"):
            self.assertIn(name, self.files)


LINK = re.compile(r"(?<!\!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|!\[[^\]]*\]\(([^)\s]+)\)|<img[^>]+src=\"([^\"]+)\"")
FENCE = re.compile(r"^(```|~~~).*?^\1", re.S | re.M)
COMMENT = re.compile(r"<!--.*?-->", re.S)


class Licences(unittest.TestCase):
    """An asset that came from somewhere else must have a line in THIRD_PARTY.md saying what is known of it."""

    def test_every_archive_and_logo_is_named_in_third_party(self):
        page = (ROOT / "THIRD_PARTY.md").read_text(encoding="utf-8")
        shipped = [f for f in tracked() if f.startswith(("Source/arcs/", "Configs/.config/fastfetch/logo/"))]
        self.assertTrue(shipped)
        missing = [f for f in shipped if f.rsplit("/", 1)[1] not in page]
        self.assertEqual(missing, [], "add a line to THIRD_PARTY.md for each of these")

    def test_removed_assets_stay_removed(self):
        files = set(tracked())
        gone = ["Source/arcs/Grub_Pochita.tar.gz", "Source/arcs/Grub_Retroboot.tar.gz", "Source/arcs/Steam_Metro.tar.gz",
                "Source/arcs/Firefox_Extensions.tar.gz", "Source/arcs/Firefox_UserConfig.tar.gz"]
        gone += [f"Configs/.config/fastfetch/logo/{n}.icon" for n in ("aisaka", "geass", "loli", "pochita", "ryuzaki", "agk_clan")]
        self.assertEqual([f for f in gone if f in files], [])


class MarkdownLinks(unittest.TestCase):
    def test_relative_links_resolve(self):
        broken = []
        for rel in tracked():
            if not rel.endswith(".md") or rel.startswith("Scripts/") or rel in LINK_EXEMPT:
                continue
            text = COMMENT.sub("", FENCE.sub("", read_text(rel) or ""))
            for m in LINK.finditer(text):
                target = next(g for g in m.groups() if g)
                if re.match(r"^([a-z][a-z0-9+.-]*:|#|//)", target, re.I):
                    continue
                path = unquote(target.split("#", 1)[0].split("?", 1)[0])
                if not path:
                    continue
                base = ROOT if path.startswith("/") else (ROOT / rel).parent
                if not (base / path.lstrip("/")).exists():
                    broken.append(f"{rel}: {target}")
        self.assertEqual(broken, [])


if __name__ == "__main__":
    unittest.main()
