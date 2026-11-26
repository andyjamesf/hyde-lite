"""The file picked for LocalSend must reach the path field of whichever panel shows next.

The control centre and its tabs stay created while closed, so a field that only reads the path when it is
created never shows a file picked later. Every field has to follow the service's `pickedPath`, and none may
clear it on reading: a hidden one would take it from the one on screen.
"""
import re
import unittest
from pathlib import Path

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
FIELDS = ("bar/modules/controls/LocalSendPanel.qml", "bar/modules/controls/LocalSendWide.qml",
          "island/components/CcLocalSendPage.qml")
SERVICE = (QS / "shared/services/LocalSend.qml").read_text()


def function(name):
    found = re.search(rf"    function {name}\(.*?\n    \}}\n", SERVICE, re.S)
    return found.group(0) if found else ""


class Fields(unittest.TestCase):
    def test_each_field_follows_a_path_picked_after_it_was_created(self):
        for rel in FIELDS:
            with self.subTest(rel):
                self.assertRegex((QS / rel).read_text(), r"function onPickedPathChanged\(\)")

    def test_each_field_also_reads_a_path_picked_before_it_was_created(self):
        for rel in FIELDS:
            with self.subTest(rel):
                self.assertRegex((QS / rel).read_text(), r"Component\.onCompleted:[^\n]*(showPicked\(\)|\{)")

    def test_no_field_clears_the_path_by_reading_it(self):
        for rel in FIELDS:
            with self.subTest(rel):
                self.assertNotRegex((QS / rel).read_text(), r'LocalSend\.pickedPath = ""')


class Service(unittest.TestCase):
    def test_a_new_pick_starts_empty_so_the_same_file_counts_as_a_change(self):
        self.assertIn('pickedPath = "";', function("browseFile"))

    def test_sending_clears_the_path_after_marking_the_send_as_busy(self):
        body = function("sendFiles")
        self.assertIn('root.pickedPath = "";', body)
        self.assertLess(body.index("root.sendBusy = true"), body.index('root.pickedPath = ""'))


if __name__ == "__main__":
    unittest.main()
