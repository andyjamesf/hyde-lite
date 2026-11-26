"""Sending needs the port the background receiver holds (53317, the one other devices and the firewall know),
so the receiver stops while a file is sent and comes back afterwards. Seen for real: with both running, `send`
exits at once with "Address already in use"."""
import re
import unittest
from pathlib import Path

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
SERVICE = (QS / "shared/services/LocalSend.qml").read_text()


def block(start):
    """The block that opens on the line starting with `start`, up to the closing brace at the same indent."""
    found = re.search(rf"^( *){re.escape(start)}.*?\n\1\}}", SERVICE, re.S | re.M)
    return found.group(0) if found else ""


def item(ident):
    found = re.search(rf"^    (?:Process|Timer) \{{\n        id: {ident}\n.*?\n    \}}", SERVICE, re.S | re.M)
    return found.group(0) if found else ""


class Pause(unittest.TestCase):
    def test_a_running_receiver_is_stopped_before_the_send_starts(self):
        body = block("function sendFiles(")
        self.assertRegex(body, r"if \(proc\.running\)\s+proc\.running = false;\s+else\s+sendProc\.running = true;")

    def test_the_send_starts_once_the_receiver_has_exited_and_nothing_restarts_it_meanwhile(self):
        receiver = item("proc")
        self.assertRegex(receiver, r"if \(root\.sendBusy\) \{[^}]*sendProc\.running = true;")
        self.assertIn("!root.sendBusy", item("restartTimer"))
        self.assertRegex(block("function restart("), r"if \((root\.)?sendBusy\)\s+return;")

    def test_the_receiver_comes_back_when_the_send_ends(self):
        self.assertIn("proc.running = true", item("sendProc"))

    def test_the_failure_shows_what_the_command_said(self):
        sender = item("sendProc")
        self.assertIn("stderr: SplitParser", sender)
        self.assertRegex(sender, r"lastSendError = root\._sendStderr")


class Screens(unittest.TestCase):
    def test_the_island_keeps_the_send_row_while_the_receiver_is_paused(self):
        page = (QS / "island/components/CcLocalSendPage.qml").read_text()
        self.assertNotRegex(page, r"visible: LocalSend\.ready\n")


if __name__ == "__main__":
    unittest.main()
