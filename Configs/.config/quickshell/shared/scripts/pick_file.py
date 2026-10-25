#!/usr/bin/env python3
"""Opens the system file chooser (xdg-desktop-portal) and prints the chosen path to stdout.

The shell has no regular windows and the Qt theme (qt6ct) has no native chooser; the portal shows
the system (GTK) chooser regardless. Exits with code 1 if the user cancels.

Usage: pick_file.py "Title" "Images:*.png;*.jpg" [initial folder]
"""
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

title = sys.argv[1] if len(sys.argv) > 1 else "Choose a file"
filters = []
if len(sys.argv) > 2 and ":" in sys.argv[2]:
    name, patterns = sys.argv[2].split(":", 1)
    filters = [(name, [(0, p) for p in patterns.split(";") if p])]
folder = sys.argv[3] if len(sys.argv) > 3 else None

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop()
result = {"path": None}

token = "qs_pick_file"
sender = bus.get_unique_name()[1:].replace(".", "_")
handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"


def on_response(_conn, _sender, _path, _iface, _signal, params):
    code, results = params.unpack()
    if code == 0 and results.get("uris"):
        result["path"] = Gio.File.new_for_uri(results["uris"][0]).get_path()
    loop.quit()


bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
                     handle, None, Gio.DBusSignalFlags.NO_MATCH_RULE, on_response)

options = {"handle_token": GLib.Variant("s", token), "modal": GLib.Variant("b", True)}
if filters:
    options["filters"] = GLib.Variant("a(sa(us))", filters)
if folder:
    options["current_folder"] = GLib.Variant("ay", folder.encode() + b"\0")

bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
              "org.freedesktop.portal.FileChooser", "OpenFile",
              GLib.Variant("(ssa{sv})", ("", title, options)), None, Gio.DBusCallFlags.NONE, -1, None)
loop.run()

if not result["path"]:
    sys.exit(1)
print(result["path"])
