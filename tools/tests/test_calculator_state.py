"""Calculator state validation and bounded history."""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

SRC = (Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/shared/services/CalculatorState.qml").read_text()
PRELUDE = "\n".join([qml_js.extract_function(SRC, "defaults"), qml_js.extract_function(SRC, "restore")])


def restore(value):
    return qml_js.run_node(f"{PRELUDE}\nconsole.log(JSON.stringify(restore({json.dumps(value)})));" )


class CalculatorState(unittest.TestCase):
    def test_path_and_focus_are_persisted_with_xdg_state(self):
        self.assertIn("`${Paths.stateHome}/quickshell/calculator.json`", SRC)
        self.assertNotIn("file.remove()", SRC)
        state = {"mode": "graph", "angle": "deg", "input": "x", "cursor": 1, "focusedField": "y2", "result": "", "history": [], "functions": ["", "", ""], "view": {"xMin": -1, "xMax": 1, "yMin": -1, "yMax": 1}}
        self.assertEqual(restore(json.dumps(state))["focusedField"], "y2")

    def test_empty_broken_and_wrong_types_use_defaults(self):
        default = restore("")
        self.assertEqual(default, restore("{"))
        self.assertEqual(default, restore('{"mode":7,"history":"x"}'))
        self.assertEqual(default["view"], {"xMin": -10, "xMax": 10, "yMin": -10, "yMax": 10})

    def test_valid_state_round_trips(self):
        state = {"mode": "graph", "angle": "rad", "input": "x^2", "cursor": 2, "result": "9", "history": [{"expr": "3^2", "result": "9"}],
                 "focusedField": "expression", "functions": ["x^2", "", ""], "view": {"xMin": -5, "xMax": 5, "yMin": -2, "yMax": 20}}
        self.assertEqual(restore(json.dumps(state)), state)

    def test_history_is_capped_and_bad_view_resets(self):
        default = restore("")
        state = {**default, "history": [{"expr": str(i), "result": str(i)} for i in range(101)]}
        self.assertEqual(len(restore(json.dumps(state))["history"]), 100)
        for view in ({"xMin": 2, "xMax": 1, "yMin": -1, "yMax": 1}, {"xMin": 0, "xMax": float("nan"), "yMin": -1, "yMax": 1}):
            state["view"] = view
            self.assertEqual(restore(json.dumps(state)), default)


if __name__ == "__main__":
    unittest.main()
