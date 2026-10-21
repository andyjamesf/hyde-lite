"""terminal.zsh's _load_completions: an empty or missing completions folder is not an error, a file in it is
sourced. Without the (N) glob qualifier zsh stops with "no matches found" and the caller prints "Error: Could not
source terminal.zsh" on every shell start. Skipped where zsh is not installed. Run:

    python3 -I tools/tests/test_zsh_completions.py
"""
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

TERMINAL = Path(__file__).resolve().parents[2] / "Configs/.config/zsh/conf.d/hyde/terminal.zsh"


def function_source():
    m = re.search(r"^function _load_completions\(\) \{\n.*?^\}\n", TERMINAL.read_text(), re.S | re.M)
    assert m, "_load_completions not found in terminal.zsh"
    return m.group(0)


@unittest.skipUnless(shutil.which("zsh"), "zsh is not installed")
class LoadCompletions(unittest.TestCase):
    def run_zsh(self, zdotdir):
        script = function_source() + "\n_load_completions\necho \"rc=$?\"\n"
        return subprocess.run(["zsh", "-f", "-c", script], capture_output=True, text=True,
                              env={"PATH": "/usr/bin:/bin", "ZDOTDIR": str(zdotdir)})

    def test_a_missing_folder_is_fine(self):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        r = self.run_zsh(d)
        self.assertEqual((r.stderr, r.stdout.strip()), ("", "rc=0"))

    def test_an_empty_folder_is_fine(self):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        (d / "completions").mkdir()
        r = self.run_zsh(d)
        self.assertEqual((r.stderr, r.stdout.strip()), ("", "rc=0"))

    def test_a_file_in_it_is_sourced(self):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d, ignore_errors=True)
        (d / "completions").mkdir()
        (d / "completions/one.zsh").write_text("echo sourced-one\n")
        (d / "completions/note.txt").write_text("echo not-sourced\n")
        r = self.run_zsh(d)
        self.assertEqual(r.stderr, "")
        self.assertIn("sourced-one", r.stdout)
        self.assertNotIn("not-sourced", r.stdout)


if __name__ == "__main__":
    unittest.main()
