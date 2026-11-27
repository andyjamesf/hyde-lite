"""Bar control-centre tab order, launcher mode, and KDE Connect routing."""
import unittest
from pathlib import Path

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"


class Tabs(unittest.TestCase):
    def test_calculator_has_its_own_tab_and_existing_keybinding_route(self):
        center = (QS / "bar/modules/controlcenter/ControlCenter.qml").read_text()
        state = (QS / "bar/services/ShellState.qml").read_text()
        shell = (QS / "bar/Shell.qml").read_text()
        self.assertIn('"home", "apps", "calc", "clipboard"', center)
        self.assertIn('id: "calc"', center)
        self.assertIn('calc: "calc"', state)
        self.assertIn("id: calculatorTab", center)
        self.assertRegex(center, r"calc:\s*calculatorTab")
        self.assertIn('ShellState.toggleLauncher("calc")', shell)
        launcher = (QS / "bar/modules/launcher/LauncherView.qml").read_text()
        block = launcher[launcher.index("onModeChanged:"):]
        block = block[:block.index("\n        }")]
        self.assertIn("query = \"\";", block)
        self.assertIn("focusTimer.restart()", launcher[launcher.index("onModeChanged:"):])

    def test_kde_connect_is_after_localsend_and_optional_in_cycle_and_strip(self):
        center = (QS / "bar/modules/controlcenter/ControlCenter.qml").read_text()
        state = (QS / "bar/services/ShellState.qml").read_text()
        self.assertIn('.concat(KdeConnect.installed ? ["kdeConnect"] : [])', center)
        self.assertIn('label: "KDE Connect"', center)
        item = center[center.index('label: "LocalSend"'):]
        self.assertIn('...(KdeConnect.installed ? [{', item)
        self.assertLess(item.index('label: "LocalSend"'), item.index('...(KdeConnect.installed ? [{'))
        self.assertIn('kdeconnect: {\n                tab: "kdeConnect"', state)
        self.assertIn('kdeConnect: kdeConnectTab', center)

    def test_kde_connect_wide_uses_shared_actions_and_plain_device_names(self):
        wide = (QS / "bar/modules/controls/KdeConnectWide.qml").read_text()
        for action in ("ring", "ping", "sendClipboard", "browseFile"):
            self.assertIn(f"KdeConnect.{action}", wide)
        self.assertIn('"controlCenter"', wide)
        self.assertIn("textFormat: Text.PlainText", wide)
        self.assertIn("KdeConnect.lastError", wide)

    def test_picker_returns_to_control_centre_tab(self):
        shell = (QS / "bar/Shell.qml").read_text()
        self.assertIn('KdeConnect.pickSource === "controlCenter"', shell)
        self.assertIn('ShellState.openControlCenter("", "kdeConnect")', shell)


if __name__ == "__main__":
    unittest.main()
