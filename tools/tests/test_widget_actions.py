"""The widget hints and clicks in core/IslandController.qml run in Node with stand-ins for Audio, Media and Brightness, and the Shortcuts wiring."""
import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

MI = Path(__file__).resolve().parents[2] / "Configs/.config/morphing-island"
ACTIONS = (MI / "core/IslandController.qml").read_text()
SHORTCUTS = (MI / "services/Shortcuts.qml").read_text()


def fn(name):
    m = re.search(rf"    function {name}\(.*?\n    \}}\n", ACTIONS, re.S)
    return re.sub(r"^    ", "", m.group(0), flags=re.M)


def run(scenario):
    stubs = """const calls = [];
const Qt = { MiddleButton: 4 };
const Audio = { micMuted: false, micVolume: 0.5, toggleMicMute() { calls.push('mic'); } };
const Brightness = { percent: 40 };
const Media = { active: true, title: 'Song', artist: 'Band', next() { calls.push('next'); }, togglePlaying() { calls.push('toggle'); } };
"""
    js = f"{stubs}{fn('widgetHandlesClick')}\n{fn('widgetHint')}\n{fn('widgetClick')}\n{scenario}"
    return json.loads(subprocess.run(["node", "-e", js], capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Behaviour(unittest.TestCase):
    def test_hints(self):
        got = run("""const out = [widgetHint('mic'), widgetHint('brightness'), widgetHint('media'), widgetHint('nothing')];
Audio.micMuted = true; out.push(widgetHint('mic'));
Media.artist = ''; out.push(widgetHint('media'));
Media.active = false; out.push(widgetHint('media'));
console.log(JSON.stringify(out));""")
        self.assertEqual(got, ["Microphone: 50%", "Brightness: 40% (scroll to change)", "Song\nBand", "",
                               "Microphone: muted", "Song", "Nothing is playing"])

    def test_clicks(self):
        got = run("""widgetClick('mic', 1); widgetClick('media', 1); widgetClick('media', Qt.MiddleButton); widgetClick('brightness', 1);
console.log(JSON.stringify([calls, widgetHandlesClick('mic'), widgetHandlesClick('media'), widgetHandlesClick('brightness'), widgetHandlesClick('wifi')]));""")
        self.assertEqual(got, [["mic", "toggle", "next"], True, True, False, False])


class Wiring(unittest.TestCase):
    def test_shortcuts_delegates_instead_of_reading_the_services(self):
        self.assertIn("IslandController.widgetHint(id)", SHORTCUTS)
        self.assertIn("IslandController.widgetHandlesClick(id)", SHORTCUTS)
        self.assertIn("IslandController.widgetClick(id, button)", SHORTCUTS)
        for member in ("Audio.mic", "Media.title", "Media.next", "Brightness.percent"):
            self.assertNotIn(member, SHORTCUTS)

    def test_the_widgets_still_have_hints(self):
        for i in ("mic", "brightness", "media"):
            self.assertRegex(SHORTCUTS, rf'case "{i}":')


if __name__ == "__main__":
    unittest.main()
