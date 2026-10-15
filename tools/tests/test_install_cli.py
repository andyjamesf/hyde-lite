"""install.sh's command line, which can be tested without Arch: help text, argument validation, and the
refusal to run where it is not supported. Nothing is installed and HOME is a throwaway directory. Run:

    python3 -I tools/tests/test_install_cli.py

NOT TESTED here (needs a real Arch system with sudo): the installation steps themselves, --dry-run's
effect on $HOME, services, chsh and the login screen.
"""
import os
import pathlib
import pty
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "install.sh"
ARCH = pathlib.Path("/etc/arch-release").exists() and os.geteuid() != 0
LOGO_WIDTH = 65
LOGO_ROWS = 6


class InstallCli(unittest.TestCase):
    def run_install(self, *args):
        """Run install.sh in a throwaway HOME with a fake `sudo` first on PATH. install.sh asks for sudo and runs
        pacman as soon as it gets past its checks, and on a real Arch system that is where these tests would start
        really installing: the fake records the call and refuses, and the test fails instead of prompting."""
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as fake:
            marker = pathlib.Path(fake) / "sudo-was-called"
            sudo = pathlib.Path(fake) / "sudo"
            sudo.write_text(f'#!/bin/sh\necho "$@" >> "{marker}"\nexit 1\n')
            sudo.chmod(0o755)
            env = {"HOME": home, "PATH": f"{fake}:{os.environ['PATH']}", "NO_COLOR": "1"}
            r = subprocess.run(["bash", str(SCRIPT), *args], env=env, capture_output=True, text=True,
                               stdin=subprocess.DEVNULL, timeout=60)
            self.assertFalse(marker.exists(), f"install.sh called sudo with {args}: {marker.read_text() if marker.exists() else ''}")
            leftovers = sorted(os.listdir(home))
        return r, leftovers

    def test_the_harness_fails_instead_of_letting_the_installer_reach_sudo(self):
        global SCRIPT
        real = SCRIPT
        with tempfile.TemporaryDirectory() as d:
            stand_in = pathlib.Path(d) / "install.sh"
            stand_in.write_text("#!/bin/bash\nsudo -v\n")
            SCRIPT = stand_in
            try:
                with self.assertRaises(AssertionError) as caught:
                    self.run_install("--shell", "zsh")
            finally:
                SCRIPT = real
        self.assertIn("called sudo", str(caught.exception))

    def test_help_documents_every_option_and_changes_nothing(self):
        r, leftovers = self.run_install("--help")
        self.assertEqual(r.returncode, 0, r.stderr)
        for opt in ("--nvidia", "--shell", "--aur-helper", "--island", "--bar", "--no-services",
                    "--interactive", "--dry-run", "--help"):
            self.assertIn(opt, r.stdout)
        self.assertEqual(leftovers, [])

    def test_unknown_option_is_rejected(self):
        r, leftovers = self.run_install("--frobnicate")
        self.assertEqual(r.returncode, 2)
        self.assertIn("unknown option '--frobnicate'", r.stderr)
        self.assertEqual(leftovers, [])

    def test_shell_must_be_zsh_or_fish(self):
        for value in ("bash", "", "zsh;id"):
            args = ["--shell", value] if value else ["--shell"]
            r, _ = self.run_install(*args)
            self.assertEqual(r.returncode, 2, (value, r.stderr))
            self.assertIn("--shell must be zsh or fish", r.stderr)
        for value in ("zsh", "fish"):
            r, _ = self.run_install("--shell", value, "--dry-run")
            self.assertNotEqual(r.returncode, 2, value)  # the option is accepted (what follows is a dry run)

    def test_aur_helper_name_is_validated(self):
        for value in ("yay; rm -rf ~", "$(id)", "Yay", "a b", ""):
            args = ["--aur-helper", value] if value else ["--aur-helper"]
            r, _ = self.run_install(*args)
            self.assertEqual(r.returncode, 2, (value, r.stderr))
            self.assertIn("bad --aur-helper", r.stderr)
        r, _ = self.run_install("--aur-helper", "paru-bin", "--dry-run")
        self.assertNotEqual(r.returncode, 2)

    def header_rows(self, columns, tty):
        """The first lines install.sh prints, with COLUMNS set, on a pseudo-terminal or a pipe."""
        with tempfile.TemporaryDirectory() as home:
            env = {"HOME": home, "PATH": os.environ["PATH"], "NO_COLOR": "1", "LANG": "C.UTF-8", "COLUMNS": columns}
            if tty:
                master, slave = pty.openpty()
                subprocess.run(["bash", str(SCRIPT), "--dry-run"], env=env, stdout=slave, stderr=slave,
                               stdin=subprocess.DEVNULL, timeout=60, check=False)
                os.close(slave)
                out = b""
                try:
                    while chunk := os.read(master, 65536):
                        out += chunk
                except OSError:  # Linux reports the closed slave side as EIO
                    pass
                os.close(master)
            else:
                out = subprocess.run(["bash", str(SCRIPT), "--dry-run"], env=env, capture_output=True,
                                     stdin=subprocess.DEVNULL, timeout=60, check=False).stdout
        return out.decode().replace("\r", "").split("\n")

    def indents(self, rows):
        return [len(r) - len(r.lstrip(" ")) for r in rows]

    def test_logo_is_centred_on_a_terminal(self):
        for cols in (80, 101, 140):
            rows = self.header_rows(str(cols), tty=True)
            logo = rows[:LOGO_ROWS]
            self.assertTrue(all(r.lstrip().startswith(("█", "╚")) for r in logo), logo)
            self.assertEqual(self.indents(logo), [(cols - LOGO_WIDTH) // 2] * LOGO_ROWS, cols)
            # the dim lines under it are centred too (within one column for odd widths)
            for row in rows[LOGO_ROWS:LOGO_ROWS + 2]:
                text = row.strip()
                self.assertLessEqual(abs(self.indents([row])[0] - (cols - len(text)) // 2), 1, (cols, row))

    def test_logo_stays_at_column_zero_when_output_is_not_a_terminal(self):
        rows = self.header_rows("101", tty=False)
        self.assertEqual(self.indents(rows[:LOGO_ROWS]), [0] * LOGO_ROWS)
        self.assertEqual(self.indents(rows[LOGO_ROWS:LOGO_ROWS + 2]), [2, 2])  # the old two-space indent

    def test_narrow_or_bogus_width_is_not_padded_wrongly(self):
        rows = self.header_rows("40", tty=True)
        self.assertEqual(self.indents(rows[:LOGO_ROWS]), [0] * LOGO_ROWS)
        rows = self.header_rows("abc", tty=True)  # not a number: falls back to 80 columns
        self.assertEqual(self.indents(rows[:LOGO_ROWS]), [(80 - LOGO_WIDTH) // 2] * LOGO_ROWS)

    @unittest.skipIf(ARCH, "this machine is a non-root Arch system: the installer would really run")
    def test_refuses_to_run_as_root_or_off_arch(self):
        r, leftovers = self.run_install("--dry-run")
        self.assertEqual(r.returncode, 1)
        self.assertRegex(r.stderr, r"run as your normal user|supports Arch Linux only")
        self.assertEqual(leftovers, [])


if __name__ == "__main__":
    unittest.main()
