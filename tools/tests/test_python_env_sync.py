"""pyutils/python_env.py `sync`: says nothing when `uv sync --check` finds nothing to do, and announces a real
install. The module is imported with a fake xdg_base_dirs (a package of HyDE's own virtual environment), and
subprocess.run, run_uv and notify.send are replaced, so nothing is installed and nothing is shown. Run:

    python3 -I tools/tests/test_python_env_sync.py
"""
import importlib.util
import os
import shutil
import sys
import tempfile
import types
import unittest
from pathlib import Path

PYUTILS = Path(__file__).resolve().parents[2] / "Configs/.local/lib/hyde/pyutils"


def load():
    """The module, imported with a fake xdg_base_dirs that is taken out of sys.modules again."""
    fake = types.ModuleType("xdg_base_dirs")
    fake.xdg_state_home = lambda: Path("/nonexistent-state")
    before_path, before_mod = list(sys.path), sys.modules.get("xdg_base_dirs")
    sys.modules["xdg_base_dirs"] = fake
    try:
        spec = importlib.util.spec_from_file_location("python_env_under_test", PYUTILS / "python_env.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    finally:
        sys.path[:] = before_path
        if before_mod is None:
            sys.modules.pop("xdg_base_dirs", None)
        else:
            sys.modules["xdg_base_dirs"] = before_mod
    return module


class Sync(unittest.TestCase):
    def setUp(self):
        self.env = load()
        self.notes, self.uv_runs, self.checks = [], [], []
        self.env.notify.send = lambda *a, **k: self.notes.append(a)
        self.env.run_uv = lambda args, **k: self.uv_runs.append((args, k))
        self.env.get_uv = lambda: "/usr/bin/uv"
        # python_env.subprocess is the real module: put its run() back after each test.
        original = self.env.subprocess.run
        self.addCleanup(setattr, self.env.subprocess, "run", original)

    def check_returns(self, code):
        def run(cmd, **kwargs):
            self.checks.append(cmd)
            return types.SimpleNamespace(returncode=code)
        self.env.subprocess.run = run

    def test_nothing_to_install_is_silent_and_runs_no_sync(self):
        self.check_returns(0)
        self.env.sync_packages()
        self.assertEqual((self.notes, self.uv_runs), ([], []))
        self.assertEqual(len(self.checks), 1)
        self.assertEqual(self.checks[0][:3], ["/usr/bin/uv", "sync", "--check"])
        self.assertIn("--active", self.checks[0])

    def test_something_to_install_syncs_and_announces_it(self):
        self.check_returns(1)
        self.env.sync_packages()
        self.assertEqual(self.uv_runs, [(["sync"], {"notify_msg": "📦 Syncing dependencies..."})])
        self.assertEqual([n[1] for n in self.notes], ["✅ Dependencies are up to date"])

    def test_an_old_uv_without_check_falls_back_to_the_old_behaviour(self):
        self.check_returns(2)                       # uv: unrecognised option
        self.env.sync_packages()
        self.assertEqual(len(self.uv_runs), 1)
        self.assertEqual(len(self.notes), 1)

    def test_no_uv_at_all_falls_through_to_run_uv_which_reports_it(self):
        def missing():
            raise FileNotFoundError("uv")
        self.env.get_uv = missing
        self.env.sync_packages()
        self.assertEqual(len(self.uv_runs), 1)

    def test_the_check_not_starting_is_not_synced(self):
        def boom(cmd, **kwargs):
            raise OSError("cannot run")
        self.env.subprocess.run = boom
        self.assertFalse(self.env.is_synced())


class Create(unittest.TestCase):
    """create_venv: a valid environment is not worth a notification; a broken one still is."""

    def setUp(self):
        self.env = load()
        self.notes, self.uv_runs, self.destroyed = [], [], []
        self.env.notify.send = lambda *a, **k: self.notes.append(a)
        self.env.run_uv = lambda args, **k: self.uv_runs.append(args)
        self.env.destroy_venv = lambda path: self.destroyed.append(path)
        self.venv = Path(tempfile.mkdtemp()) / "python_env"
        self.addCleanup(shutil.rmtree, self.venv.parent, ignore_errors=True)
        self.env.get_venv_path = lambda: str(self.venv)

    def make_valid_venv(self):
        (self.venv / "bin").mkdir(parents=True)
        python = self.venv / "bin/python"
        python.write_text("#!/bin/sh\n")
        os.chmod(python, 0o755)
        (self.venv / "pyvenv.cfg").write_text(f"version = {sys.version_info.major}.{sys.version_info.minor}.0\n")

    def test_a_valid_environment_is_left_alone_without_a_word(self):
        self.make_valid_venv()
        self.env.create_venv()
        self.assertEqual((self.notes, self.uv_runs, self.destroyed), ([], [], []))

    def test_a_broken_environment_is_announced_and_recreated(self):
        (self.venv / "bin").mkdir(parents=True)                   # no python in it
        self.env.create_venv()
        self.assertEqual([n[1] for n in self.notes][0], "⚠️ Broken venv detected, recreating…")
        self.assertEqual(self.destroyed, [str(self.venv)])
        self.assertEqual(self.uv_runs, [["sync"]])

    def test_no_environment_is_created_and_announced(self):
        self.env.create_venv()
        self.assertEqual(self.uv_runs, [["sync"]])
        self.assertEqual([n[1] for n in self.notes], ["✅ Virtual environment ready"])


if __name__ == "__main__":
    unittest.main()
