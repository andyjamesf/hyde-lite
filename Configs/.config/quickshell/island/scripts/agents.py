#!/usr/bin/env python3
"""Wi-Fi and Bluetooth agents of the Morphing Island (run by services/Agents.qml).

Takes the place of nm-applet's and blueman's password/PIN windows: NetworkManager and BlueZ ask
this process, and the island asks you.

  NetworkManager SecretAgent: a network needs a password it does not have (wrong or changed
    password, WPA-Enterprise). Secrets NetworkManager keeps itself never come here. Secrets saved
    for nm-applet in the keyring (libsecret) are still used, and new ones for agent-owned
    connections are saved there too.
  BlueZ Agent1 (default agent, KeyboardDisplay): PIN or passkey to type, a code to confirm or to
    type on the device, and permission for an unpaired device.

Protocol, one JSON object per line.
  stdout (to the island):
    {"type": "wifi", "id", "name", "retry", "enterprise"}   a network password
    {"type": "pin"|"passkey", "id", "name"}                   a code to type here
    {"type": "confirm", "id", "name", "code"}                 does the device show this code?
    {"type": "authorize", "id", "name", "service"}            let this device connect?
    {"type": "display", "id", "name", "code"}                 type this code on the device
    {"type": "cancel", "id"}                                  the request went away
    {"type": "ready"} / {"type": "error", "text"}
  stdin (answers): {"id", "ok": true|false, "secret": "..."}
Secrets are passed straight to NetworkManager/BlueZ and never written anywhere else (except the
keyring for agent-owned Wi-Fi secrets, as nm-applet does).
"""
import itertools
import json
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

try:
    import gi

    gi.require_version("Secret", "1")
    from gi.repository import Secret

    NM_SCHEMA = Secret.Schema.new(
        "org.freedesktop.NetworkManager.Connection",
        Secret.SchemaFlags.DONT_MATCH_NAME,
        {"connection-uuid": Secret.SchemaAttributeType.STRING, "setting-name": Secret.SchemaAttributeType.STRING, "setting-key": Secret.SchemaAttributeType.STRING},
    )
except Exception:  # no libsecret: the keyring is simply not used
    Secret = None

NM_AGENT = "org.freedesktop.NetworkManager.SecretAgent"
BLUEZ_AGENT = "org.bluez.Agent1"
AGENT_PATH = "/org/morphingisland/agent"
# NetworkManager GetSecrets flags.
ALLOW_INTERACTION, REQUEST_NEW = 0x1, 0x2

_ids = itertools.count(1)
pending = {}  # id → callable(answer_dict)


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def ask(obj, on_answer):
    rid = next(_ids)
    pending[rid] = on_answer
    emit(dict(obj, id=rid))
    return rid


def cancel(rid):
    if pending.pop(rid, None) is not None:
        emit({"type": "cancel", "id": rid})


def on_stdin(source, condition):
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    try:
        answer = json.loads(line)
        handler = pending.pop(int(answer.get("id", 0)), None)
        if handler:
            handler(answer)
    except (ValueError, TypeError):
        pass
    return True


# ---------------------------------------------------------------- NetworkManager

class NMError(dbus.DBusException):
    def __init__(self, name, text=""):
        super().__init__(text)
        self._dbus_error_name = NM_AGENT + "." + name


def keyring_lookup(uuid, setting, key):
    if Secret is None:
        return None
    try:
        return Secret.password_lookup_sync(NM_SCHEMA, {"connection-uuid": uuid, "setting-name": setting, "setting-key": key}, None)
    except Exception:
        return None


def keyring_store(uuid, name, setting, key, value):
    if Secret is None:
        return
    try:
        Secret.password_store_sync(NM_SCHEMA, {"connection-uuid": uuid, "setting-name": setting, "setting-key": key}, Secret.COLLECTION_DEFAULT, f"Network secret for {name}/{setting}/{key}", value, None)
    except Exception:
        pass


def secret_key(connection, setting):
    """The key NetworkManager wants for this setting ("psk", "wep-key0", "password")."""
    if setting == "802-1x":
        return "password"
    sec = connection.get("802-11-wireless-security", {})
    if str(sec.get("key-mgmt", "")) == "none":
        return "wep-key0"
    return "psk"


class NMAgent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, "/org/freedesktop/NetworkManager/SecretAgent")
        self.requests = {}  # (connection path, setting) → request id

    @dbus.service.method(NM_AGENT, in_signature="a{sa{sv}}osasu", out_signature="a{sa{sv}}", async_callbacks=("reply", "error"))
    def GetSecrets(self, connection, path, setting, hints, flags, reply, error):
        setting = str(setting)
        con = connection.get("connection", {})
        uuid = str(con.get("uuid", ""))
        ssid = bytes(connection.get("802-11-wireless", {}).get("ssid", [])).decode("utf-8", "replace")
        name = ssid or str(con.get("id", "network"))
        if setting not in ("802-11-wireless-security", "802-1x"):
            error(NMError("NoSecrets", "Only Wi-Fi secrets are handled here"))
            return
        key = secret_key(connection, setting)

        def answer_with(value):
            reply(dbus.Dictionary({setting: dbus.Dictionary({key: dbus.String(value)}, signature="sv")}, signature="sa{sv}"))

        if not flags & REQUEST_NEW:
            saved = keyring_lookup(uuid, setting, key)
            if saved:
                answer_with(saved)
                return
        if not flags & ALLOW_INTERACTION:
            error(NMError("NoSecrets", "No saved secret"))
            return

        def on_answer(a):
            self.requests.pop((str(path), setting), None)
            if a.get("ok") and a.get("secret"):
                answer_with(a["secret"])
            else:
                error(NMError("UserCanceled", "Cancelled"))

        rid = ask({"type": "wifi", "name": name, "retry": bool(flags & REQUEST_NEW), "enterprise": setting == "802-1x"}, on_answer)
        self.requests[(str(path), setting)] = rid

    @dbus.service.method(NM_AGENT, in_signature="os", out_signature="")
    def CancelGetSecrets(self, path, setting):
        rid = self.requests.pop((str(path), str(setting)), None)
        if rid is not None:
            cancel(rid)

    @dbus.service.method(NM_AGENT, in_signature="a{sa{sv}}o", out_signature="")
    def SaveSecrets(self, connection, path):
        # Only agent-owned secrets (flags 1) reach here: keep them in the keyring, like nm-applet.
        con = connection.get("connection", {})
        uuid, name = str(con.get("uuid", "")), str(con.get("id", ""))
        for setting in ("802-11-wireless-security", "802-1x"):
            values = connection.get(setting, {})
            for key in ("psk", "wep-key0", "password"):
                if key in values and str(values[key]):
                    keyring_store(uuid, name, setting, key, str(values[key]))

    @dbus.service.method(NM_AGENT, in_signature="a{sa{sv}}o", out_signature="")
    def DeleteSecrets(self, connection, path):
        if Secret is None:
            return
        uuid = str(connection.get("connection", {}).get("uuid", ""))
        try:
            Secret.password_clear_sync(NM_SCHEMA, {"connection-uuid": uuid}, None)
        except Exception:
            pass


# ---------------------------------------------------------------- BlueZ

class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


class BluezAgent(dbus.service.Object):
    def __init__(self, bus):
        super().__init__(bus, AGENT_PATH)
        self.bus = bus
        self.current = None  # request id on show (BlueZ has one at a time)
        self.display = None

    def device(self, path):
        try:
            props = dbus.Interface(self.bus.get_object("org.bluez", path), "org.freedesktop.DBus.Properties")
            return props.GetAll("org.bluez.Device1")
        except dbus.DBusException:
            return {}

    def name(self, path):
        d = self.device(path)
        return str(d.get("Alias") or d.get("Name") or str(path).rsplit("/", 1)[-1].replace("_", ":"))

    def _ask(self, kind, path, reply, error, convert=None, **extra):
        def on_answer(a):
            self.current = None
            if not a.get("ok"):
                error(Rejected("Rejected"))
            elif convert is None:
                reply()
            else:
                try:
                    reply(convert(a.get("secret", "")))
                except (ValueError, TypeError):
                    error(Rejected("Invalid code"))

        self.current = ask(dict({"type": kind, "name": self.name(path)}, **extra), on_answer)

    def _end_display(self):
        if self.display is not None:
            emit({"type": "cancel", "id": self.display})
            self.display = None

    @dbus.service.method(BLUEZ_AGENT, in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method(BLUEZ_AGENT, in_signature="o", out_signature="s", async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        self._ask("pin", device, reply, error, convert=lambda s: dbus.String(s.strip()))

    @dbus.service.method(BLUEZ_AGENT, in_signature="o", out_signature="u", async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        self._ask("passkey", device, reply, error, convert=lambda s: dbus.UInt32(int(s.strip())))

    @dbus.service.method(BLUEZ_AGENT, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        self._end_display()
        self.display = next(_ids)
        emit({"type": "display", "id": self.display, "name": self.name(device), "code": str(pincode)})

    @dbus.service.method(BLUEZ_AGENT, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        if self.display is None:
            self.display = next(_ids)
        emit({"type": "display", "id": self.display, "name": self.name(device), "code": f"{int(passkey):06d}", "entered": int(entered)})

    @dbus.service.method(BLUEZ_AGENT, in_signature="ou", out_signature="", async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        self._end_display()
        self._ask("confirm", device, reply, error, code=f"{int(passkey):06d}")

    @dbus.service.method(BLUEZ_AGENT, in_signature="o", out_signature="", async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        self._ask("authorize", device, reply, error, service="")

    @dbus.service.method(BLUEZ_AGENT, in_signature="os", out_signature="", async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid, reply, error):
        d = self.device(device)
        # Paired and trusted devices (everything paired from the island is trusted) need no question.
        if d.get("Paired") and d.get("Trusted"):
            reply()
            return
        self._ask("authorize", device, reply, error, service=str(uuid))

    @dbus.service.method(BLUEZ_AGENT, in_signature="", out_signature="")
    def Cancel(self):
        self._end_display()
        if self.current is not None:
            handler = pending.pop(self.current, None)
            emit({"type": "cancel", "id": self.current})
            self.current = None
            if handler:
                handler({"ok": False})


def main():
    global loop
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()
    agents = []
    try:
        agents.append(NMAgent(bus))
        manager = dbus.Interface(bus.get_object("org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager/AgentManager"), "org.freedesktop.NetworkManager.AgentManager")
        manager.Register("org.morphingisland.agent")
    except dbus.DBusException as e:
        emit({"type": "error", "text": f"NetworkManager agent: {e.get_dbus_message()}"})
    try:
        agents.append(BluezAgent(bus))
        manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
        manager.RegisterAgent(AGENT_PATH, "KeyboardDisplay")
        manager.RequestDefaultAgent(AGENT_PATH)
    except dbus.DBusException as e:
        emit({"type": "error", "text": f"Bluetooth agent: {e.get_dbus_message()}"})
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    emit({"type": "ready"})
    loop.run()


if __name__ == "__main__":
    main()
