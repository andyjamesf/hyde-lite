"""Graph compilation and sampling stay eval-free and split discontinuities."""
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

QS = Path(__file__).resolve().parents[2] / "Configs/.config/quickshell"
CALC = (QS / "shared/services/Calculator.qml").read_text()
GRAPH = (QS / "shared/services/GraphMath.qml").read_text()
PRELUDE = "\n".join([
    f"const _functions = {qml_js.extract_property(CALC, '_functions')};",
    f"const _constants = {qml_js.extract_property(CALC, '_constants')};",
    qml_js.extract_function(CALC, "_tokenize"), qml_js.extract_function(CALC, "evaluate"), qml_js.extract_function(CALC, "compile"),
    *[qml_js.extract_function(GRAPH, name) for name in ("sample", "zoom", "pan", "ticks")],
])


def js(code):
    return qml_js.run_node(PRELUDE + "\n" + code)


class GraphMath(unittest.TestCase):
    def test_compile_and_angle_modes(self):
        self.assertEqual(js("console.log(compile('x^2','rad')(3));"), 9)
        self.assertAlmostEqual(js("console.log(compile('sin(x)','deg')(90));"), 1, places=9)
        self.assertTrue(js("console.log(JSON.stringify([compile('2,5x','rad'),compile('foo(x)','rad'),compile('sqrt(x)','rad')(-1)]));")[0] is None)
        cases = [("2x", 6), ("2(x+1)", 8), ("x(x+1)", 12), ("-x^2", -9), ("2pi*x", 6 * 3.141592653589793), ("3", 3)]
        for formula, want in cases:
            self.assertAlmostEqual(js(f"console.log(compile({json.dumps(formula)},'rad')(3));"), want)
        for formula, x, want in (("sin(2x)", 30, .8660254037844386), ("sin(x+1)", 29, .5), ("cos(x/2)", 120, .5), ("sin(30)+x", 2, 2.5), ("asin(x/2)", 1, 30)):
            self.assertAlmostEqual(js(f"console.log(compile({json.dumps(formula)},'deg')({x}));"), want, places=8)

    def test_minus_binds_looser_than_power_and_names_containing_e_or_x_survive(self):
        got = js("const at=(t,x)=>{const f=compile(t,'rad'); return f?f(x):'invalid';};"
                 "console.log(JSON.stringify([at('-x^2',3), at('-2^2',0), at('(-x)^2',3), at('2^-x',1), at('exp(x)',0), at('2exp(x)',0), at('ex',1)]));")
        self.assertEqual(got[:6], [-9, -4, 9, 0.5, 1, 2])
        self.assertAlmostEqual(got[6], 2.718281828459045)

    def test_smooth_curves_are_not_cut_at_their_peaks(self):
        for formula in ("3*sin(40x)", "-x^2+6", "x^2", "cos(60x)"):
            for width in (469, 500, 701):
                result = js(f"console.log(JSON.stringify(sample(compile({json.dumps(formula)},'deg'),{{xMin:-10,xMax:10,yMin:-50,yMax:110}},{width})));")
                self.assertEqual(len(result), 1, (formula, width))

    def test_discontinuities_are_split(self):
        for formula, angle in (("1/x", "rad"), ("tan(x)", "deg")):
            result = js(f"console.log(JSON.stringify(sample(compile({json.dumps(formula)},{json.dumps(angle)}),{{xMin:-180,xMax:180,yMin:-10,yMax:10}},500)));" )
            self.assertGreaterEqual(len(result), 2)
            for segment in result:
                for left, right in zip(segment, segment[1:], strict=False):
                    self.assertFalse(left[1] * right[1] < 0 and abs(left[1] - right[1]) > 10)

    def test_view_operations_and_ticks(self):
        got = js("const v={xMin:-10,xMax:10,yMin:-10,yMax:10}; const z=zoom(v,.5,2,3); const p=pan(v,.1,.1); console.log(JSON.stringify([z,p,ticks(-10,10,5)]));")
        self.assertEqual(got[0], {"xMin": -4, "xMax": 6, "yMin": -3.5, "yMax": 6.5})
        self.assertEqual(got[2], [-10, -5, 0, 5, 10])

    def test_continuous_steep_and_discontinuous_curves(self):
        view = "{xMin:-2,xMax:2,yMin:-10,yMax:10}"
        for formula in ("x", "100x", "x^3", "sqrt(x)"):
            got = js(f"console.log(JSON.stringify(sample(compile({json.dumps(formula)},'deg'),{view},300)));" )
            self.assertTrue(got, formula)
        for formula, angle, sample_view in (("1/x", "rad", view), ("tan(x)", "deg", "{xMin:-180,xMax:180,yMin:-10,yMax:10}"), ("floor(x)", "rad", view)):
            got = js(f"console.log(JSON.stringify(sample(compile({json.dumps(formula)},{json.dumps(angle)}),{sample_view},300)));" )
            self.assertTrue(got, formula)
            self.assertGreaterEqual(len(got), 2, formula)


if __name__ == "__main__":
    unittest.main()
