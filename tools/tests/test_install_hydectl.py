"""Display-free tests for Scripts/install_hydectl.sh, and a guard against committing binaries. Run:

    python3 -I tools/tests/test_install_hydectl.py

The script downloads with curl, so the tests give it a file:// URL to a tarball they build, and a throwaway
target through HYDECTL_URL, HYDECTL_SHA256 and HYDECTL_BIN.
"""
import hashlib
import io
import os
import pathlib
import subprocess
import tarfile
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/install_hydectl.sh"


def tarball(path, members):
    with tarfile.open(path, "w:gz") as tar:
        for name, data in members.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o755
            tar.addfile(info, io.BytesIO(data))
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


class InstallHydectl(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = pathlib.Path(tmp.name)
        self.bin = self.tmp / "bin/hydectl"
        self.archive = self.tmp / "hydectl.tar.gz"
        self.sha = tarball(self.archive, {"hydectl-1-linux-amd64": b"#!/bin/sh\necho hydectl\n", "README.md": b"x"})

    def run_script(self, url=None, sha=None):
        env = {**os.environ, "HYDECTL_URL": url or self.archive.as_uri(), "HYDECTL_SHA256": sha or self.sha,
               "HYDECTL_BIN": str(self.bin)}
        return subprocess.run([str(SCRIPT)], env=env, capture_output=True, text=True)

    def test_installs_the_executable_and_records_the_checksum(self):
        done = self.run_script()
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertTrue(os.access(self.bin, os.X_OK))
        self.assertEqual(self.bin.with_name("hydectl.sha256").read_text().strip(), self.sha)
        self.assertEqual(self.bin.read_text(), "#!/bin/sh\necho hydectl\n")  # not the README

    def test_second_run_downloads_nothing(self):
        self.assertEqual(self.run_script().returncode, 0)
        done = self.run_script(url=(self.tmp / "gone.tar.gz").as_uri())
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("already installed", done.stdout)

    def test_a_download_that_does_not_match_the_checksum_is_refused(self):
        done = self.run_script(sha="0" * 64)
        self.assertEqual(done.returncode, 1)
        self.assertIn("[err]", done.stderr)  # install.sh counts "[err]" lines as a failed step
        self.assertFalse(self.bin.exists())

    def test_an_unreachable_url_fails_with_an_err_line(self):
        done = self.run_script(url=(self.tmp / "gone.tar.gz").as_uri())
        self.assertEqual(done.returncode, 1)
        self.assertIn("[err]", done.stderr)

    def test_an_archive_without_an_executable_is_refused(self):
        sha = tarball(self.archive, {"README.md": b"x"})
        done = self.run_script(sha=sha)
        self.assertEqual(done.returncode, 1)
        self.assertFalse(self.bin.exists())


class NoBinaries(unittest.TestCase):
    def test_no_elf_executable_is_tracked(self):
        files = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True,
                               check=True).stdout.split("\0")
        elf = [f for f in files if f and (ROOT / f).is_file() and not (ROOT / f).is_symlink()
               and (ROOT / f).read_bytes()[:4] == b"\x7fELF"]
        self.assertEqual(elf, [], "binaries belong in a release download with a pinned checksum, see Scripts/install_hydectl.sh")


if __name__ == "__main__":
    unittest.main()
