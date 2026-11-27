"""Unit tests for the event-driven KDE Connect D-Bus snapshot helper."""
import importlib.util
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

SCRIPT = (Path(__file__).resolve().parents[2] /
          "Configs/.config/quickshell/shared/scripts/kdeconnect_state.py")
spec = importlib.util.spec_from_file_location("kdeconnect_state", SCRIPT)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


def response(data, kind="s"):
    return json.dumps({"type": kind, "data": data})


DEVICE_IDS = ["11111111_1111_4111_8111_111111111111", "22222222222242228222222222222222"]


class Snapshot(unittest.TestCase):
    def test_dbus_json_preserves_arbitrary_names(self):
        names = ["Ana's iPhone", "a>b <c>", "São José 📱"]
        ids = ["one", "two", "three"]

        def fake(args, timeout=5):
            if args[3] == "call":
                return response([ids], "as")
            if args[3] == "get-property":
                path, iface, prop = args[5], args[6], args[7]
                if prop == "isPaired": return response(True, "b")
                if prop == "name": return response(names[ids.index(path.rsplit("/", 1)[1])])
                if prop == "type": return response("phone")
                if prop == "isReachable": return response(True, "b")
                raise RuntimeError("missing property")
            raise AssertionError(args)

        with patch.object(helper, "run", side_effect=fake):
            result = helper.snapshot()
        self.assertEqual({d["name"] for d in result["devices"]}, set(names))

    def test_empty_device_list(self):
        with patch.object(helper, "run", return_value=response([[]], "as")):
            self.assertEqual(helper.snapshot()["devices"], [])

    def test_unpaired_device_is_filtered_out(self):
        def fake(args, timeout=5):
            if args[3] == "call": return response([["paired", "guest"]], "as")
            prop = args[7]
            if args[5].endswith("/guest") and prop == "isPaired": return response(False, "b")
            return {"isPaired": response(True, "b"), "name": response("Phone"),
                    "type": response("phone"), "isReachable": response(True, "b")}[prop]
        with patch.object(helper, "run", side_effect=fake):
            self.assertEqual([d["id"] for d in helper.snapshot()["devices"]], ["paired"])

    def test_missing_battery_object_uses_unknown_values(self):
        def fake(args, timeout=5):
            if args[3] == "call": return response([["p"]], "as")
            prop = args[7]
            values = {"isPaired": response(True, "b"), "name": response("Phone"),
                      "type": response("phone"), "isReachable": response(True, "b")}
            if prop not in values: raise RuntimeError("unknown object")
            return values[prop]
        with patch.object(helper, "run", side_effect=fake):
            device = helper.snapshot()["devices"][0]
        self.assertEqual((device["battery"], device["charging"]), (-1, False))

    def test_nonzero_child_dies_when_parent_is_killed(self):
        child_code = "import time; time.sleep(30)"
        parent_code = (
            "import sys,time; sys.path.insert(0, %r); import kdeconnect_state as h; "
            "p=h.spawn([sys.executable,'-c',%r]); print(p.pid,flush=True); time.sleep(30)"
        ) % (str(SCRIPT.parent), child_code)
        parent = subprocess.Popen([sys.executable, "-c", parent_code], stdout=subprocess.PIPE, text=True)
        try:
            child_pid = int(parent.stdout.readline())
            os.kill(parent.pid, signal.SIGKILL)
            parent.wait(timeout=3)
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                try:
                    os.kill(child_pid, 0)
                except ProcessLookupError:
                    break
                time.sleep(0.05)
            else:
                self.fail("child survived parent SIGKILL")
        finally:
            if parent.poll() is None: parent.kill()
            if parent.stdout is not None: parent.stdout.close()

    def test_relevance_filter_ignores_unrelated_signals(self):
        self.assertFalse(helper.relevant_line("member=PropertiesChanged iface=org.mpris.MediaPlayer2"))
        self.assertTrue(helper.relevant_line("/modules/kdeconnect/devices/x/battery: org.kde.kdeconnect.device.battery.refreshed (false, 51)"))
        self.assertTrue(helper.relevant_line("/modules/kdeconnect/devices/x: org.freedesktop.DBus.Properties.PropertiesChanged ('org.kde.kdeconnect.device', {'isReachable': <true>}, [])"))
        self.assertFalse(helper.relevant_line("/modules/kdeconnect: org.kde.kdeconnect.daemon.customDevicesChanged (['The name org.kde.kdeconnect is owned by fake'],)"))
        self.assertFalse(helper.relevant_line("/modules/kdeconnect: org.kde.kdeconnect.daemon.connectivity_report ('deviceAdded')"))
        self.assertFalse(helper.relevant_line("/modules/kdeconnect/devices/x: org.kde.kdeconnect.device.notifications ('deviceAdded')"))
        self.assertTrue(helper.relevant_line("The name org.kde.kdeconnect is owned by :1.100"))
        self.assertTrue(helper.relevant_line("The name org.kde.kdeconnect does not have an owner"))
        self.assertIsNone(helper.owner_event("/modules/kdeconnect/devices/x: org.kde.kdeconnect.device.nameChanged ('is owned by :1.22')"))

    def test_captured_busctl_replies_are_parsed(self):
        ids_reply = '{"type":"as","data":[["11111111_1111_4111_8111_111111111111","22222222222242228222222222222222"]]}'
        captured = {
            "isPaired": '{"type":"b","data":true}',
            "name": '{"type":"s","data":"Test Phone"}',
            "type": '{"type":"i","data":51}',
            "isReachable": '{"type":"b","data":true}',
        }
        def fake(args, timeout=5):
            if args[3] == "call": return ids_reply
            prop = args[7]
            if prop == "type": return '{"type":"s","data":"phone"}'
            if prop in captured: return captured[prop]
            if prop == "hasBattery": return '{"type":"b","data":false}'
            raise RuntimeError("unknown property")
        with patch.object(helper, "run", side_effect=fake):
            devices = helper.snapshot()["devices"]
        self.assertEqual([d["id"] for d in devices], DEVICE_IDS)
        self.assertEqual(devices[0]["name"], "Test Phone")

    def test_real_subprocess_emits_initial_update_then_empty(self):
        with tempfile.TemporaryDirectory() as td:
            bindir = Path(td)
            statefile = bindir / "battery"
            statefile.write_text("51")
            def executable(name, contents):
                path = bindir / name
                path.write_text("#!/usr/bin/env python3\n" + contents)
                path.chmod(0o755)
            executable("kdeconnect-cli", "pass\n")
            executable("busctl", """
import json, os, sys
args = sys.argv[1:]
if 'call' in args:
 print(json.dumps({'type':'as','data':[['22222222222242228222222222222222']]}))
else:
 prop = args[-1]
 values = {'isPaired':('b',True), 'name':('s','Test Phone'), 'type':('s','phone'), 'isReachable':('b',True), 'hasBattery':('b',True), 'charge':('i',int(open(os.environ['KDE_STATE']).read())), 'isCharging':('b',False)}
 kind, value = values[prop]
 print(json.dumps({'type':kind,'data':value}))
""")
            executable("gdbus", """
import os, sys, time
print('The name org.kde.kdeconnect is owned by :1.100', flush=True)
time.sleep(.35)
open(os.environ['KDE_STATE'],'w').write('52')
print('/modules/kdeconnect/devices/22222222222242228222222222222222/battery: org.kde.kdeconnect.device.battery.refreshed (false, 52)', flush=True)
time.sleep(.35)
print('The name org.kde.kdeconnect does not have an owner', flush=True)
time.sleep(3)
""")
            env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ["PATH"], KDE_STATE=str(statefile))
            proc = subprocess.Popen([sys.executable, str(SCRIPT)], stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE, text=True, env=env)
            try:
                lines = []
                deadline = time.monotonic() + 5
                while len(lines) < 3 and time.monotonic() < deadline:
                    line = proc.stdout.readline()
                    if line: lines.append(json.loads(line))
                self.assertEqual([x["devices"][0]["battery"] if x["devices"] else None for x in lines], [51, 52, None])
            finally:
                proc.terminate()
                proc.wait(timeout=3)
                proc.stdout.close()
                proc.stderr.close()

    def test_not_installed_is_one_explicit_empty_state(self):
        with patch.object(helper.shutil, "which", return_value=None), patch.object(helper, "emit") as emit:
            self.assertEqual(helper.main(), 0)
        emit.assert_called_once_with({"installed": False, "devices": []})

    def test_unchanged_state_is_emitted_only_once(self):
        state = {"installed": True, "devices": []}
        with patch.object(helper, "emit") as emit:
            previous = helper.emit_if_changed(state, None)
            previous = helper.emit_if_changed(state.copy(), previous)
        emit.assert_called_once_with(state)
        self.assertEqual(previous, helper.state_key(state))


if __name__ == "__main__":
    unittest.main()
