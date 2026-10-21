"""services/Updates.qml, the part that reads `hyde-lite update --check` for the Settings screen's "hyde-lite" row
(parseHydeLite, run in Node from the QML source), and components/SettingsView.qml, whose keyboard rows are
numbered by hand: each row's number must be its place in the `rows` list. Run:

    python3 -I tools/tests/test_hyde_lite_check.py
"""
import json
import re
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

ISLAND = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/island"
UPDATES = (ISLAND / "services/Updates.qml").read_text()
VIEW = (ISLAND / "components/SettingsView.qml").read_text()


def parse(out):
    js = f"{qml_js.extract_function(UPDATES, 'parseHydeLite')}\nconsole.log(JSON.stringify(parseHydeLite({json.dumps(out)})));"
    return qml_js.run_node(js)


@unittest.skipUnless(shutil.which("node"), "node not installed")
class ParseCheck(unittest.TestCase):
    def test_up_to_date(self):
        r = parse("hyde-lite is up to date (b42fd227)\n::0\n")
        self.assertEqual((r["state"], r["summary"]), ("current", "Up to date (b42fd227)"))

    def test_new_commits_are_counted_and_the_list_is_not_the_summary(self):
        out = "3 new commit(s) on origin/main:\n  abc123 one\n  def456 two\n  789abc three\nrun: hyde-lite update\n::0\n"
        r = parse(out)
        self.assertEqual((r["state"], r["summary"]), ("available", "3 new commits"))
        self.assertEqual(parse("1 new commit(s) on origin/main:\n  abc one\nrun: hyde-lite update\n::0\n")["summary"], "1 new commit")

    def test_a_current_checkout_whose_install_did_not_finish(self):
        r = parse("the checkout is current but the last install did not finish; run: hyde-lite update\n::0\n")
        self.assertEqual((r["state"], r["summary"]), ("unfinished", "The last install did not finish"))

    def test_a_refusal_shows_its_reason_without_the_program_name(self):
        r = parse("hyde-lite: /home/u/hyde-lite has changes of its own; commit or stash them first\n::1\n")
        self.assertEqual(r["state"], "failed")
        self.assertEqual(r["summary"], "/home/u/hyde-lite has changes of its own; commit or stash them first")

    def test_a_missing_command_and_a_timeout(self):
        r = parse("hyde-lite: the hyde-lite command is not installed (run ./install.sh)\n::127\n")
        self.assertEqual((r["state"], r["summary"]), ("failed", "the hyde-lite command is not installed (run ./install.sh)"))
        self.assertEqual(parse("::124\n")["state"], "failed")                       # timeout: no output at all

    def test_garbage_and_silence_are_unknown_not_a_crash(self):
        self.assertEqual(parse("")["state"], "failed")                             # no "::code" line: treated as failed
        self.assertEqual(parse("something odd\n::0\n")["state"], "unknown")


class KeyboardRows(unittest.TestCase):
    def test_every_rows_number_is_its_place_in_the_list(self):
        rows = re.search(r"readonly property var rows: \[(.*?)\]", VIEW, re.S).group(1).replace("\n", " ").split(",")
        names = [r.strip() for r in rows]
        self.assertIn("updateRow", names)
        self.assertLess(names.index("updateRow"), names.index("resetRow"), "the reset button stays last")
        # each row block: `id: name` ... `root.current === N`
        for m in re.finditer(r"id: (\w+Row)\b.*?root\.current === (\d+)\s+onEntered: root\.current = (\d+)", VIEW, re.S):
            name, shown, entered = m.group(1), int(m.group(2)), int(m.group(3))
            if name in names:
                self.assertEqual(names.index(name), shown, f"{name}: the ring shows at {shown}, but it is item {names.index(name)}")
                self.assertEqual(shown, entered, f"{name}: the ring shows at {shown} but hovering sets {entered}")

    def test_the_screen_checks_for_hyde_lite_when_it_opens(self):
        self.assertIn("Updates.refreshHydeLite()", VIEW)


if __name__ == "__main__":
    unittest.main()
