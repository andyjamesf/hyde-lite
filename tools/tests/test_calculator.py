"""services/Calculator.qml (the launcher's calculator: its own parser, no eval) run in Node from the QML source."""
import json
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

SRC = (Path(__file__).resolve().parents[2] / "Configs/.config/morphing-island/services/Calculator.qml").read_text()
PRELUDE = "\n".join([
    f"const _functions = {qml_js.extract_property(SRC, '_functions')};",
    f"const _constants = {qml_js.extract_property(SRC, '_constants')};",
    qml_js.extract_function(SRC, "_tokenize"),
    qml_js.extract_function(SRC, "evaluate"),
    qml_js.extract_function(SRC, "format"),
])


def ev(*texts):
    # JSON turns Infinity and NaN into null, which would hide a missing finiteness check: report them as text
    js = "const show = r => r === null || Number.isFinite(r) ? r : String(r);"
    return qml_js.run_node(f"{PRELUDE}\n{js}\nconsole.log(JSON.stringify({json.dumps(list(texts))}.map(t => show(evaluate(t)))));")


def fmt(*numbers):
    # JSON cannot carry NaN/Infinity: pass them as strings and convert
    js = f"const xs = {json.dumps(list(numbers))}.map(x => x === 'NaN' ? NaN : x === 'Inf' ? Infinity : x);"
    return qml_js.run_node(f"{PRELUDE}\n{js}\nconsole.log(JSON.stringify(xs.map(x => format(x))));")


def close(a, b):
    return a is not None and abs(a - b) < 1e-9


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Evaluate(unittest.TestCase):
    def check(self, cases):
        got = ev(*[c[0] for c in cases])
        for (text, want), g in zip(cases, got, strict=True):
            if want is None:
                self.assertIsNone(g, text)
            else:
                self.assertTrue(close(g, want), f"{text!r}: got {g}, want {want}")

    def test_precedence_and_associativity(self):
        self.check([("1+2*3", 7), ("(1+2)*3", 9), ("2^3^2", 512), ("2*3^2", 18), ("10-4-3", 3), ("100/10/5", 2),
                    ("2^-1", 0.5), ("--3+1", 4), ("+3*+2", 6), ("8/4*2", 4)])

    def test_unary_minus_binds_tighter_than_power(self):
        # Pins the current behaviour, which is Excel's: -2^2 is (-2)^2 = 4. Most programming languages and
        # mathematical notation give -(2^2) = -4. Changing it is a decision for the maintainer, not a test fix.
        self.check([("-2^2", 4), ("-2^3", -8), ("2*-3", -6), ("-(2^2)", -4)])

    def test_percent_and_remainder(self):
        self.check([("50*20%", 10), ("20%+1", 1.2), ("(10+10)%", 0.2), ("10%3", 1), ("10 % 3 + 1", 2), ("200*10%+5", 25)])

    def test_input_forms(self):
        self.check([("2,5*2", 5), ("6×7", 42), ("9÷3", 3), (" 1 +  2 ", 3), ("1e3+1", 1001), (".5+.5", 1), ("2.5e-1*4", 1),
                    ("SQRT(16)+1", 5), ("Pi*0+1", 1)])

    def test_constants_and_functions(self):
        self.check([("pi*2", 2 * 3.141592653589793), ("e^1", 2.718281828459045), ("sqrt(16)", 4), ("abs(-3)+0", 3),
                    ("log(1000)", 3), ("ln(e)", 1), ("exp(0)+0", 1), ("round(2.5)+0", 3), ("floor(2.9)+0", 2),
                    ("ceil(2.1)+0", 3), ("sin(0)+cos(0)", 1), ("atan(1)*4", 3.141592653589793), ("asin(1)+acos(1)", 1.5707963267948966),
                    ("tan(0)+1", 1)])

    def test_not_an_expression(self):
        self.check([("", None), ("   ", None), ("42", None), ("-42", None), ("3.14", None), ("abc", None), ("e", None), ("ee", None), ("pie", None), ("pi", 3.141592653589793), ("PI", 3.141592653589793),
                    ("pi+0", 3.141592653589793), ("2pi", None), ("pi*2", 6.283185307179586), ("-pi", -3.141592653589793)])

    def test_malformed_input_is_null_not_an_error(self):
        self.check([("1+", None), ("*2", None), ("(1+2", None), ("1+2)", None), ("()", None), ("1 2", None), ("2 3 +", None),
                    ("sqrt", None), ("sqrt 4", None), ("sqrt(", None), ("foo(1)+1", None), ("1+x", None), ("1..2+1", None),
                    ("1+2;3", None), ("1 $ 2", None), ("--", None), ("^2", None)])

    def test_non_finite_results_are_null(self):
        self.check([("1/0", None), ("0/0", None), ("sqrt(-1)", None), ("ln(0)", None), ("10^1000", None), ("log(-1)", None)])

    def test_only_the_two_own_maps_are_looked_up(self):
        # names that exist on Object.prototype must not resolve to a function or constant
        self.check([("constructor(1)+1", None), ("toString(1)+1", None), ("__proto__+1", None), ("hasOwnProperty(1)+1", None),
                    ("valueOf+1", None), ("constructor+1", None)])

    def test_no_code_runs(self):
        self.check([("process.exit(1)", None), ("require('fs')", None), ("1;process.exit(1)", None),
                    ("(()=>1)()", None), ("`1`+1", None), ("1 + alert(2)", None)])

    def test_big_inputs_finish(self):
        deep = "(" * 400 + "1+1" + ")" * 400
        flat = "+".join(["1"] * 5000)
        got = ev(deep, flat, "2^" * 200 + "1", "-" * 3000 + "1+1")
        self.assertTrue(close(got[0], 2))
        self.assertTrue(close(got[1], 5000))
        self.assertTrue(got[2] is None or got[2] > 0)  # a huge tower: finite or null, but it returns
        self.assertIn(got[3], (2, 0, None))


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Constants(unittest.TestCase):
    def test_pi_and_e_come_from_the_math_object(self):
        # the source must take them from Math, not from a typed-in literal, and the results must be bit-identical
        self.assertIn("pi: Math.PI", SRC)
        self.assertIn("e: Math.E", SRC)
        got = qml_js.run_node(f"{PRELUDE}\nconsole.log(JSON.stringify([evaluate('pi') === Math.PI, evaluate('e^1') === Math.exp(1) || "
                              "Math.abs(evaluate('e^1') - Math.E) < 1e-15, evaluate('pi*1') === Math.PI]));")
        self.assertEqual(got, [True, True, True])


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Format(unittest.TestCase):
    def test_readable_results(self):
        self.assertEqual(fmt(0, 1, -1, 0.5, 42, 1234567, 0.1 + 0.2, 1 / 3, 2 / 3, 100, 1e10, 123456789012345.0),
                         ["0", "1", "-1", "0.5", "42", "1234567", "0.3", "0.333333333333", "0.666666666667", "100", "10000000000",
                          "123456789012000"])

    def test_extreme_values_use_scientific_notation(self):
        got = fmt(1e20, -1e20, 1.5e-12, 1e15, 2.5e-10)
        self.assertEqual(got, ["1e+20", "-1e+20", "1.5e-12", "1e+15", "2.5e-10"])

    def test_not_a_number_is_empty(self):
        self.assertEqual(fmt("NaN", "Inf", "x"), ["", "", ""])


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Documentation(unittest.TestCase):
    def test_every_function_in_the_header_is_implemented(self):
        # the header comment lists the functions the launcher advertises
        for name in ("sqrt", "abs", "sin", "cos", "tan", "asin", "acos", "atan", "log", "ln", "exp", "round", "floor", "ceil"):
            self.assertIn(f"            {name}: Math.", SRC)
            self.assertIn(name, SRC.split("Singleton {")[0])


if __name__ == "__main__":
    unittest.main()
