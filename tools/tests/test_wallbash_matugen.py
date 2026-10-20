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

    def test_ramp_starts_next_to_the_background(self):
        """Step 1 is the tone beside the window background and step 9 the one beside the text, in both modes.

        Measured on the 561 dcols HyDE had cached (2026-10-20): 4xa1 is nearer pry1 than 4xa9 is in 431 of
        459 dark ones and in 99 of 101 light ones. So a light background runs tone 95 -> 20 and a dark one
        20 -> 95; the other way round the GTK theme got dark text on a dark window."""
        for mode, first, last in (("light", "5F", "14"), ("dark", "14", "5F")):
            self.set_prefs(json.dumps({"theme.mode": mode}))
            kv = self.parse(self.mod.build(make_data())[1])
            # make_data() encodes family number and tone in the colour: tone 95 is 0x5f, tone 20 is 0x14
            for n in (1, 2, 3, 4):
                self.assertEqual(kv[f"dcol_{n}xa1"], f"{n:02X}{first}00", (mode, n))
                self.assertEqual(kv[f"dcol_{n}xa9"], f"{n:02X}{last}00", (mode, n))

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
        self.wall = self.home / "wall.png"
        self.wall.write_bytes(b"x")
        self.mod.WALL.symlink_to(self.wall)
        self.lib = self.home / ".local/lib/hyde"

    def run_main(self, *argv, returncodes=None, dconf=None):
        """Runs main() with subprocess.run mocked. `returncodes` maps a script name to its exit status (default 0);
        `dconf` is the value `dconf read` prints, or None for a machine without dconf."""
        out = io.StringIO()

        def fake(cmd, **kwargs):
            result = mock.Mock(returncode=(returncodes or {}).get(pathlib.Path(cmd[1]).name if cmd[0] == "bash" else "", 0))
            result.stdout = (dconf or "") + "\n" if cmd[:2] == ["dconf", "read"] else ""
            return result

        with mock.patch("sys.argv", ["wallbash-matugen", *argv]), contextlib.redirect_stdout(out), \
                mock.patch.object(self.mod.subprocess, "run", side_effect=fake) as run, \
                mock.patch.object(self.mod.shutil, "which", return_value="/usr/bin/dconf" if dconf is not None else None):
            code = self.mod.main()
        return code, out.getvalue(), run

    def script(self, name):
        path = self.lib / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n")
        return path

    def test_dry_run_changes_nothing(self):
        code, out, run = self.run_main("--dry")
        self.assertEqual(code, 0)
        self.assertIn("dcol_mode=", out)
        self.assertEqual(self.real.read_text(), "old")
        run.assert_not_called()

    @staticmethod
    def rebuilds(run):
        """The calls that rebuild HyDE's templates (the icon theme refresh is another subprocess)."""
        return [c for c in run.call_args_list if c.args[0][0] == "bash"]

    def test_writes_through_the_symlink_and_is_idempotent(self):
        code, out, _ = self.run_main()
        self.assertEqual(code, 0)
        self.assertTrue(self.mod.DCOL_LINK.is_symlink())
        self.assertIn('dcol_mode="dark"', self.real.read_text())
        self.assertIn("wrote dark palette", out)
        before = self.real.stat().st_mtime_ns
        code, out, run = self.run_main()
        self.assertIn("already matches", out)
        self.assertEqual(self.rebuilds(run), [])  # nothing to rebuild, so no loop with the file watcher
        self.assertEqual(self.real.stat().st_mtime_ns, before)

    def test_rebuilds_with_color_set_given_the_wallpaper(self):
        colour_set = self.script("color.set.sh")
        self.script("theme.switch.sh")
        _, out, run = self.run_main()
        calls = self.rebuilds(run)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0], ["bash", str(colour_set), str(self.wall)])
        self.assertIn("color.set.sh", out)

    def test_falls_back_to_theme_switch_without_color_set(self):
        switch = self.script("theme.switch.sh")
        _, out, run = self.run_main()
        self.assertEqual([c.args[0] for c in self.rebuilds(run)], [["bash", str(switch)]])
        self.assertIn("theme.switch.sh", out)

    def test_falls_back_to_theme_switch_when_color_set_fails(self):
        self.script("color.set.sh")
        switch = self.script("theme.switch.sh")
        _, _, run = self.run_main(returncodes={"color.set.sh": 1})
        self.assertEqual([c.args[0][1] for c in self.rebuilds(run)], [str(self.lib / "color.set.sh"), str(switch)])

    def test_icon_theme_is_refreshed_before_the_rebuild(self):
        self.script("color.set.sh")
        _, _, run = self.run_main()
        self.assertEqual([c.args[0][0] for c in run.call_args_list][:2], ["matugen-icons", "bash"])

    def test_open_gtk_apps_are_told_to_reload_after_a_color_set_rebuild(self):
        self.script("color.set.sh")
        _, _, run = self.run_main(dconf="'Wallbash-Gtk'")
        dconf = [c.args[0] for c in run.call_args_list if c.args[0][0] == "dconf"]
        gtk = "/org/gnome/desktop/interface/gtk-theme"
        self.assertIn(["dconf", "write", gtk, "'Adwaita'"], dconf)
        self.assertEqual(dconf[dconf.index(["dconf", "write", gtk, "'Adwaita'"]) + 1], ["dconf", "write", gtk, "'Wallbash-Gtk'"])

    def test_no_dconf_no_reload(self):
        self.script("color.set.sh")
        _, _, run = self.run_main(dconf=None)
        self.assertEqual([c for c in run.call_args_list if c.args[0][0] == "dconf"], [])

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
