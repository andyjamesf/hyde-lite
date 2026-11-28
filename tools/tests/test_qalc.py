"""qalc argv and output handling, using real qalc captures."""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
SRC = (QS / "shared/services/Qalc.qml").read_text()
PRELUDE = "\n".join(qml_js.extract_function(SRC, name) for name in ("prepare", "argsFor", "parse"))
DATA = Path(__file__).resolve().parent / "data/qalc"


def call(js):
    return qml_js.run_node(f"{PRELUDE}\nconsole.log(JSON.stringify({js}));")


class Qalc(unittest.TestCase):
    def fixture(self, name):
        return json.loads((DATA / f"{name}.json").read_text())

    def test_real_success_output_parses(self):
        f = self.fixture("1+1")
        self.assertEqual(call(f"parse({f['exit_code']}, {json.dumps(f['stdout'])}, {json.dumps(f['stderr'])})"), {"ok": True, "text": "2"})

    def test_decimal_comma_is_normalized_and_other_comma_calls_are_not(self):
        self.assertEqual(call('prepare("2,5*2")'), "2.5*2")
        self.assertEqual(call('prepare("max(1;2)")'), "max(1;2)")

    def test_qalc_filesystem_process_and_plot_functions_are_refused_case_insensitively(self):
        for name in ("command", "save", "store", "set", "mode", "exrates", "load", "plot", "export", "quit", "exit", "help", "history"):
            for spelling in (name, name.upper()):
                with self.subTest(name=spelling):
                    self.assertEqual(call(f"prepare({json.dumps(spelling + '(1)')})"), "")

    def test_normal_math_and_units_remain_available_and_qalc_stdout_errors_fail(self):
        for expression in ("1+1", "10 km to mile", "sin(90)", "max(1;2)", "factor(12)"):
            self.assertEqual(call(f"prepare({json.dumps(expression)})"), expression)
        self.assertEqual(call('parse(0, "error: failed to load file", "")'), {"ok": False, "text": "error: failed to load file"})

    def test_negative_expression_is_after_option_terminator(self):
        argv = call('argsFor("-5+2", "deg")')
        self.assertEqual(argv[-2:], ["--", "-5+2"])

    def test_required_samples_are_captured_with_real_process_metadata(self):
        for name in ("1+1", "sin90-deg", "sin90-rad", "decimal-comma", "10-km-to-mile", "solve-quadratic", "1-div-0", "foo-open", "tower", "negative"):
            with self.subTest(name=name):
                f = self.fixture(name)
                self.assertTrue(f["argv"][:3] == ["qalc", "-defaults", "-t"])
                self.assertIsInstance(f["exit_code"], int)
                self.assertIsInstance(f["elapsed_ms"], float)

    def test_installed_qalc_audit_captures_commands_functions_and_stdout_error(self):
        functions = json.loads((DATA / "list-functions.json").read_text())
        commands = json.loads((DATA / "interactive-help.json").read_text())
        error = json.loads((DATA / "interactive-load-error.json").read_text())
        self.assertEqual(functions["exit_code"], 0)
        self.assertIn("command", functions["stdout"].lower())
        self.assertIn("save/store", commands["stdout"])
        self.assertEqual(error["exit_code"], 0)
        self.assertIn("error:", error["stdout"].lower())
        self.assertEqual(error["stderr"], "")
        self.assertEqual(call(f"parse({error['exit_code']}, {json.dumps(error['stdout'])}, {json.dumps(error['stderr'])})")["ok"], False)


if __name__ == "__main__":
    unittest.main()
