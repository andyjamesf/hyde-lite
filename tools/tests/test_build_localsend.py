"""tools/build_localsend.sh, run for real against a throwaway tree, with fake `cargo` and `sudo`.

    python3 -I tools/tests/test_build_localsend.py

NOT TESTED here: the real compile and the real `pacman -S rust` (they need the network and Arch).
"""
import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools/build_localsend.sh"
# Everything the script may call. PATH holds only these and the fakes, so no real cargo or sudo is reachable.
TOOLS = ("bash", "cat", "chmod", "cp", "cut", "dirname", "env", "find", "install", "mkdir", "mv", "realpath", "rm",
         "sha256sum", "sort", "xargs")

# Writes a "binary" that holds the source's main.rs, so a test can tell which source it was built from.
FAKE_CARGO = """#!/bin/bash
echo "$*" >>"$LOG/cargo"
[[ -e $LOG/cargo-fails ]] && { echo "error: could not compile" >&2; exit 101; }
mkdir -p "$CARGO_TARGET_DIR/release"
cp cli/src/main.rs "$CARGO_TARGET_DIR/release/localsend-cli"
"""


class Build(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = pathlib.Path(tmp.name)
        self.home, self.log, self.bin, self.repo = (root / n for n in ("home", "log", "bin", "repo"))
        for d in (self.home, self.log, self.bin, self.repo / "tools", self.repo / "third-party/localsend-cli/cli/src"):
            d.mkdir(parents=True)
        if SCRIPT.exists():
            shutil.copy(SCRIPT, self.repo / "tools")
        self.source = self.repo / "third-party/localsend-cli/cli/src/main.rs"
        self.source.write_text("version one\n")
        for name in TOOLS:
            os.symlink(shutil.which(name) or name, self.bin / name)
        self.dest = self.home / ".local/bin/localsend-cli"
        self.cache = self.home / ".cache/hyde-lite/localsend-build"

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o755)

    def run_script(self, dry=0, **extra):
        env = {"HOME": str(self.home), "PATH": str(self.bin), "LOG": str(self.log), "flg_DryRun": str(dry), **extra}
        return subprocess.run(["bash", str(self.repo / "tools/build_localsend.sh")], env=env, capture_output=True,
                              text=True, stdin=subprocess.DEVNULL, timeout=60, cwd=self.home)

    def calls(self, name):
        path = self.log / name
        return path.read_text().splitlines() if path.exists() else []

    def test_builds_the_vendored_source_and_installs_it(self):
        self.fake("cargo", FAKE_CARGO)
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.dest.read_text(), "version one\n")
        self.assertTrue(os.access(self.dest, os.X_OK))
        self.assertEqual(self.calls("cargo"), ["build --release --locked -p localsend-cli"])
        self.assertFalse(self.cache.exists(), "the build directory is hundreds of MB and is not kept")
        self.assertEqual(sorted(p.name for p in (self.repo / "third-party/localsend-cli").iterdir()), ["cli"])

    def test_unchanged_source_is_not_built_again_even_if_a_readme_changes(self):
        self.fake("cargo", FAKE_CARGO)
        self.run_script()
        (self.repo / "third-party/localsend-cli/README.md").write_text("new words\n")
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("up to date", r.stdout)
        self.assertEqual(len(self.calls("cargo")), 1)

    def test_changed_source_is_built_again(self):
        self.fake("cargo", FAKE_CARGO)
        self.run_script()
        self.source.write_text("version two\n")
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.dest.read_text(), "version two\n")

    def test_a_missing_binary_is_built_again(self):
        self.fake("cargo", FAKE_CARGO)
        self.run_script()
        self.dest.unlink()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertTrue(self.dest.exists())

    def test_a_failed_build_keeps_the_old_binary_and_is_retried(self):
        self.fake("cargo", FAKE_CARGO)
        self.run_script()
        self.source.write_text("version two\n")
        (self.log / "cargo-fails").touch()
        r = self.run_script()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("[err]", r.stdout)  # install.sh looks for this marker
        self.assertEqual(self.dest.read_text(), "version one\n")
        (self.log / "cargo-fails").unlink()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.dest.read_text(), "version two\n")

    def test_installs_rust_only_when_there_is_no_cargo(self):
        # The fake sudo "installs" rust by putting the fake cargo on PATH.
        (self.log / "cargo-template").write_text(FAKE_CARGO)
        self.fake("sudo", '#!/bin/bash\necho "$*" >>"$LOG/sudo"\n'
                          f'cp "$LOG/cargo-template" "{self.bin}/cargo"; chmod +x "{self.bin}/cargo"\n')
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.calls("sudo"), ["pacman -S --needed --noconfirm rust"])
        self.source.write_text("version two\n")
        self.run_script()
        self.assertEqual(len(self.calls("sudo")), 1)

    def test_reports_it_when_rust_cannot_be_installed(self):
        self.fake("sudo", "#!/bin/bash\nexit 1\n")
        r = self.run_script()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("[err]", r.stdout)
        self.assertFalse(self.dest.exists())

    def test_a_relative_xdg_cache_home_is_ignored(self):
        # The XDG specification: a relative path in these variables is invalid.
        self.fake("cargo", FAKE_CARGO)
        r = self.run_script(XDG_CACHE_HOME="relative-cache")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.dest.read_text(), "version one\n")
        self.assertEqual(list(self.repo.rglob("relative-cache")) + list(self.home.rglob("relative-cache")), [])

    def test_a_run_interrupted_while_cleaning_up_is_finished_by_the_next_one(self):
        self.fake("cargo", FAKE_CARGO)
        (self.bin / "rm").unlink()
        self.fake("rm", "#!/bin/bash\nexit 130\n")  # as if interrupted while removing the build directory
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertTrue(self.cache.exists())
        (self.bin / "rm").unlink()
        os.symlink(shutil.which("rm") or "rm", self.bin / "rm")
        self.assertEqual(self.run_script().returncode, 0)
        self.assertFalse(self.cache.exists(), "the leftover build directory is removed")

    def test_a_dry_run_changes_nothing(self):
        self.fake("cargo", FAKE_CARGO)
        self.fake("sudo", '#!/bin/bash\necho "$*" >>"$LOG/sudo"\n')
        r = self.run_script(dry=1)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("would", r.stdout)
        self.assertEqual((self.calls("cargo"), self.calls("sudo"), list(self.home.iterdir())), ([], [], []))


class Installer(unittest.TestCase):
    def test_install_sh_runs_it_as_a_step(self):
        self.assertIn('run_step "LocalSend" "$root/tools/build_localsend.sh"', (REPO / "install.sh").read_text())


if __name__ == "__main__":
    unittest.main()
