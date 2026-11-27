"""The polished Thunar: its colours, stylesheet and installer step (tools/thunar.sh). Run:

    python3 -I tools/tests/test_thunar.py
"""
import os
import pathlib
import re
import subprocess
import tempfile
import tomllib
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = REPO / "Configs/.config/matugen/templates/gtk.css"
STYLE = REPO / "Configs/.config/gtk-3.0/thunar.css"
MATUGEN = REPO / "Configs/.config/matugen/config.toml"
DOTS = REPO / "Scripts/dots/thunar.toml"
# names the patched Thunar looks up from C
FROM_PATCH = {"m3_primary_container", "m3_outline"}


def without_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


class Colours(unittest.TestCase):
    def test_every_m3_name_used_is_defined(self):
        used = set(re.findall(r"@(m3_[a-z_]+)", without_comments(STYLE.read_text()))) | FROM_PATCH
        defined = set(re.findall(r"@define-color (m3_[a-z_]+) \{\{colors\.[a-z_]+\.default\.hex\}\};", TEMPLATE.read_text()))
        self.assertEqual(used - defined, set())
        self.assertEqual(len(defined), 15)

    def test_stylesheet_has_no_literal_colour(self):
        self.assertEqual(re.findall(r"#[0-9a-fA-F]{3,8}\b|\brgba?\(", without_comments(STYLE.read_text())), [])

    def test_stylesheet_is_deployed_by_exactly_one_dot(self):
        # deez refuses to deploy a file another dot already owns, and the whole step fails
        owners = []
        for dot in (REPO / "Scripts/dots").glob("*.toml"):
            for name, section in tomllib.loads(dot.read_text()).items():
                for e in section.get("files", []) if isinstance(section, dict) else []:
                    paths = [e["paths"]] if isinstance(e.get("paths"), str) else e.get("paths", [])
                    for path in paths:
                        full = os.path.join(e.get("source_root", ""), path)
                        target = "Configs/.config/gtk-3.0/thunar.css"
                        ignored = any(os.path.join(e.get("source_root", ""), i) == target for i in e.get("ignored_paths", []))
                        if not ignored and (target == full or target.startswith(full + "/")):
                            owners.append(f"{dot.name}:{name}")
        self.assertEqual(owners, ["hyde.toml:hyde"])

    def test_the_import_hook_needs_no_shell_specific_escapes(self):
        # printf keeps the backslash of \" in dash (Ubuntu's sh, and CI's)
        hook = tomllib.loads(MATUGEN.read_text())["templates"]["gtk3"]["post_hook"]
        self.assertNotIn('\\"', hook)

    def test_gtk3_hook_imports_each_file_once_and_wallpaper_first(self):
        hook = tomllib.loads(MATUGEN.read_text())["templates"]["gtk3"]["post_hook"]
        for before in (None, '@import url("wallpaper.css");\n', '@import url("thunar.css");\n'):
            with self.subTest(before=before), tempfile.TemporaryDirectory() as home:
                css = pathlib.Path(home, ".config/gtk-3.0/gtk.css")
                css.parent.mkdir(parents=True)
                if before:
                    css.write_text(before)
                for _ in range(2):
                    subprocess.run(["sh", "-c", hook], env={**os.environ, "HOME": home}, check=True)
                text = css.read_text()
                self.assertEqual(text.count('@import url("wallpaper.css");'), 1)
                self.assertEqual(text.count('@import url("thunar.css");'), 1)
                if before != '@import url("thunar.css");\n':
                    self.assertLess(text.index("wallpaper.css"), text.index("thunar.css"))

SCRIPT = REPO / "tools/thunar.sh"
VERSION = "4.20.10-1"
DEFAULTS = {"/last-separator-position": ("int", "210"),
            "/shortcuts-icon-size": ("string", "THUNAR_ICON_SIZE_16"),
            "/misc-symbolic-icons-in-sidepane": ("bool", "true"),
            "/last-menubar-visible": ("bool", "false"),
            "/last-statusbar-visible": ("bool", "false")}
FAKES = {
    "pacman": """echo "pacman $*" >>"$LOG"
case "$1 $2" in
    "-Q thunar-hyde-lite") [[ -n ${FAKE_INSTALLED:-} ]] && echo "thunar-hyde-lite $FAKE_INSTALLED" ;;
    "-Q thunar") [[ -n ${FAKE_THUNAR:-} ]] ;;
    *) true ;;
esac""",
    "makepkg": """echo "makepkg $*" >>"$LOG"
[[ -z ${FAKE_BUILD_FAIL:-} ]] || exit 4
[[ -f PKGBUILD && -f thunar-hyde-lite.patch ]] || exit 5
touch "$PKGDEST/thunar-hyde-lite-4.20.10-1-x86_64.pkg.tar.zst"
""",
    "sudo": 'echo "sudo $*" >>"$LOG"; exec "$@"',
    "xfconf-query": """echo "xfconf-query $*" >>"$LOG"
[[ -z ${FAKE_XFCONF_FAIL:-} || "$*" != *"$FAKE_XFCONF_FAIL"* ]]""",
    "wallpaper-palette": """echo "wallpaper-palette $*" >>"$LOG"
[[ -z ${FAKE_PALETTE_FAIL:-} ]]""",
    "dbus-run-session": """echo "dbus-run-session" >>"$LOG"
shift
DBUS_SESSION_BUS_ADDRESS=private exec "$@"
""",
}


class Step(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = pathlib.Path(tmp.name)
        (self.tmp / "bin").mkdir()
        for name, body in FAKES.items():
            fake = self.tmp / "bin" / name
            fake.write_text("#!/usr/bin/env bash\n" + body + "\n")
            fake.chmod(0o755)
        self.log = self.tmp / "log"
        self.marker = self.tmp / "state/hyde-lite/thunar-defaults.applied"

    def run_step(self, **env):
        self.log.write_text("")
        base = {"PATH": f"{self.tmp / 'bin'}:/usr/bin:/bin", "HOME": str(self.tmp), "LOG": str(self.log),
                "XDG_STATE_HOME": str(self.tmp / "state"), "XDG_CACHE_HOME": str(self.tmp / "cache"),
                "DBUS_SESSION_BUS_ADDRESS": "session", "FAKE_THUNAR": "1"}
        merged = {k: v for k, v in {**base, **env}.items() if v is not None}
        r = subprocess.run(["bash", str(SCRIPT)], env=merged, capture_output=True, text=True, timeout=60)
        return r, self.log.read_text().splitlines()

    def installs(self, calls):
        return [c for c in calls if c.startswith("pacman -U")]

    def test_builds_and_installs_when_missing(self):
        r, calls = self.run_step()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.installs(calls)), 1)
        self.assertRegex(self.installs(calls)[0], r"^pacman -U --noconfirm --ask 4 \S+thunar-hyde-lite-4\.20\.10-1-x86_64\.pkg\.tar\.zst$")
        self.assertFalse((self.tmp / "cache/hyde-lite/thunar-build").exists())

    def test_same_version_does_nothing(self):
        r, calls = self.run_step(FAKE_INSTALLED=VERSION)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertFalse([c for c in calls if c.startswith(("makepkg", "sudo"))])

    def test_a_newer_recipe_rebuilds(self):
        _, calls = self.run_step(FAKE_INSTALLED="4.20.9-1")
        self.assertEqual(len(self.installs(calls)), 1)

    def test_failed_build_keeps_a_file_manager_and_reports_an_error(self):
        r, calls = self.run_step(FAKE_BUILD_FAIL="1", FAKE_THUNAR=None)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("[err]", r.stdout)
        self.assertIn("pacman -S --needed --noconfirm thunar", calls)
        self.assertEqual(self.installs(calls), [])
        self.assertTrue(self.marker.exists(), "the defaults apply to the official Thunar too")

    def test_failed_build_leaves_an_installed_thunar_alone(self):
        _, calls = self.run_step(FAKE_BUILD_FAIL="1")
        self.assertFalse([c for c in calls if c.startswith("pacman -S")])

    def test_dry_run_changes_nothing(self):
        r, calls = self.run_step(flg_DryRun="1")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertFalse([c for c in calls if c.startswith(("makepkg", "sudo", "xfconf-query"))])
        self.assertFalse(self.marker.exists())

    def test_defaults_are_applied_once(self):
        _, calls = self.run_step(FAKE_INSTALLED=VERSION)
        expected = {f"xfconf-query -c thunar -p {p} -n -t {t} -s {v}" for p, (t, v) in DEFAULTS.items()}
        self.assertEqual({c for c in calls if c.startswith("xfconf-query")}, expected)
        _, calls = self.run_step(FAKE_INSTALLED=VERSION)
        self.assertFalse([c for c in calls if c.startswith("xfconf-query")])

    def test_a_failed_default_leaves_no_marker(self):
        r, _ = self.run_step(FAKE_INSTALLED=VERSION, FAKE_XFCONF_FAIL="shortcuts-icon-size")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("[err]", r.stdout)
        self.assertFalse(self.marker.exists())

    def test_without_a_session_bus_one_private_bus_serves_every_default(self):
        r, calls = self.run_step(FAKE_INSTALLED=VERSION, DBUS_SESSION_BUS_ADDRESS=None)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(calls.count("dbus-run-session"), 1)
        self.assertEqual(len([c for c in calls if c.startswith("xfconf-query")]), len(DEFAULTS))
        self.assertTrue(self.marker.exists())

    def gtk_files(self, imports, colours):
        gtk = self.tmp / ".config/gtk-3.0"
        gtk.mkdir(parents=True)
        (gtk / "gtk.css").write_text(imports)
        (gtk / "wallpaper.css").write_text(colours)

    def test_an_existing_machine_gets_its_colours_rendered_again(self):
        # wallpaper-palette skips a run for the same wallpaper, so a new template alone changes nothing
        self.gtk_files('@import url("wallpaper.css");\n', "")
        _, calls = self.run_step(FAKE_INSTALLED=VERSION)
        self.assertIn("wallpaper-palette apply --force", calls)

    def test_colours_already_in_place_are_left_alone(self):
        self.gtk_files('@import url("wallpaper.css");\n@import url("thunar.css");\n',
                       "@define-color m3_primary_container #000000;\n")
        _, calls = self.run_step(FAKE_INSTALLED=VERSION)
        self.assertFalse([c for c in calls if c.startswith("wallpaper-palette")])

    def test_no_wallpaper_yet_does_not_fail_the_step(self):
        r, _ = self.run_step(FAKE_INSTALLED=VERSION, FAKE_PALETTE_FAIL="1")
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertNotIn("[err]", r.stdout)

    def test_dry_run_renders_nothing(self):
        _, calls = self.run_step(flg_DryRun="1")
        self.assertFalse([c for c in calls if c.startswith("wallpaper-palette")])

    def test_install_sh_runs_the_step(self):
        self.assertIn('run_step "Thunar" "$root/tools/thunar.sh"', (REPO / "install.sh").read_text())


if __name__ == "__main__":
    unittest.main()
