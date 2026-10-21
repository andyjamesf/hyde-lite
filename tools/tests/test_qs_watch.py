"""tools/qs-watch.sh against a fake `qs`: a busy one must produce exactly one snapshot with the expected
sections, an idle one none, and a missing one must not crash. The fake is a shell script called `qs` that
spins (or sleeps), and answers `qs -p DIR log` with a few repeated lines. Run:

    python3 -I tools/tests/test_qs_watch.py

NOT TESTED here: a real Quickshell (its `log` output and thread names).
"""
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "tools/qs-watch.sh"

# `qs -p CONFIG log [-t N]` is answered by this script. The running "shell" is a Python process whose command
# line contains `qs -p CONFIG`, which is what the watcher looks for, so its behaviour can be timed exactly.
FAKE_QS = """#!/bin/sh
i=0; while [ $i -lt 5 ]; do echo "  WARN qt.qpa.wayland.textinput: disableSurface but 0x0 is focused"; i=$((i+1)); done
echo "  INFO something else"
"""
RUNNING = {
    "busy": "while 1: pass",
    "idle": "import time; time.sleep(60)",
    # busy for the first 1.8 s only: one busy sample, then quiet
    "burst": "import time\nend = time.time() + 1.8\nwhile time.time() < end: pass\ntime.sleep(60)",
    # busy 0-1.8 s, quiet until 4 s, busy again until 6.5 s: busy samples that are not consecutive
    "twice": ("import time\nt0 = time.time()\n"
              "def spin(until):\n    while time.time() - t0 < until: pass\n"
              "spin(1.8); time.sleep(max(0, 4.0 - (time.time() - t0))); spin(6.5); time.sleep(60)"),
}


class Watch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        (self.bin / "qs").write_text(FAKE_QS)
        (self.bin / "qs").chmod(0o755)
        self.cfg = self.dir / "cfg"
        self.cfg.mkdir()
        self.out = self.dir / "out"
        self.procs = []
        self.addCleanup(self.stop)

    def stop(self):
        for p in self.procs:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            p.wait()

    def env(self):
        return {"PATH": f"{self.bin}:{os.environ['PATH']}", "HOME": str(self.dir)}

    def start_fake(self, mode):
        p = subprocess.Popen([sys.executable, "-I", "-c", RUNNING[mode], "qs", "-p", str(self.cfg)], env=self.env(),
                             start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.procs.append(p)
        time.sleep(0.3)
        return p

    def watch(self, *extra):
        cmd = [str(SCRIPT), str(self.cfg), "--out", str(self.out), "--interval", "1", "--window", "1",
               "--threshold", "50", "--hits", "2", "--max-loops", "6", *extra]
        return subprocess.run(cmd, env=self.env(), capture_output=True, text=True, timeout=60, check=False)

    def test_a_busy_shell_gets_one_snapshot(self):
        self.start_fake("busy")
        r = self.watch()
        self.assertEqual(r.returncode, 0, r.stderr)
        snaps = sorted(self.out.glob("qs-snap-*.txt"))
        self.assertEqual(len(snaps), 1)
        self.assertEqual(r.stdout.strip(), str(snaps[0]))
        text = snaps[0].read_text()
        for section in ("--- threads by CPU", "open files:", "--- most repeated lines of the log", "--- last lines of the log"):
            self.assertIn(section, text)
        # `uniq -c` puts the count first: the repeated line must be on top, with its count of 5
        self.assertRegex(text, r"(?m)^\s*5 WARN qt\.qpa\.wayland\.textinput")
        self.assertRegex(text, r"(?m)^\s*1 INFO something else")
        log = (self.out / "qs-watch.log").read_text()
        self.assertRegex(log, r"cpu=\d+%")
        self.assertIn("snapshot:", log)

    def test_an_idle_shell_gets_none(self):
        self.start_fake("idle")
        r = self.watch()
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(list(self.out.glob("qs-snap-*.txt")), [])
        self.assertIn("gave up", (self.out / "qs-watch.log").read_text())

    def test_no_shell_running_does_not_crash(self):
        r = self.watch("--max-loops", "2")
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(list(self.out.glob("qs-snap-*.txt")), [])

    def test_one_busy_sample_is_not_enough_with_hits_two(self):
        """A shell that is busy for a moment (a menu opening) must not trigger a snapshot..."""
        self.start_fake("burst")
        r = self.watch("--max-loops", "4")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertEqual(list(self.out.glob("qs-snap-*.txt")), [])
        busy = [line for line in (self.out / "qs-watch.log").read_text().splitlines() if "cpu=" in line]
        self.assertTrue(any(int(line.split("cpu=")[1].rstrip("%")) > 50 for line in busy), busy)  # it did see the burst

    def test_busy_samples_with_a_quiet_one_between_are_not_a_runaway(self):
        """Two busy samples count only if they are consecutive: a quiet one in between starts the count again."""
        self.start_fake("twice")
        r = self.watch("--max-loops", "4")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertEqual(list(self.out.glob("qs-snap-*.txt")), [])
        cpus = [int(line.split("cpu=")[1].rstrip("%")) for line in (self.out / "qs-watch.log").read_text().splitlines() if "cpu=" in line]
        self.assertGreater(cpus[0], 50)
        self.assertLess(cpus[1], 50)
        self.assertGreater(cpus[2], 50)

    def test_a_single_busy_sample_is_enough_with_hits_one(self):
        """...unless the owner asks for that."""
        self.start_fake("burst")
        r = self.watch("--hits", "1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(list(self.out.glob("qs-snap-*.txt"))), 1)

    def test_bad_arguments(self):
        for args in (["--threshold", "x"], ["--bogus"], ["--window", "0"], ["--out"]):
            r = subprocess.run([str(SCRIPT), *args], capture_output=True, text=True, timeout=30, check=False)
            self.assertEqual(r.returncode, 2, args)
        r = subprocess.run([str(SCRIPT), "--help"], capture_output=True, text=True, timeout=30, check=False)
        self.assertEqual(r.returncode, 0)
        self.assertIn("--threshold", r.stdout)

    def test_the_default_config_is_not_a_personal_path(self):
        text = SCRIPT.read_text()
        self.assertNotIn("/home/", text)
        self.assertIn("${XDG_CONFIG_HOME:-$HOME/.config}/quickshell", text)


if __name__ == "__main__":
    unittest.main()
