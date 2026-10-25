"""The OSD guards of the Morphing Island, tested on the real QML source.

QML cannot run in a cloud session, but the JavaScript inside the functions can: this extracts the functions
from the .qml files and runs them in Node with a fake clock and fake singletons.

  island/core/IslandController.qml    _stormy()           the storm guard (an OSD requested without a
                                                          pause for 20 s)
  shared/services/Audio.qml           _micVolumeChange()  the microphone filter (tiny AGC nudges never
                                      _micMuteChange()    show an OSD)

The audio service is shared by both shells now, so the two thresholds it filters by are its own
properties rather than reads of OsdConfig; the values still come from the island's OsdConfig here,
because that is what island/Shell.qml binds them to.

Skipped without Node. NOT TESTED here: the singletons wired together in a running shell, on a screen. Run:

    python3 -I tools/tests/test_osd_guard.py
"""
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ISLAND = ROOT / "Configs/.config/quickshell/island"
CONTROLLER = ISLAND / "core/IslandController.qml"
AUDIO = ROOT / "Configs/.config/quickshell/shared/services/Audio.qml"
OSD_CONFIG = ISLAND / "config/OsdConfig.qml"
NODE = shutil.which("node")


def function_source(qml, name):
    """The text of `function name(...) { ... }`, by brace matching."""
    start = qml.index(f"function {name}(")
    i = qml.index("{", start)
    depth = 0
    for j in range(i, len(qml)):
        depth += qml[j] == "{"
        depth -= qml[j] == "}"
        if depth == 0:
            return qml[start:j + 1]
    raise AssertionError(f"unbalanced braces in {name}")


def config_value(name):
    m = re.search(rf"readonly property (?:int|real) {name}: ([0-9.]+)", OSD_CONFIG.read_text(encoding="utf-8"))
    assert m, name
    return float(m.group(1))


HARNESS = r"""
const cfg = %(config)s;
let t = 0;
const clock = { now: () => t };
const warnings = [];
const fake = { warn: m => warnings.push(m) };
// The QML functions use the singleton's properties as bare names: `with` gives them that scope.
const make = (src, state) => new Function("OsdConfig", "console", "Date", "state", "with (state) { return (" + src + "); }")(cfg, fake, clock, state);
const out = {};

// ---- storm guard ----
const st = { _runs: {} };
const stormy = make(%(stormy)s, st);
const run = (mode, from, to, every) => { const r = []; for (t = from; t <= to; t += every) r.push([t, stormy(mode)]); return r; };

out.keyHold = run("volume", 0, 15000, 40).some(x => x[1]);            // 15 s of key repeat: never ignored
out.warningsAfterKeyHold = warnings.length;

stormy("volume"); t += 5000;                                         // a pause ends the run
const storm = run("mic", 100000, 125000, 100);                       // 25 s without a pause
out.stormFirstIgnoredAt = (storm.find(x => x[1]) || [null])[0] - 100000;
out.stormAllIgnoredAfter = storm.filter(x => x[0] - 100000 > 20100).every(x => x[1]);
out.stormBeforeNeverIgnored = storm.filter(x => x[0] - 100000 <= 20000).every(x => !x[1]);
out.warningsAfterStorm = warnings.length;
out.warningText = warnings[warnings.length - 1];

out.otherModeUnaffected = run("brightness", 125000, 125500, 100).every(x => !x[1]);
t = 125000 + 1501 + 1000; out.afterPauseAllowed = !stormy("mic");   // a pause longer than the gap ends it
out.sameGapKeepsRun = (() => { const s2 = { _runs: {} }, f = make(%(stormy)s, s2); t = 0; let ignored = false;
  for (t = 0; t <= 30000; t += 1500) ignored = f("x"); return ignored; })();   // exactly the gap: still one run
out.longerGapBreaksRun = (() => { const s2 = { _runs: {} }, f = make(%(stormy)s, s2); let ignored = false;
  for (t = 0; t <= 60000; t += 1501) ignored = ignored || f("x"); return ignored; })();

// ---- microphone filter ----
const mic = n => ({ _armed: true, micMinDelta: cfg.micMinDelta, micMinIntervalMs: cfg.micMinIntervalMs, micVolume: 0.5, _micShownVolume: 0.5, _micLastEmit: 0, micEmitTimer: { n: 0, restart() { this.n++; } }, ...n });
const volChange = s => make(%(micVolumeChange)s, s);
const muteChange = s => make(%(micMuteChange)s, s);

let s = mic({}), f = volChange(s);
for (let i = 0; i < 100; i++) { t = 1000 + i * 100; s.micVolume = 0.5 + (i %% 2 ? 0.012 : -0.011); f(); }
out.agcJitterEmits = s.micEmitTimer.n;

s = mic({}); f = volChange(s);
t = 1000; s.micVolume = 0.60; f(); out.realChangeEmits = s.micEmitTimer.n;
t = 1100; s.micVolume = 0.65; f(); out.tooSoonEmits = s.micEmitTimer.n;       // 100 ms later: dropped
t = 1400; s.micVolume = 0.70; f(); out.afterIntervalEmits = s.micEmitTimer.n; // 400 ms later: shown
out.shownVolumeFollows = s._micShownVolume;

s = mic({}); f = volChange(s);
for (let i = 0; i < 6; i++) { t = 1000 + i * 400; s.micVolume = 0.5 + i * 0.005; f(); }   // slow drift to 0.525
out.slowDriftEmits = s.micEmitTimer.n;

s = mic({ _armed: false }); t = 1000; s.micVolume = 0.9; volChange(s)(); muteChange(s)();
out.notArmedEmits = s.micEmitTimer.n;
s = mic({}); muteChange(s)(); muteChange(s)(); out.muteAlwaysEmits = s.micEmitTimer.n;

console.log(JSON.stringify(out));
"""


@unittest.skipUnless(NODE, "Node is not installed")
class OsdGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        controller = CONTROLLER.read_text(encoding="utf-8")
        audio = AUDIO.read_text(encoding="utf-8")
        config = {n: config_value(n) for n in ("stormGapMs", "stormAfterMs", "micMinDelta", "micMinIntervalMs")}
        script = HARNESS % {
            "config": json.dumps(config),
            "stormy": json.dumps(function_source(controller, "_stormy")),
            "micVolumeChange": json.dumps(function_source(audio, "_micVolumeChange")),
            "micMuteChange": json.dumps(function_source(audio, "_micMuteChange")),
        }
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "run.js"
            path.write_text(script, encoding="utf-8")
            r = subprocess.run([NODE, str(path)], capture_output=True, text=True, timeout=60, check=False)
        assert r.returncode == 0, r.stderr
        cls.r = json.loads(r.stdout.strip().splitlines()[-1])

    def test_holding_a_key_is_never_a_storm(self):
        self.assertFalse(self.r["keyHold"])
        self.assertEqual(self.r["warningsAfterKeyHold"], 0)

    def test_twenty_seconds_without_a_pause_is_a_storm(self):
        self.assertIsNotNone(self.r["stormFirstIgnoredAt"])
        self.assertTrue(20000 < self.r["stormFirstIgnoredAt"] <= 20200, self.r["stormFirstIgnoredAt"])
        self.assertTrue(self.r["stormBeforeNeverIgnored"])
        self.assertTrue(self.r["stormAllIgnoredAfter"])

    def test_one_warning_per_storm_and_it_names_the_osd(self):
        self.assertEqual(self.r["warningsAfterStorm"], 1)
        self.assertIn('"mic"', self.r["warningText"])
        self.assertIn("OSD storm", self.r["warningText"])

    def test_other_osds_and_later_requests_are_not_affected(self):
        self.assertTrue(self.r["otherModeUnaffected"])
        self.assertTrue(self.r["afterPauseAllowed"])

    def test_the_gap_boundary(self):
        self.assertTrue(self.r["sameGapKeepsRun"], "a pause of exactly the gap does not end the run")
        self.assertFalse(self.r["longerGapBreaksRun"], "a longer pause does")

    def test_agc_jitter_never_shows_an_osd(self):
        self.assertEqual(self.r["agcJitterEmits"], 0)

    def test_a_real_change_shows_and_is_rate_limited(self):
        self.assertEqual(self.r["realChangeEmits"], 1)
        self.assertEqual(self.r["tooSoonEmits"], 1)
        self.assertEqual(self.r["afterIntervalEmits"], 2)
        self.assertAlmostEqual(self.r["shownVolumeFollows"], 0.70)

    def test_a_slow_drift_shows_once_it_adds_up(self):
        self.assertEqual(self.r["slowDriftEmits"], 1)

    def test_not_armed_and_mute(self):
        self.assertEqual(self.r["notArmedEmits"], 0)
        self.assertEqual(self.r["muteAlwaysEmits"], 2)


class Wiring(unittest.TestCase):
    """Text-level checks of what cannot be executed here."""

    def test_only_the_three_osds_are_guarded(self):
        text = CONTROLLER.read_text(encoding="utf-8")
        m = re.search(r"_guarded: \[([^\]]*)\]", text)
        self.assertIsNotNone(m)
        listed = sorted(x.strip().strip('"') for x in m.group(1).split(","))
        self.assertEqual(listed, ["brightness", "mic", "volume"])
        # written out as strings (qmllint counts IslandState member reads in a binding): they must still
        # be the values of IslandState's constants
        state = (CONTROLLER.parent / "IslandState.qml").read_text(encoding="utf-8")
        for name in listed:
            self.assertRegex(state, rf'property string {name}: "{name}"')

    def test_the_guard_runs_before_the_surface_check(self):
        body = function_source(CONTROLLER.read_text(encoding="utf-8"), "showTransient")
        self.assertLess(body.index("_stormy(m)"), body.index("isSurface(mode)"))

    def test_defaults_match_the_documentation(self):
        self.assertEqual(config_value("stormGapMs"), 1500)
        self.assertEqual(config_value("stormAfterMs"), 20000)
        self.assertEqual(config_value("micMinDelta"), 0.02)
        self.assertEqual(config_value("micMinIntervalMs"), 300)


if __name__ == "__main__":
    unittest.main()
