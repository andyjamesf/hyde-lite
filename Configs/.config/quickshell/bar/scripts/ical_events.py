#!/usr/bin/env python3
"""Calendar events (Google Calendar or any other with an iCal address, or a local .ics file) for the
shells (the HyDE Quickshell shell and the Morphing Island share it).

Reads the list of calendars from ~/.local/share/quickshell/calendars.json (outside the dotfiles
repository, because private iCal addresses grant read access to the calendar):

    {
      "calendars": [
        { "name": "Personal", "url": "https://calendar.google.com/calendar/ical/.../basic.ics",
          "color": "#8ab4f8" },
        { "name": "Holidays", "path": "~/.local/share/quickshell/calendars/holidays.ics",
          "color": "#81c995" }
      ]
    }

"url" may be https://, http:// or webcal:// (read as https); "path" is a local .ics file ("~"
allowed; a file:// url works too).

Downloads each calendar, expands recurring events over the window [today - 45 days,
today + 120 days] and writes ~/.cache/quickshell/calendar.json (atomically), which the shell
watches. If a calendar fails (no network), the events from the last good read are kept.

No dependencies outside the standard library: the iCal parser and the RRULE expansion cover what
Google produces (DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY,
BYMONTH, EXDATE and exceptions with RECURRENCE-ID).
"""
import json
import os
import re
import sys
import tempfile
import urllib.parse
import urllib.request
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

HOME = os.path.expanduser("~")
CONFIG = os.path.join(os.environ.get("XDG_DATA_HOME", f"{HOME}/.local/share"), "quickshell", "calendars.json")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", f"{HOME}/.cache"), "quickshell", "calendar.json")


def local_zone():
    """System time zone with its daylight saving rules (not just the current offset)."""
    try:
        if os.environ.get("TZ"):
            return ZoneInfo(os.environ["TZ"].lstrip(":"))
        with open("/etc/localtime", "rb") as f:
            return ZoneInfo.from_file(f)
    except Exception:
        return datetime.now().astimezone().tzinfo


LOCAL = local_zone()
WEEKDAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
MAX_STEPS = 20000


# --- iCal -------------------------------------------------------------------------------------

def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def split_prop(line):
    """'DTSTART;TZID=Europe/Lisbon:20260101T100000' -> ('DTSTART', {'TZID': ...}, '2026...')."""
    in_quotes = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ":" and not in_quotes:
            head, value = line[:i], line[i + 1:]
            break
    else:
        return None
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def unescape(s):
    return s.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def parse_dt(value, params):
    """Returns (timezone-aware datetime | date, all_day)."""
    value = value.strip()
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        return date(int(value[:4]), int(value[4:6]), int(value[6:8])), True
    dt = datetime.strptime(value[:15], "%Y%m%dT%H%M%S")
    if value.endswith("Z"):
        return dt.replace(tzinfo=UTC), False
    tzid = params.get("TZID")
    if tzid:
        try:
            return dt.replace(tzinfo=ZoneInfo(tzid)), False
        except Exception:
            pass
    return dt.replace(tzinfo=LOCAL), False


def parse_duration(value):
    m = re.fullmatch(r"([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?", value.strip())
    if not m:
        return timedelta(0)
    sign = -1 if m.group(1) == "-" else 1
    w, d, h, mi, s = (int(x or 0) for x in m.groups()[1:])
    return sign * timedelta(weeks=w, days=d, hours=h, minutes=mi, seconds=s)


def parse_events(text):
    events, current = [], None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            current = {"exdates": set()}
        elif line == "END:VEVENT":
            if current is not None and "start" in current:
                events.append(current)
            current = None
        elif current is not None:
            prop = split_prop(line)
            if not prop:
                continue
            name, params, value = prop
            if name == "SUMMARY":
                current["title"] = unescape(value)
            elif name == "LOCATION":
                current["location"] = unescape(value)
            elif name == "UID":
                current["uid"] = value
            elif name == "STATUS":
                current["status"] = value.upper()
            elif name == "DTSTART":
                current["start"], current["allDay"] = parse_dt(value, params)
            elif name == "DTEND":
                current["end"], _ = parse_dt(value, params)
            elif name == "DURATION":
                current["duration"] = parse_duration(value)
            elif name == "RRULE":
                current["rrule"] = dict(p.split("=", 1) for p in value.split(";") if "=" in p)
            elif name == "EXDATE":
                for v in value.split(","):
                    current["exdates"].add(key_of(parse_dt(v, params)[0]))
            elif name == "RECURRENCE-ID":
                current["recurrenceId"] = key_of(parse_dt(value, params)[0])
    return events


def key_of(d):
    """Comparable key of an occurrence (the instant in UTC, or the date for all-day events)."""
    if isinstance(d, datetime):
        return d.astimezone(UTC).strftime("%Y%m%dT%H%M%S")
    return d.strftime("%Y%m%d")


# --- Recurrence -------------------------------------------------------------------------------

def add_months(d, months):
    y, m = divmod(d.month - 1 + months, 12)
    return y + d.year, m + 1


def nth_weekday(year, month, weekday, n):
    """n-th weekday of the month (negative n counts from the end); None if it doesn't exist."""
    last = (date(year + (month == 12), month % 12 + 1, 1) - timedelta(days=1)).day
    days = [date(year, month, d) for d in range(1, last + 1) if date(year, month, d).weekday() == weekday]
    try:
        return days[n - 1] if n > 0 else days[n]
    except IndexError:
        return None


def parse_byday(value):
    out = []
    for item in value.split(","):
        m = re.fullmatch(r"([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)", item.strip())
        if m:
            out.append((int(m.group(1)) if m.group(1) else 0, WEEKDAYS.index(m.group(2))))
    return out


def occurrences(start, rule, window_end):
    """Start dates (of the same type as `start`) generated by the RRULE, in order."""
    freq = rule.get("FREQ", "DAILY")
    interval = int(rule.get("INTERVAL", 1))
    count = int(rule["COUNT"]) if "COUNT" in rule else None
    until = None
    if "UNTIL" in rule:
        until, _ = parse_dt(rule["UNTIL"], {})
    byday = parse_byday(rule["BYDAY"]) if "BYDAY" in rule else []
    bymonthday = [int(x) for x in rule["BYMONTHDAY"].split(",")] if "BYMONTHDAY" in rule else []
    bymonth = [int(x) for x in rule["BYMONTH"].split(",")] if "BYMONTH" in rule else []
    is_dt = isinstance(start, datetime)

    def at(d):
        return datetime.combine(d, start.timetz()) if is_dt else d

    def past_until(x):
        if until is None:
            return False
        if isinstance(x, datetime) and isinstance(until, datetime):
            return x > until
        return (x.date() if isinstance(x, datetime) else x) > (until.date() if isinstance(until, datetime) else until)

    def past_window(x):
        return (x.date() if isinstance(x, datetime) else x) > window_end

    produced, step = 0, 0
    start_day = start.date() if is_dt else start
    while step < MAX_STEPS:
        if freq == "DAILY":
            candidates = [start_day + timedelta(days=step * interval)]
        elif freq == "WEEKLY":
            week0 = start_day - timedelta(days=start_day.weekday()) + timedelta(weeks=step * interval)
            days = sorted(wd for _, wd in byday) if byday else [start_day.weekday()]
            candidates = [week0 + timedelta(days=wd) for wd in days]
        elif freq == "MONTHLY":
            y, m = add_months(start_day, step * interval)
            candidates = []
            if byday:
                for n, wd in byday:
                    if n:
                        d = nth_weekday(y, m, wd, n)
                        if d:
                            candidates.append(d)
                    else:
                        candidates += [d for d in (nth_weekday(y, m, wd, k) for k in range(1, 6)) if d]
            else:
                for md in bymonthday or [start_day.day]:
                    try:
                        candidates.append(date(y, m, md) if md > 0 else nth_last_day(y, m, md))
                    except ValueError:
                        pass
        elif freq == "YEARLY":
            y = start_day.year + step * interval
            candidates = []
            for mo in bymonth or [start_day.month]:
                if byday:
                    candidates += [d for n, wd in byday if (d := nth_weekday(y, mo, wd, n or 1))]
                else:
                    try:
                        candidates.append(date(y, mo, start_day.day))
                    except ValueError:
                        pass
        else:
            return
        step += 1
        for d in sorted(candidates):
            if d < start_day or (bymonth and d.month not in bymonth and freq != "YEARLY"):
                continue
            x = at(d)
            if past_until(x) or past_window(x):
                return
            yield x
            produced += 1
            if count is not None and produced >= count:
                return


def nth_last_day(y, m, md):
    last = (date(y + (m == 12), m % 12 + 1, 1) - timedelta(days=1)).day
    return date(y, m, last + md + 1)


# --- Output -----------------------------------------------------------------------------------

def to_local(d):
    return d.astimezone(LOCAL) if isinstance(d, datetime) else d


def google_calendar_id(cal):
    """The Google calendar id in a Google "secret address in iCal format", or "" (other links)."""
    src = cal.get("url") or ""
    m = re.search(r"calendar\.google\.com/calendar/ical/([^/]+)/", src)
    return urllib.parse.unquote(m.group(1)) if m else ""


def expand(events, window_start, window_end, cal):
    google = google_calendar_id(cal)
    overrides = {(e.get("uid"), e["recurrenceId"]): e for e in events if "recurrenceId" in e}
    out = []
    for e in events:
        if "recurrenceId" in e or e.get("status") == "CANCELLED":
            continue
        start = e["start"]
        if "end" in e:
            length = e["end"] - start
        elif "duration" in e:
            length = e["duration"]
        else:
            length = timedelta(days=1) if e["allDay"] else timedelta(0)
        starts = occurrences(start, e["rrule"], window_end) if "rrule" in e else [start]
        for s in starts:
            k = key_of(s)
            # Google names one occurrence of a repeating event "<id>_<original start>".
            original = k + ("Z" if isinstance(s, datetime) else "")
            if k in e["exdates"]:
                continue
            item = overrides.get((e.get("uid"), k))
            if item is not None:
                if item.get("status") == "CANCELLED":
                    continue
                s = item["start"]
                end = item.get("end", s + length)
                title, location = item.get("title", e.get("title", "")), item.get("location", e.get("location", ""))
            else:
                end = s + length
                title, location = e.get("title", ""), e.get("location", "")
            day_end = to_local(end)
            day_end = (day_end.date() if isinstance(day_end, datetime) else day_end)
            if day_end < window_start:
                continue
            ls, le = to_local(s), to_local(end)
            out.append({
                "title": title or "(untitled)",
                "location": location,
                "allDay": e["allDay"],
                "start": ls.isoformat(),
                "end": le.isoformat(),
                "calendar": cal.get("name", ""),
                "color": cal.get("color", ""),
                # Editing and deleting (Google calendars only): scripts/gcal.py finds it by these.
                "uid": e.get("uid", ""),
                "recurring": "rrule" in e,
                "originalStart": original,
                "googleCalendar": google,
            })
    return out


def read_calendar(cal):
    """The calendar's iCal text, from its local file or its address."""
    src = (cal.get("path") or cal.get("url") or "").strip()
    if src.startswith("file://"):
        src = urllib.parse.unquote(src[len("file://"):])
    if src.startswith(("/", "~")):
        with open(os.path.expanduser(src), encoding="utf-8", errors="replace") as f:
            return f.read()
    if src.startswith("webcal://"):
        src = "https://" + src[len("webcal://"):]
    req = urllib.request.Request(src, headers={"User-Agent": "quickshell-calendar"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode("utf-8", "replace")


def main():
    if not os.path.exists(CONFIG):
        print(f"No calendars: create {CONFIG}", file=sys.stderr)
        return 0
    with open(CONFIG) as fh:
        calendars = json.load(fh).get("calendars", [])
    try:
        with open(CACHE) as fh:
            previous = json.load(fh)
    except Exception:
        previous = {"events": []}

    today = date.today()
    window_start, window_end = today - timedelta(days=45), today + timedelta(days=120)
    events, errors = [], []
    for cal in calendars:
        try:
            events += expand(parse_events(read_calendar(cal)), window_start, window_end, cal)
        except Exception as ex:
            errors.append(f"{cal.get('name', '?')}: {ex}")
            events += [e for e in previous.get("events", []) if e.get("calendar") == cal.get("name")]

    events.sort(key=lambda e: e["start"])
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(CACHE))
    with os.fdopen(fd, "w") as f:
        json.dump({"updated": datetime.now(LOCAL).isoformat(), "errors": errors, "events": events}, f, ensure_ascii=False)
    os.replace(tmp, CACHE)
    for e in errors:
        print(e, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
