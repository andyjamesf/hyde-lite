"""config/PrefsSchema.qml: run its fault() in Node against real keys, so the list type is exercised."""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

SCHEMA = Path(__file__).resolve().parents[2] / "Configs/.config/morphing-island/config/PrefsSchema.qml"


def faults(cases):
    """cases: [(key, value)] -> list of fault strings, from the QML's own code."""
    src = SCHEMA.read_text()
    keys = re.search(r"readonly property var keys: (\(\{.*?\n        \}\))", src, re.S).group(1)
    fn = re.search(r"    function fault\(key, value\) \{.*?\n    \}\n", src, re.S).group(0)
    js = f"const keys = {keys};\n{fn.replace('function fault', 'function fault', 1)}\n" \
         f"console.log(JSON.stringify({json.dumps(cases)}.map(([k, v]) => fault(k, v))));"
    js = js.replace("    function fault", "function fault", 1)
    out = subprocess.run(["node", "-e", js], capture_output=True, text=True, check=True).stdout
    return json.loads(out)


@unittest.skipUnless(shutil.which("node"), "node not installed")
class ListType(unittest.TestCase):
    def test_valid_lists(self):
        got = faults([["statusPill.icons", ["volume", "wifi"]], ["statusPill.icons", []],
                      ["expanded.extraButtons", ["lock"]], ["statusPill.icons", ["my-plugin"]]])
        self.assertEqual(got, ["", "", "", ""])

    def test_invalid_lists(self):
        got = faults([["statusPill.icons", "volume"], ["statusPill.icons", {"a": 1}], ["statusPill.icons", 3],
                      ["statusPill.icons", ["volume", ""]], ["statusPill.icons", ["volume", 4]],
                      ["expanded.extraButtons", [None]]])
        self.assertTrue(all(got), got)
        self.assertIn("position 1", got[3])
        self.assertIn("expected a list", got[0])

    def test_other_types_unchanged(self):
        got = faults([["pill.height", 36], ["pill.height", 300], ["pill.height", "36"], ["theme.mode", "dark"],
                      ["theme.mode", "dim"], ["pill.hidden", True], ["no.such.key", 1]])
        self.assertEqual([bool(g) for g in got], [False, True, True, False, True, False, False])

    def test_pill_options(self):
        got = faults([["pill.topMargin", 0], ["pill.topMargin", 24], ["pill.topMargin", 25], ["pill.topMargin", -1],
                      ["pill.topMargin", 3.5], ["clock.hour12", True], ["clock.hour12", "yes"],
                      ["statusPill.enabled", False], ["statusPill.nearClock", 1]])
        self.assertEqual([bool(g) for g in got], [False, False, True, True, True, False, True, False, True])

    def test_every_pref_the_config_reads_has_a_schema_entry(self):
        keys = set(re.findall(r'^\s+"([\w.]+)": \{', SCHEMA.read_text(), re.M))
        used = set()
        for p in (SCHEMA.parent).glob("*.qml"):
            used |= set(re.findall(r'Prefs\.get\("([\w.]+)"', p.read_text()))
        self.assertEqual(sorted(used - keys), [])

    def test_list_keys_are_reset_by_defaults(self):
        reset = (SCHEMA.parent / "SettingsScreen.qml").read_text()
        for k in ("statusPill.icons", "expanded.extraButtons"):
            self.assertIn(f'"{k}"', reset)


if __name__ == "__main__":
    unittest.main()
