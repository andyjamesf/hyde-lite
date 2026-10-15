#!/usr/bin/env python3
"""What must not be in a public copy of this repository: secrets, personal data, stray files.

    python3 -I tools/scan_publish.py DIR        scan every file under DIR (not a git repository needed)

Exit status 0 when nothing is found, 1 otherwise. tools/tests/test_repo_hygiene.py runs the same rules on the
tracked files, and tools/export_clean.sh runs this on the tree it exports. It is a tripwire, not a secret
scanner: CI also runs gitleaks, and the export is a fresh tree with no history.
"""
import pathlib
import re
import sys

# Things that must never be in the tree (each was removed once, see LITE.md). The first group is personal data of
# the maintainer, the second is credentials in the shapes that matter for this project (Google Calendar, GitHub, AWS).
FORBIDDEN_TEXT = {
    r"ko_fi\s*:": "upstream's sponsor link",
    r"/home/khing": "another author's home directory",
    r"f\.s\.a\.t96": "a personal e-mail address",
    r"Andy(Ryzen|Desktop|Laptop)\d*": "a machine's host name",
    r"hyde-dotfiles|hyde-quickshell": "names of private repositories",
    r"Source/assets/": "upstream's removed screenshots",
    r"BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY": "a private key",
    r"ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|gho_[A-Za-z0-9]{30,}": "a GitHub token",
    r"AKIA[0-9A-Z]{16}": "an AWS access key",
    r"AIza[0-9A-Za-z_-]{35}": "a Google API key",
    r"GOCSPX-[0-9A-Za-z_-]{20,}": "a Google OAuth client secret",
    r"ya29\.[0-9A-Za-z_-]{20,}": "a Google OAuth access token",
    r"1//0[0-9A-Za-z_-]{30,}": "a Google OAuth refresh token",
    r"[0-9]{8,}-[0-9a-z]{20,}\.apps\.googleusercontent\.com": "a Google OAuth client id",
    r"xox[baprs]-[A-Za-z0-9-]{10,}": "a Slack token",
    r"sk-ant-[A-Za-z0-9_-]{20,}": "an Anthropic API key",
    r"[\"']client_secret[\"']\s*:\s*[\"'][^\"'\s]{8,}[\"']": "a client secret with a value",
    r"private-[0-9a-f]{20,}/basic\.ics": "a private Google Calendar feed address",
}
# files that may legitimately talk about the above (the rules themselves; LITE.md records the removals)
TEXT_EXEMPT = {"tools/tests/test_repo_hygiene.py", "tools/scan_publish.py", "LITE.md"}
SECRET_FILE_NAMES = re.compile(
    r"(^|/)(\.env(\..*)?|id_rsa|id_ed25519|\.netrc|\.pypirc|token\.json|client_secret.*\.json"
    r"|.*\.(pem|p12|pfx|key|keystore|jks|kdbx))$")
SKIP_DIRS = {".git", "__pycache__", ".ruff_cache", "node_modules"}


def read_text(path):
    data = path.read_bytes()
    if b"\0" in data[:4096]:
        return None
    return data.decode("utf-8", "replace")


def files_under(root):
    root = pathlib.Path(root)
    out = []
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root)
        if p.is_file() and not any(part in SKIP_DIRS for part in rel.parts):
            out.append(rel.as_posix())
    return out


def scan_text(root, files):
    hits = []
    for rel in files:
        if rel in TEXT_EXEMPT:
            continue
        text = read_text(pathlib.Path(root) / rel)
        if text is None:
            continue
        for pattern, why in FORBIDDEN_TEXT.items():
            m = re.search(pattern, text)
            if m:
                hits.append(f"{rel}: {why} ({m.group(0)[:30]!r})")
    return hits


def scan_names(files):
    return [f"{f}: a file name that usually holds a secret" for f in files if SECRET_FILE_NAMES.search(f)]


def main(argv):
    if len(argv) != 2 or not pathlib.Path(argv[1]).is_dir():
        print(__doc__.strip().split("\n\n")[0], file=sys.stderr)
        return 2
    files = files_under(argv[1])
    problems = scan_names(files) + scan_text(argv[1], files)
    for p in problems:
        print(f"scan_publish: {p}")
    print(f"scan_publish: {len(files)} files scanned, {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
