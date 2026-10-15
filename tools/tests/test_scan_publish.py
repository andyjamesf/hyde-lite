"""tools/scan_publish.py finds each kind of thing it promises to, and nothing in a clean tree.

The samples are built by concatenation so that this file itself is not flagged by the repository hygiene test."""
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "scan_publish.py"
sys.path.insert(0, str(ROOT / "tools"))
import scan_publish  # noqa: E402

A = "a" * 40
SAMPLES = {
    "a personal e-mail address": "f." + "s.a.t96" + "@example.test",
    "a machine's host name": "host " + "Andy" + "Ryzen7",
    "a private key": "-----BEGIN " + "OPENSSH PRIVATE KEY-----",
    "a GitHub token": "gh" + "p_" + A[:36],
    "an AWS access key": "AK" + "IA" + "A" * 16,
    "a Google API key": "AI" + "za" + A[:35],
    "a Google OAuth client secret": "GOC" + "SPX-" + A[:28],
    "a Google OAuth access token": "ya" + "29." + A[:30],
    "a Google OAuth refresh token": "1/" + "/0" + A[:40],
    "a Google OAuth client id": "123456789012-" + A[:32] + ".apps.google" + "usercontent.com",
    "a Slack token": "xo" + "xb-" + "1234567890-abcdef",
    "an Anthropic API key": "sk-" + "ant-" + A[:30],
    "a client secret with a value": '{"client_' + 'secret": "' + A[:20] + '"}',
    "a private Google Calendar feed address": "private-" + "0123456789abcdef0123456789" + "/basic.ics",
}


def scan_dir(files):
    with tempfile.TemporaryDirectory() as d:
        for name, text in files.items():
            p = pathlib.Path(d, name)
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text) if isinstance(text, str) else p.write_bytes(text)
        return subprocess.run([sys.executable, "-I", str(SCRIPT), d], capture_output=True, text=True)


class Scan(unittest.TestCase):
    def test_every_rule_is_exercised_and_fires(self):
        covered = {why for why in SAMPLES}
        listed = set(scan_publish.FORBIDDEN_TEXT.values())
        # rules that only match upstream-specific text are not given a sample here
        upstream_only = {"upstream's sponsor link", "another author's home directory", "names of private repositories",
                         "upstream's removed screenshots"}
        self.assertEqual(listed - covered - upstream_only, set(), "a rule without a sample in this test")
        for why, text in SAMPLES.items():
            r = scan_dir({"notes/a.txt": f"nothing to see\n{text}\nnothing to see\n"})
            self.assertEqual(r.returncode, 1, why)
            self.assertIn(why, r.stdout, why)

    def test_a_clean_tree_passes(self):
        r = scan_dir({"README.md": "# Title\nplain text, an example@example.invalid address, a path /home/user/x\n",
                      "src/a.py": "token = 'qs_pick_file'\n", "bin/blob": b"\0\x01\x02" + (b"AIza" + b"a" * 35)})
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("0 problem", r.stdout)

    def test_secret_file_names(self):
        for name in (".env", ".env.local", "id_rsa", "keys/server.pem", "client_secret_123.json", "google/token.json",
                     "a/b/c.kdbx", ".netrc"):
            r = scan_dir({name: "x"})
            self.assertEqual(r.returncode, 1, name)
            self.assertIn("usually holds a secret", r.stdout, name)
        for name in ("monkey.json", "tokens.md", "env.sh", "keyboard.png"):
            self.assertEqual(scan_dir({name: "x"}).returncode, 0, name)

    def test_caches_and_git_folders_are_skipped(self):
        bad = SAMPLES["a GitHub token"]
        r = scan_dir({".git/config": bad, "x/__pycache__/m.txt": bad, ".ruff_cache/c": bad})
        self.assertEqual(r.returncode, 0, r.stdout)

    def test_usage_error(self):
        r = subprocess.run([sys.executable, "-I", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
