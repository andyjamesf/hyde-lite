"""Both shells must offer the same control centre.

The control centre cannot be photographed: it closes as soon as a scripted IPC call returns, in
either shell. So what each one draws is compared through the ccItems() diagnostic
(qs ipc call bar-debug ccItems / island-debug ccItems), and the source of both is checked here so
a tile or a button cannot be added to one and forgotten in the other.
"""
import pathlib
import re
import unittest

SHELL = pathlib.Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"


def ids_of(path, prop):
    """The ids listed in a QML array property, e.g. `tiles: ["wifi", …]`."""
    text = (SHELL / path).read_text(encoding="utf-8")
    m = re.search(r"property var %s: \[(.*?)\]" % prop, text, re.S)
    assert m, "%s has no %s" % (path, prop)
    return re.findall(r'"([^"]+)"', m.group(1))


def model_ids(name):
    """The ids the shared model lists, in order."""
    text = (SHELL / ("shared/controlcenter/%s.qml" % name)).read_text(encoding="utf-8")
    body = text[text.index("property var items:"):text.index("readonly property var shown")]
    return re.findall(r'\n            id: "([^"]+)"', body)


class ControlCentreParity(unittest.TestCase):
    def test_island_draws_every_shared_toggle(self):
        """The island's own order must name every toggle, or it silently drops one."""
        self.assertEqual(sorted(ids_of("island/config/ControlCenter.qml", "tiles")),
                         sorted(model_ids("CcToggles")))

    def test_island_draws_every_shared_shortcut(self):
        self.assertEqual(sorted(ids_of("island/config/ControlCenter.qml", "shortcuts")),
                         sorted(model_ids("CcShortcuts")))

    def test_every_toggle_has_an_icon_in_the_shared_tile(self):
        """The tile is drawn once (CcToggleTile), so each id in the shared list needs its icon there."""
        text = (SHELL / "shared/controlcenter/CcToggleTile.qml").read_text(encoding="utf-8")
        mapped = re.findall(r"\n                (\w+): \w+Icon,?", text)
        self.assertEqual(sorted(mapped), sorted(model_ids("CcToggles")))

    def test_both_shells_answer_what_the_model_asks(self):
        """A signal the model emits with nobody listening is a dead button."""
        for shell in ("bar", "island"):
            text = (SHELL / ("%s/Shell.qml" % shell)).read_text(encoding="utf-8")
            for fn in ("onColorSourceToggleRequested", "onOpenRequested"):
                self.assertIn(fn, text, "%s/Shell.qml does not answer %s" % (shell, fn))

    def test_both_shells_draw_the_one_main_page(self):
        """The island's main page is the complete one; the bar draws the same component (the minimal bar
        draws the bar's panels), and neither keeps tiles, sliders or a notification list of its own."""
        for path in ("island/components/CcMainPage.qml", "bar/modules/controlcenter/ControlCenter.qml"):
            text = (SHELL / path).read_text(encoding="utf-8")
            self.assertIn("CcMainView {", text, "%s does not draw the shared main page" % path)
            for own in ("Notifications.list", "BigSlider {", "CcTile {"):
                self.assertNotIn(own, text, "%s keeps its own %s" % (path, own))
        view = (SHELL / "shared/controlcenter/CcMainView.qml").read_text(encoding="utf-8")
        self.assertIn("NotificationCentre {", view)

    def test_the_diagnostic_exists_in_both(self):
        """It is how the two are compared; losing it loses the only check there is."""
        for shell in ("bar", "island"):
            text = (SHELL / ("%s/Shell.qml" % shell)).read_text(encoding="utf-8")
            self.assertIn("function ccItems()", text)


if __name__ == "__main__":
    unittest.main()
