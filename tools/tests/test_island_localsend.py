"""LocalSend in the island: the wiring that cannot be run here (mode, page, icon, click, file picker)."""
import re
import unittest
from pathlib import Path

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
MI = QS / "island"


def read(rel):
    path = MI / rel
    return path.read_text() if path.exists() else ""


class Wiring(unittest.TestCase):
    def test_the_mode_is_a_surface_and_a_control_centre_subview(self):
        state = read("core/IslandState.qml")
        self.assertIn('readonly property string localsend: "localsend"', state)
        for name in ("surfaces", "subviews"):
            self.assertRegex(state, rf"property var {name}: \[[^\]]*\blocalsend\b")

    def test_the_control_centre_loads_the_page_and_measures_it(self):
        view = read("components/ControlCenterView.qml")
        self.assertIn("readonly property string name: IslandState.localsend", view)
        self.assertIn("sourceComponent: CcLocalSendPage {", view)
        self.assertRegex(view, r"const loaders = \[[^\]]*\blocalSendPage\b")

    def test_the_icon_is_drawn_clickable_and_on_by_default(self):
        self.assertRegex(read("components/StatusZone.qml"), r"\blocalsend: localSendIcon\b")
        shortcuts = read("services/Shortcuts.qml")
        self.assertIn('case "localsend":', shortcuts)
        self.assertIn("IslandController.open(IslandState.localsend)", shortcuts)
        self.assertIn('"localsend"', read("config/StatusPillConfig.qml"))
        self.assertRegex(read("config/Expanded.qml"), r'statusIcons: \[[^\]]*"localsend"')
        self.assertIn('{ id: "localsend", label: "LocalSend" }', read("config/SettingsScreen.qml"))


class Page(unittest.TestCase):
    def test_a_pending_request_can_get_all_three_answers(self):
        page = read("components/CcLocalSendPage.qml")
        for decision in ("accept", "accept_and_pair", "decline"):
            self.assertIn(f'"{decision}"', page)
        self.assertIn("LocalSend.answer(", page)

    def test_the_picked_path_is_taken_on_load_and_while_open(self):
        page = read("components/CcLocalSendPage.qml")
        self.assertIn('LocalSend.browseFile("island")', page)
        self.assertIn("Component.onCompleted: showPicked()", page)
        self.assertRegex(page, r"function onPickedPathChanged\(\)")

    def test_a_missing_binary_can_be_retried(self):
        page = read("components/CcLocalSendPage.qml")
        self.assertIn("LocalSend.installError", page)
        self.assertIn("LocalSend.restart()", page)

    def test_the_shell_reopens_the_page_without_toggling_it_closed(self):
        shell = read("Shell.qml")
        block = re.search(r"function onFilePicked\(path\) \{.*?\n        \}", shell, re.S)
        body = block.group(0) if block else ""
        self.assertIn('LocalSend.pickSource === "island"', body)
        self.assertIn("IslandController.mode !== IslandState.localsend", body)
        self.assertIn("IslandController.open(IslandState.localsend)", body)


if __name__ == "__main__":
    unittest.main()
