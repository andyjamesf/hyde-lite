#!/usr/bin/env python3
"""Google Calendar for the shell: connect once (OAuth), list your calendars, create events.

The iCal links the calendar reads are read-only; creating events needs Google's Calendar API, and
the API needs an OAuth client of your own (Google Cloud Console → Credentials → OAuth client ID →
Desktop app; see the island's README). Everything is stored outside git, readable only by you:

    ~/.local/share/quickshell/google/client.json   the OAuth client (the file Google gives you)
    ~/.local/share/quickshell/google/token.json    the access you granted (refresh token)

Commands (each prints one line of JSON; errors as {"error": "..."}):

    gcal.py status                 {"client": bool, "connected": bool}
    gcal.py set-client FILE        stores the client file Google gave you
    gcal.py connect                opens the browser to grant access, waits for the answer
    gcal.py disconnect             forgets the access (the client stays)
    gcal.py calendars              [{"id", "name", "color", "primary"}] you can write to
    gcal.py add JSON               creates an event; JSON fields:
        calendar     calendar id ("primary" by default)
        title        text
        allDay       bool
        start, end   "2026-09-27T18:00" (local time) or "2026-09-27" (all day; end inclusive)
        repeat       {"freq": "DAILY|WEEKLY|MONTHLY|YEARLY", "interval": n, "days": ["MO", …],
                      "count": n, "until": "2026-12-31"}   (optional)
        color        Google event colour id "1"…"11" (optional: the calendar's colour)
        location, description   text (optional)
        reminders    [minutes, …] popups before the start (optional: the calendar's defaults;
                     [] = none)
      → {"id", "link"}
    gcal.py get CAL UID ORIGINAL this|all
                                   an event as the form's fields (+ "id"), found by its iCal UID:
                                   "all" = the event (the whole series), "this" = the occurrence
                                   starting at ORIGINAL (20260927T170000Z, or 20260927 all day)
    gcal.py update CAL ID JSON     changes an event (fields as for add; emptied ones are cleared)
    gcal.py delete CAL ID          deletes an event (an occurrence id deletes only that one)

No dependencies outside Python's standard library.
"""
import base64
import hashlib
import http.server
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta
from typing import NoReturn

HOME = os.path.expanduser("~")
DIR = os.path.join(os.environ.get("XDG_DATA_HOME", f"{HOME}/.local/share"), "quickshell", "google")
CLIENT = os.path.join(DIR, "client.json")
TOKEN = os.path.join(DIR, "token.json")
SCOPES = [
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
]
API = "https://www.googleapis.com/calendar/v3"


def out(obj):
    print(json.dumps(obj, ensure_ascii=False))


def fail(msg) -> NoReturn:
    out({"error": msg})
    sys.exit(1)


def write_private(path, data):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def client():
    c = read_json(CLIENT)
    c = (c or {}).get("installed") or (c or {}).get("web")
    if not c or "client_id" not in c:
        fail("No Google OAuth client yet: add the client file first")
    return c


def post_form(url, fields):
    data = urllib.parse.urlencode(fields).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            detail = json.load(e).get("error_description") or e.reason
        except Exception:
            detail = e.reason
        fail(f"Google refused: {detail}")
    except urllib.error.URLError as e:
        fail(f"No connection to Google ({e.reason})")


def access_token():
    tok = read_json(TOKEN)
    if not tok or "refresh_token" not in tok:
        fail("Not connected to Google yet")
    if tok.get("access_token") and tok.get("expires_at", 0) > time.time() + 60:
        return tok["access_token"]
    c = client()
    new = post_form("https://oauth2.googleapis.com/token", {
        "client_id": c["client_id"],
        "client_secret": c.get("client_secret", ""),
        "refresh_token": tok["refresh_token"],
        "grant_type": "refresh_token",
    })
    tok["access_token"] = new["access_token"]
    tok["expires_at"] = time.time() + int(new.get("expires_in", 3600))
    write_private(TOKEN, tok)
    return tok["access_token"]


def api(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {access_token()}",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = r.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as e:
        try:
            detail = json.load(e)["error"]["message"]
        except Exception:
            detail = e.reason
        fail(f"Google refused: {detail}")
    except urllib.error.URLError as e:
        fail(f"No connection to Google ({e.reason})")


# --- Commands --------------------------------------------------------------------------------

def cmd_status():
    tok = read_json(TOKEN)
    c = read_json(CLIENT)
    out({"client": bool(c and ((c.get("installed") or c.get("web") or {}).get("client_id"))),
         "connected": bool(tok and tok.get("refresh_token"))})


def cmd_set_client(path):
    c = read_json(os.path.expanduser(path))
    if not c or not (c.get("installed") or c.get("web") or {}).get("client_id"):
        fail("That is not a Google OAuth client file (it should hold \"installed\": {\"client_id\": …})")
    write_private(CLIENT, c)
    out({"ok": True})


def cmd_connect():
    """Installed-app OAuth with PKCE: a one-shot HTTP server on 127.0.0.1 receives the answer."""
    c = client()
    verifier = base64.urlsafe_b64encode(secrets.token_bytes(48)).rstrip(b"=").decode()
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [""])[0] != state:
                self.send_response(400)
                self.end_headers()
                return
            result.update({k: v[0] for k, v in q.items()})
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            ok = "code" in result
            self.wfile.write(("<html><body style='font-family:sans-serif;padding:3em'><h2>"
                              + ("Connected. You can close this tab." if ok else "Access was not granted.")
                              + "</h2></body></html>").encode())

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}"
    url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": c["client_id"], "redirect_uri": redirect, "response_type": "code",
        "scope": " ".join(SCOPES), "code_challenge": challenge, "code_challenge_method": "S256",
        "access_type": "offline", "prompt": "consent", "state": state,
    })
    opener = shutil.which("xdg-open")
    if opener:
        subprocess.Popen([opener, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        print(url, file=sys.stderr)
    server.timeout = 1
    deadline = time.time() + 300
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()
    if "code" not in result:
        fail("Not connected: " + (result.get("error", "no answer from the browser within 5 minutes")))
    tok = post_form("https://oauth2.googleapis.com/token", {
        "client_id": c["client_id"], "client_secret": c.get("client_secret", ""),
        "code": result["code"], "code_verifier": verifier, "redirect_uri": redirect,
        "grant_type": "authorization_code",
    })
    if "refresh_token" not in tok:
        fail("Google gave no lasting access: remove the app's access in your Google account and connect again")
    write_private(TOKEN, {"refresh_token": tok["refresh_token"], "access_token": tok["access_token"],
                          "expires_at": time.time() + int(tok.get("expires_in", 3600))})
    out({"ok": True})


def cmd_disconnect():
    try:
        os.remove(TOKEN)
    except FileNotFoundError:
        pass
    out({"ok": True})


def cmd_calendars():
    items = api("GET", "/users/me/calendarList?minAccessRole=writer").get("items", [])
    items.sort(key=lambda c: (not c.get("primary", False), c.get("summary", "").lower()))
    out([{"id": c["id"], "name": c.get("summaryOverride") or c.get("summary", c["id"]),
          "color": c.get("backgroundColor", ""), "primary": c.get("primary", False)} for c in items])


def local_zone_name():
    tz = os.environ.get("TZ", "").lstrip(":")
    if tz:
        return tz
    try:
        target = os.path.realpath("/etc/localtime")
        return target.split("/zoneinfo/", 1)[1]
    except (OSError, IndexError):
        return "UTC"


def parse_event(raw):
    try:
        return json.loads(raw)
    except ValueError:
        fail("Bad event data")


def build_body(e, editing=False):
    """Google's event body from the form's fields. Editing: emptied fields are cleared too."""
    title = str(e.get("title", "")).strip()
    if not title:
        fail("The event needs a title")
    zone = local_zone_name()
    if e.get("allDay"):
        try:
            first = date.fromisoformat(e["start"][:10])
            last = date.fromisoformat((e.get("end") or e["start"])[:10])
        except (KeyError, ValueError):
            fail("Dates must look like 2026-09-27")
        if last < first:
            fail("The event ends before it starts")
        start, end = {"date": first.isoformat()}, {"date": (last + timedelta(days=1)).isoformat()}
    else:
        try:
            s = datetime.fromisoformat(e["start"])
            t = datetime.fromisoformat(e["end"]) if e.get("end") else s + timedelta(hours=1)
        except (KeyError, ValueError):
            fail("Times must look like 2026-09-27T18:00")
        if t <= s:
            fail("The event ends before it starts")
        start = {"dateTime": s.isoformat(timespec="seconds"), "timeZone": zone}
        end = {"dateTime": t.isoformat(timespec="seconds"), "timeZone": zone}
    body = {"summary": title, "start": start, "end": end}
    for k_in, k_out in (("location", "location"), ("description", "description")):
        if str(e.get(k_in, "")).strip() or editing:
            body[k_out] = str(e.get(k_in, "")).strip()
    if e.get("color") or editing:
        body["colorId"] = str(e.get("color") or "") or None
    if isinstance(e.get("reminders"), list):
        body["reminders"] = {"useDefault": False,
                             "overrides": [{"method": "popup", "minutes": int(m)} for m in e["reminders"][:5]]}
    elif editing:
        body["reminders"] = {"useDefault": True}
    rep = e.get("repeat")
    if rep and rep.get("freq") in ("DAILY", "WEEKLY", "MONTHLY", "YEARLY"):
        parts = [f"FREQ={rep['freq']}"]
        if int(rep.get("interval", 1) or 1) > 1:
            parts.append(f"INTERVAL={int(rep['interval'])}")
        if rep["freq"] == "WEEKLY" and rep.get("days"):
            parts.append("BYDAY=" + ",".join(d for d in rep["days"] if d in ("MO", "TU", "WE", "TH", "FR", "SA", "SU")))
        if rep.get("count"):
            parts.append(f"COUNT={int(rep['count'])}")
        elif rep.get("until"):
            try:
                parts.append("UNTIL=" + date.fromisoformat(rep["until"][:10]).strftime("%Y%m%d") + "T235959Z")
            except ValueError:
                fail("The repeat end date must look like 2026-12-31")
        body["recurrence"] = ["RRULE:" + ";".join(parts)]
    elif editing and "repeat" in e:
        body["recurrence"] = []
    return body


def cal_path(calendar):
    return "/calendars/" + urllib.parse.quote(str(calendar or "primary"), safe="")


def cmd_add(raw):
    e = parse_event(raw)
    made = api("POST", cal_path(e.get("calendar")) + "/events", build_body(e))
    out({"id": made.get("id", ""), "link": made.get("htmlLink", "")})


def find_event(calendar, uid, original="", only_this=False):
    """The event behind an iCal UID (the series for repeating ones), or with `only_this` the one
    occurrence starting at `original` (as the iCal feed names it: 20260927T170000Z or 20260927)."""
    items = api("GET", cal_path(calendar) + "/events?" + urllib.parse.urlencode({"iCalUID": uid, "showDeleted": "false"})).get("items", [])
    series = next((i for i in items if not i.get("recurringEventId")), None) or (items[0] if items else None)
    if series is None:
        fail("That event is not in this Google calendar (read-only, or already deleted)")
    if only_this and series.get("recurrence"):
        return api("GET", cal_path(calendar) + "/events/" + urllib.parse.quote(f"{series['id']}_{original}", safe=""))
    return series


def form_fields(ev):
    """Google's event → the form's fields (dates and times local)."""
    all_day = "date" in ev.get("start", {})
    if all_day:
        start = ev["start"]["date"]
        end = (date.fromisoformat(ev["end"]["date"]) - timedelta(days=1)).isoformat()
    else:
        start = datetime.fromisoformat(ev["start"]["dateTime"]).astimezone().strftime("%Y-%m-%dT%H:%M")
        end = datetime.fromisoformat(ev["end"]["dateTime"]).astimezone().strftime("%Y-%m-%dT%H:%M")
    rep = None
    for rule in ev.get("recurrence", []):
        if rule.startswith("RRULE:"):
            parts = dict(p.split("=", 1) for p in rule[6:].split(";") if "=" in p)
            rep = {"freq": parts.get("FREQ", ""), "interval": int(parts.get("INTERVAL", 1)),
                   "days": parts["BYDAY"].split(",") if "BYDAY" in parts else [],
                   "count": int(parts["COUNT"]) if "COUNT" in parts else 0,
                   "until": (parts["UNTIL"][:4] + "-" + parts["UNTIL"][4:6] + "-" + parts["UNTIL"][6:8]) if "UNTIL" in parts else ""}
    rem = ev.get("reminders", {})
    return {"id": ev["id"], "title": ev.get("summary", ""), "allDay": all_day, "start": start, "end": end,
            "location": ev.get("location", ""), "description": ev.get("description", ""), "color": ev.get("colorId", ""),
            "repeat": rep, "reminders": None if rem.get("useDefault", True) else [o["minutes"] for o in rem.get("overrides", [])],
            "recurringEventId": ev.get("recurringEventId", "")}


def cmd_get(calendar, uid, original, scope):
    out(form_fields(find_event(calendar, uid, original, scope == "this")))


def cmd_update(calendar, event_id, raw):
    e = parse_event(raw)
    body = build_body(e, editing=True)
    # One occurrence of a repeating event cannot carry its own repeat rule.
    if "_" in event_id:
        body.pop("recurrence", None)
    made = api("PATCH", cal_path(calendar) + "/events/" + urllib.parse.quote(event_id, safe=""), body)
    out({"id": made.get("id", ""), "link": made.get("htmlLink", "")})


def cmd_delete(calendar, event_id):
    api("DELETE", cal_path(calendar) + "/events/" + urllib.parse.quote(event_id, safe=""))
    out({"deleted": event_id})


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"
    if cmd == "status":
        cmd_status()
    elif cmd == "set-client" and len(args) == 2:
        cmd_set_client(args[1])
    elif cmd == "connect":
        cmd_connect()
    elif cmd == "disconnect":
        cmd_disconnect()
    elif cmd == "calendars":
        cmd_calendars()
    elif cmd == "add" and len(args) == 2:
        cmd_add(args[1])
    elif cmd == "get" and len(args) == 5:
        cmd_get(args[1], args[2], args[3], args[4])
    elif cmd == "update" and len(args) == 4:
        cmd_update(args[1], args[2], args[3])
    elif cmd == "delete" and len(args) == 3:
        cmd_delete(args[1], args[2])
    else:
        fail("Usage: gcal.py status | set-client FILE | connect | disconnect | calendars | add JSON"
             " | get CALENDAR UID ORIGINAL_START this|all | update CALENDAR EVENT_ID JSON | delete CALENDAR EVENT_ID")


if __name__ == "__main__":
    main()
