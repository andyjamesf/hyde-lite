"""The keys are one list (Configs/.config/hypr/keybinds.lua), so the list has to hold together.

The file is plain data; it is read with the system `lua` (skipped when there is none) and checked
for the faults that have already happened: the same combination bound twice, a key with no
description, an island action the island does not answer, and a key that was dropped on purpose
coming back.
"""
import json
import pathlib
import re
import shutil
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
KEYBINDS = ROOT / "Configs/.config/hypr/keybinds.lua"
ISLAND_SHELL = ROOT / "Configs/.config/quickshell/island/Shell.qml"

DUMP = r"""
local function esc(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end
local k = dofile(arg[1])
local out = {}
for _, group in ipairs({ "shell", "binds" }) do
    for _, b in ipairs(k[group] or {}) do
        out[#out + 1] = string.format('{"group":%s,"keys":%s,"desc":%s,"island":%s}',
            esc(group), esc(b.keys), esc(b.desc or ""), b.island and esc(b.island) or "null")
    end
end
local un = {}
for _, s in ipairs(k.unbind or {}) do un[#un + 1] = esc(s) end
print('{"binds":[' .. table.concat(out, ",") .. '],"unbind":[' .. table.concat(un, ",") .. ']}')
"""


def norm(spec):
    """A key combination as a set, so 'SHIFT + $mod + A' and '$mod + SHIFT + A' compare equal."""
    parts = [p.strip().upper().replace("CONTROL", "CTRL") for p in spec.split(" + ")]
    return frozenset(parts)


@unittest.skipUnless(shutil.which("lua"), "no lua on this machine")
class Keybinds(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        out = subprocess.run(["lua", "-", str(KEYBINDS)], input=DUMP, capture_output=True,
                             text=True, check=True).stdout
        cls.data = json.loads(out)
        cls.binds = cls.data["binds"]

    def test_no_combination_is_bound_twice(self):
        seen = {}
        for b in self.binds:
            key = norm(b["keys"])
            self.assertNotIn(key, seen, "%s is bound twice (%s, %s)" % (b["keys"], seen.get(key), b["desc"]))
            seen[key] = b["desc"]

    def test_every_key_has_a_described_category(self):
        for b in self.binds:
            self.assertRegex(b["desc"], r"^\[[^\]]+\] .+", "%s has no '[Category] what' description" % b["keys"])

    def test_island_actions_exist_in_the_island(self):
        text = ISLAND_SHELL.read_text(encoding="utf-8")
        handled = set(re.findall(r"function (\w+)\(", text))
        for b in self.binds:
            if b["island"]:
                verb = b["island"].split()[0]
                self.assertIn(verb, handled, "%s sends '%s', which the island has no function for" % (b["keys"], verb))

    def test_dropped_keys_stay_dropped(self):
        """Keys removed on purpose (duplicates of another key) must not come back as binds."""
        bound = {norm(b["keys"]) for b in self.binds}
        for gone in ("$mod + CTRL + B", "$mod + T", "$mod + SHIFT + B", "$mod + ALT + I",
                     "$mod + ALT + Right", "$mod + ALT + Left"):
            self.assertNotIn(norm(gone), bound, "%s was dropped on purpose" % gone)

    def test_the_shell_key_and_the_wallpaper_keys_are_there(self):
        bound = {norm(b["keys"]) for b in self.binds}
        for want in ("$mod + SHIFT + I", "$mod + CTRL + Right", "$mod + CTRL + Left", "$mod + L", "$mod + Return"):
            self.assertIn(norm(want), bound)

    def test_keybindings_md_is_current(self):
        """KEYBINDINGS.md is generated from the same files; a key changed without it is a stale list."""
        r = subprocess.run(["python3", "-I", str(ROOT / "tools/gen_keybindings.py"), "--check"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
