"""Display-free tests for Configs/.local/bin/wallbash-matugen.

The script turns matugen's JSON into HyDE's wall.dcol. It reads HOME-relative paths when imported, so each
test imports a fresh copy under a throwaway HOME. Run:

    python3 -I tools/tests/test_wallbash_matugen.py
"""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import pathlib
import re
import tempfile
import unittest
from unittest import mock

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / "Configs/.local/bin/wallbash-matugen"

TONES = (10, 20, 30, 40, 50, 60, 70, 80, 90, 95)


def make_data(is_dark=True):
    """A matugen document in which every colour says where it came from."""
    def role(light, dark):
        return {"default": {"color": dark}, "dark": {"color": dark}, "light": {"color": light}}

    palettes = {
        fam: {str(t): {"color": f"#{i:02x}{t:02x}00"} for t in TONES}
        for i, fam in enumerate(("primary", "secondary", "tertiary", "neutral_variant"), start=1)
    }
    colors = {
        "background": role("#fafafa", "#101010"),
        "surface_container": role("#f0f0f0", "#181818"),
        "surface_container_high": role("#e0e0e0", "#202020"),
        "surface_container_highest": role("#d0d0d0", "#282828"),
        "on_background": role("#111111", "#eeeeee"),
        "on_surface": role("#222222", "#dddddd"),
        "on_surface_variant": role("#333333", "#cccccc"),
    }
    return {"is_dark_mode": is_dark, "palettes": palettes, "colors": colors}


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name)
        env = {"HOME": str(self.home)}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)
        for var in ("XDG_CACHE_HOME", "XDG_STATE_HOME"):
            os.environ.pop(var, None)
        loader = importlib.machinery.SourceFileLoader("wallbash_matugen", str(SCRIPT))
        spec = importlib.util.spec_from_loader("wallbash_matugen", loader)
        self.mod = importlib.util.module_from_spec(spec)
        loader.exec_module(self.mod)

    def set_prefs(self, text):
        self.mod.PREFS.parent.mkdir(parents=True, exist_ok=True)
        self.mod.PREFS.write_text(text)


class Helpers(Base):
    def test_rgba_keeps_hydes_alpha_placeholder(self):
        self.assertEqual(self.mod.rgba("#ff8000"), "rgba(255,128,0,\\1)")
        self.assertEqual(self.mod.rgba("00000a"), "rgba(0,0,10,\\1)")

    def test_role_prefers_the_asked_mode_then_default(self):
        colors = {"x": {"default": {"color": "#111111"}, "light": {"color": "#eeeeee"}}}
        self.assertEqual(self.mod.role(colors, "x", "light"), "#eeeeee")
        self.assertEqual(self.mod.role(colors, "x", "dark"), "#111111")

    def test_role_missing_exits(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.mod.role({}, "nope", "dark")

    def test_tone_exact_and_nearest(self):
        pal = make_data()["palettes"]
        self.assertEqual(self.mod.tone(pal, "primary", 40), pal["primary"]["40"]["color"])
        # 95 exists; 100 does not and must fall back to the nearest one (95)
        self.assertEqual(self.mod.tone(pal, "primary", 100), pal["primary"]["95"]["color"])
        # 5 is nearest to 10
        self.assertEqual(self.mod.tone(pal, "primary", 5), pal["primary"]["10"]["color"])

    def test_tone_missing_family_exits(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.mod.tone({}, "primary", 40)


class ModeOf(Base):
    def test_explicit_preference_wins_over_the_image(self):
        self.set_prefs(json.dumps({"theme.mode": "light"}))
        self.assertEqual(self.mod.mode_of({"is_dark_mode": True}), "light")
        self.set_prefs(json.dumps({"theme.mode": "dark"}))
        self.assertEqual(self.mod.mode_of({"is_dark_mode": False}), "dark")

    def test_auto_follows_the_image(self):
        self.set_prefs(json.dumps({"theme.mode": "auto"}))
        self.assertEqual(self.mod.mode_of({"is_dark_mode": True}), "dark")
        self.assertEqual(self.mod.mode_of({"is_dark_mode": False}), "light")

    def test_missing_or_broken_prefs_fall_back_to_the_image(self):
        self.assertEqual(self.mod.mode_of({"is_dark_mode": True}), "dark")
        self.set_prefs("{not json")
        self.assertEqual(self.mod.mode_of({"is_dark_mode": False}), "light")
        self.set_prefs(json.dumps({"theme.mode": "sepia"}))
        self.assertEqual(self.mod.mode_of({}), "light")


class Build(Base):
    def parse(self, text):
        return dict(re.findall(r'^(\w+)="(.*)"$', text, flags=re.M))

    def test_shape(self):
        mode, text = self.mod.build(make_data())
        kv = self.parse(text)
        self.assertEqual(mode, "dark")
        self.assertEqual(kv["dcol_mode"], "dark")
        # 1 mode line + (4 pry + 4 txt) * 2 + (4 families * 9 tones) * 2
        self.assertEqual(len(text.splitlines()), 1 + 16 + 72)
        for i in range(1, 5):
            self.assertIn(f"dcol_pry{i}", kv)
            self.assertIn(f"dcol_txt{i}_rgba", kv)
        for n in range(1, 5):
            for m in range(1, 10):
                self.assertIn(f"dcol_{n}xa{m}", kv)

    def test_hex_is_upper_case_without_hash(self):
        kv = self.parse(self.mod.build(make_data())[1])
        for key, val in kv.items():
            if key.endswith("_rgba") or key == "dcol_mode":
                continue
            self.assertRegex(val, r"^[0-9A-F]{6}$", key)

    def test_background_is_the_background_role(self):
        """pry1 must be the window background itself, not a tone beside it."""
        kv = self.parse(self.mod.build(make_data())[1])
        self.assertEqual(kv["dcol_pry1"], "101010")
        self.assertEqual(kv["dcol_pry4"], "282828")
        self.assertEqual(kv["dcol_txt1"], "EEEEEE")

    def test_light_mode_uses_the_light_roles(self):
        self.set_prefs(json.dumps({"theme.mode": "light"}))
        mode, text = self.mod.build(make_data(is_dark=True))
        kv = self.parse(text)
        self.assertEqual(mode, "light")
        self.assertEqual(kv["dcol_pry1"], "FAFAFA")

    def test_ramp_runs_from_light_to_dark(self):
        """Regression: step 1 is the lightest tone (95) and step 9 the darkest (20), in both modes."""
        for mode in ("dark", "light"):
            self.set_prefs(json.dumps({"theme.mode": mode}))
            kv = self.parse(self.mod.build(make_data())[1])
            # make_data() encodes family number and tone in the colour: tone 95 is 0x5f, tone 20 is 0x14
            for n in (1, 2, 3, 4):
                self.assertEqual(kv[f"dcol_{n}xa1"], f"{n:02X}5F00", (mode, n))
                self.assertEqual(kv[f"dcol_{n}xa9"], f"{n:02X}1400", (mode, n))

    def test_rgba_matches_hex(self):
        kv = self.parse(self.mod.build(make_data())[1])
        self.assertEqual(kv["dcol_pry1_rgba"], "rgba(16,16,16,\\1)")

    def test_missing_inputs_exit(self):
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self.mod.build({"colors": {}})
            with self.assertRaises(SystemExit):
                self.mod.build({"palettes": {}})


class Main(Base):
    def setUp(self):
        super().setUp()
        self.mod.MATUGEN.parent.mkdir(parents=True)
        self.mod.MATUGEN.write_text(json.dumps(make_data()))
        real = self.mod.DCOL_LINK.parent / "wallbash" / "abc.dcol"
        real.parent.mkdir(parents=True)
        real.write_text("old")
        self.real = real
        self.mod.DCOL_LINK.symlink_to(real)

    def run_main(self, *argv):
        out = io.StringIO()
        with mock.patch("sys.argv", ["wallbash-matugen", *argv]), contextlib.redirect_stdout(out), \
                mock.patch.object(self.mod.subprocess, "run") as run:
            code = self.mod.main()
        return code, out.getvalue(), run

    def test_dry_run_changes_nothing(self):
        code, out, run = self.run_main("--dry")
        self.assertEqual(code, 0)
        self.assertIn("dcol_mode=", out)
        self.assertEqual(self.real.read_text(), "old")
        run.assert_not_called()

    def test_writes_through_the_symlink_and_is_idempotent(self):
        code, out, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertTrue(self.mod.DCOL_LINK.is_symlink())
        self.assertIn('dcol_mode="dark"', self.real.read_text())
        self.assertIn("wrote dark palette", out)
        before = self.real.stat().st_mtime_ns
        code, out, run = self.run_main()
        self.assertIn("already matches", out)
        run.assert_not_called()  # nothing to rebuild, so no loop with the file watcher
        self.assertEqual(self.real.stat().st_mtime_ns, before)

    def test_rebuilds_templates_when_hyde_has_the_script(self):
        lib = self.home / ".local/lib/hyde/theme.switch.sh"
        lib.parent.mkdir(parents=True)
        lib.write_text("#!/bin/sh\n")
        _, _, run = self.run_main()
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0][0], "bash")

    def test_no_matugen_cache_exits(self):
        self.mod.MATUGEN.unlink()
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.run_main()

    def test_hyde_not_run_yet_exits(self):
        self.mod.DCOL_LINK.unlink()
        self.mod.DCOL_LINK.symlink_to(self.home / "nowhere/missing.dcol")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.run_main()


if __name__ == "__main__":
    unittest.main()
