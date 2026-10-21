"""Island Settings: the icon-list editor's list edits (run in Node) and its id lists against the QML that draws them."""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

MI = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/island"
EDITOR = (MI / "components/IconListEditor.qml").read_text()
SCREEN = (MI / "config/SettingsScreen.qml").read_text()
ZONE = (MI / "components/StatusZone.qml").read_text()


def choice_ids(name):
    block = re.search(rf"property var {name}: \[(.*?)\n    \]", SCREEN, re.S).group(1)
    return re.findall(r'id: "([a-z]+)"', block)


def default_list(path, prop):
    m = re.search(rf"property var {prop}: Prefs\.get\(\"[\w.]+\", (\[.*?\])\)", (MI / path).read_text())
    return json.loads(m.group(1))


def run_edits(calls):
    fns = "\n".join(re.sub(r"^    ", "", m.group(0), flags=re.M)
                    for m in re.finditer(r"    function (?:movedItem|removedItem|addedItem)\(.*?\n    \}\n", EDITOR, re.S))
    js = f"{fns}\nconst c = {json.dumps(calls)};\nconsole.log(JSON.stringify(c.map(([f, ...a]) => ({{movedItem, removedItem, addedItem}})[f](...a))));"
    return json.loads(subprocess.run(["node", "-e", js], capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "node not installed")
class ListEdits(unittest.TestCase):
    def test_moved(self):
        got = run_edits([["movedItem", ["a", "b", "c"], 0, 1], ["movedItem", ["a", "b", "c"], 2, -1],
                         ["movedItem", ["a", "b", "c"], 0, -1], ["movedItem", ["a", "b", "c"], 2, 1],
                         ["movedItem", ["a", "b", "c"], -1, 1]])
        self.assertEqual(got, [["b", "a", "c"], ["a", "c", "b"], ["a", "b", "c"], ["a", "b", "c"], ["a", "b", "c"]])

    def test_removed_and_added(self):
        got = run_edits([["removedItem", ["a", "b", "c"], 1], ["removedItem", ["a"], 0], ["removedItem", ["a"], 5],
                         ["addedItem", ["a"], "b"], ["addedItem", ["a"], "a"], ["addedItem", [], "x"]])
        self.assertEqual(got, [["a", "c"], [], ["a"], ["a", "b"], ["a"], ["x"]])


class Ids(unittest.TestCase):
    def test_status_choices_are_exactly_the_icons_statuszone_draws(self):
        drawn = re.findall(r"^\s+(\w+): \w+Icon,?$", re.search(r"iconComponents: \(\{(.*?)\}\)", ZONE, re.S).group(1), re.M)
        self.assertEqual(sorted(choice_ids("statusIconChoices")), sorted(drawn))

    def test_shortcut_choices_are_the_buttons_statuszone_handles(self):
        glyphs = re.findall(r"^\s+(\w+): \"\\u", re.search(r"extraGlyphs: \(\{(.*?)\}\)", ZONE, re.S).group(1), re.M)
        handled = set(glyphs) | {"nightlight", "power", "lock"}
        self.assertEqual(set(choice_ids("shortcutChoices")), handled)

    def test_default_lists_only_use_offered_ids(self):
        status = default_list("config/StatusPillConfig.qml", "icons")
        # "vpn" has been in the default list without anything drawing it; StatusZone skips it.
        self.assertEqual([i for i in status if i not in choice_ids("statusIconChoices")], ["vpn"])
        self.assertEqual([i for i in default_list("config/Expanded.qml", "extraButtons") if i not in choice_ids("shortcutChoices")], [])

    def test_settings_rows_and_ring_indices_agree(self):
        view = (MI / "components/SettingsView.qml").read_text()
        rows = re.search(r"readonly property var rows: \[(.*?)\]", view).group(1).split(",")
        ring = [int(n) for n in re.findall(r"root\.current === (\d+)", view)]
        self.assertEqual(sorted(set(ring)), list(range(len(rows))))


if __name__ == "__main__":
    unittest.main()
