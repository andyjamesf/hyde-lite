"""Island extra pills: the position arithmetic and the prefs rule (both run in Node from the QML source), and the
window wiring that cannot be run here (one slot and one mask region per allowed pill)."""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

MI = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/island"
PILLS = (MI / "config/PillsConfig.qml").read_text()
SCHEMA = (MI / "config/PrefsSchema.qml").read_text()
WINDOW = (MI / "core/IslandWindow.qml").read_text()


def node(js):
    return json.loads(subprocess.run(["node", "-e", js], capture_output=True, text=True, check=True).stdout)


def fn(src, name):
    m = re.search(rf"    function {name}\(.*?\n    \}}\n", src, re.S)
    return re.sub(r"^    ", "", m.group(0), flags=re.M)


def x_for(cases):
    js = f"{fn(PILLS, 'xFor')}\nconst c = {json.dumps(cases)};\nconsole.log(JSON.stringify(c.map(a => xFor(...a))));"
    return node(js)


def faults(values):
    keys = re.search(r"readonly property var keys: (\(\{.*?\n        \}\))", SCHEMA, re.S).group(1)
    js = f"const keys = {keys};\n{fn(SCHEMA, 'fault')}\nconsole.log(JSON.stringify({json.dumps(values)}.map(v => fault('pills.extra', v))));"
    return node(js)


def pill(side, *w):
    return {"side": side, "widgets": list(w or ["clock"])}


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Positions(unittest.TestCase):
    def test_left_pills_stack_rightwards_and_right_pills_leftwards(self):
        lst = [pill("left"), pill("left"), pill("right"), pill("right")]
        w = [100, 50, 80, 40]
        # args: list, widths, k, leftStart, rightStart, gap
        got = x_for([[lst, w, k, 200, 1800, 8] for k in range(4)])
        self.assertEqual(got, [200, 308, 1720, 1672])

    def test_a_pill_of_the_other_side_does_not_move_it(self):
        lst = [pill("right"), pill("left"), pill("right")]
        w = [60, 70, 90]
        self.assertEqual(x_for([[lst, w, 1, 100, 1000, 10], [lst, w, 2, 100, 1000, 10]]), [100, 1000 - 60 - 10 - 90])

    def test_single_pills(self):
        self.assertEqual(x_for([[[pill("left")], [120], 0, 12, 1900, 8], [[pill("right")], [120], 0, 12, 1900, 8]]),
                         [12, 1780])


def edits(calls):
    """calls: [[name, args...]] -> results of PillsConfig's pure list edits, run in Node."""
    names = ("withPill", "withoutPill", "withSide", "withWidgets")
    src = "\n".join(fn(PILLS, n) for n in names)
    max_pills = re.search(r"maxPills: (\d+)", PILLS).group(1)
    js = f"const maxPills = {max_pills};\n{src}\nconst f = {{{', '.join(names)}}};\nconst c = {json.dumps(calls)};\nconsole.log(JSON.stringify(c.map(([n, ...a]) => f[n](...a))));"
    return node(js)


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Edits(unittest.TestCase):
    def test_add_stops_at_the_maximum(self):
        four = [pill("left")] * 4
        got = edits([["withPill", [], "right"], ["withPill", [pill("left")], "right"], ["withPill", four, "right"]])
        self.assertEqual(got[0], [{"side": "right", "widgets": ["clock"]}])
        self.assertEqual(got[1], [pill("left"), {"side": "right", "widgets": ["clock"]}])
        self.assertEqual(got[2], four)

    def test_remove_side_and_widgets(self):
        lst = [pill("left", "a"), pill("right", "b", "c")]
        got = edits([["withoutPill", lst, 0], ["withSide", lst, 1, "left"], ["withWidgets", lst, 0, ["x", "y"]],
                     ["withWidgets", lst, 1, []]])
        self.assertEqual(got[0], [pill("right", "b", "c")])
        self.assertEqual(got[1], [pill("left", "a"), pill("left", "b", "c")])
        self.assertEqual(got[2], [pill("left", "x", "y"), pill("right", "b", "c")])
        self.assertEqual(got[3], [pill("left", "a")])  # emptying a pill removes it (an empty one is invalid)

    def test_edits_do_not_change_their_input(self):
        lst = [pill("left", "a")]
        edits([["withSide", lst, 0, "right"]])
        self.assertEqual(lst, [pill("left", "a")])

    def test_edited_lists_pass_the_schema_rule(self):
        lst = [pill("left", "a"), pill("right", "b")]
        out = edits([["withPill", lst, "left"], ["withSide", lst, 0, "right"], ["withWidgets", lst, 1, ["q"]]])
        self.assertEqual(faults(out), ["", "", ""])


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Rule(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(faults([[], [pill("left")], [pill("right", "clock", "media", "workspaces")],
                                 [pill("left")] * 4]), ["", "", "", ""])

    def test_invalid(self):
        bad = [{"side": "left"}, "x", 3, [3], [None], [[1]], [{"side": "top", "widgets": ["a"]}],
               [{"side": "left", "widgets": []}], [{"side": "left", "widgets": [""]}],
               [{"side": "left", "widgets": ["a", 2]}], [{"side": "left", "widgets": ["a"] * 13}],
               [pill("left")] * 5, [{"widgets": ["a"]}]]
        got = faults(bad)
        self.assertTrue(all(got), [b for b, g in zip(bad, got, strict=True) if not g])


class Wiring(unittest.TestCase):
    def test_max_pills_matches_the_schema_and_the_slots(self):
        n = int(re.search(r"maxPills: (\d+)", PILLS).group(1))
        self.assertIn(f"value.length > {n}", SCHEMA)
        self.assertEqual(len(re.findall(r"ExtraPill \{\s+id: extra\d", WINDOW)), n)

    def test_every_slot_has_a_mask_region_and_its_spec(self):
        for k in range(4):
            self.assertIn(f"item: extra{k}.active ? extra{k} : null", WINDOW)
            self.assertIn(f"spec: PillsConfig.extra[{k}] ?? null", WINDOW)
            self.assertIn(f"shownX: win.extraX({k})", WINDOW)
        self.assertIn("extraWidths: [extra0.targetWidth, extra1.targetWidth, extra2.targetWidth, extra3.targetWidth]", WINDOW)

    def test_extra_allowed_uses_the_clock_mode_name(self):
        self.assertIn('extraAllowed: displayMode === "clock"', WINDOW)
        state = (MI / "core/IslandState.qml").read_text()
        self.assertRegex(state, r'property string clock: "clock"')

    def test_settings_shows_the_pills_editor(self):
        view = (MI / "components/SettingsView.qml").read_text()
        self.assertIn("PillsEditor {", view)
        self.assertIn("pillsRow, updateRow, systemRow, resetRow]", view)

    def test_pill_widget_choices_are_the_status_ones_plus_workspaces(self):
        screen = (MI / "config/SettingsScreen.qml").read_text()
        self.assertRegex(screen, r'pillWidgetChoices: \[\{ id: "workspaces", label: "Workspaces" \}\]\.concat\(statusIconChoices\)')

    def test_pref_is_reset_by_defaults(self):
        self.assertIn('"pills.extra"', (MI / "config/SettingsScreen.qml").read_text())

    def test_widget_ids_the_docs_promise_exist_in_statuszone(self):
        zone = (MI / "components/StatusZone.qml").read_text()
        for i in ("clock", "date", "mic", "brightness", "media", "battery", "volume"):
            self.assertRegex(zone, rf"\b{i}: \w+Icon\b")


if __name__ == "__main__":
    unittest.main()
