"""Display-free tests for the iCal reader the two shells share (scripts/ical_events.py).

Covers the parser, the RRULE expansion (the part most likely to be subtly wrong), expand() with exceptions
and cancellations, and main() end to end against a local .ics file. The clock zone is pinned to UTC. Run:

    python3 -I tools/tests/test_ical_events.py
"""
import contextlib
import importlib.util
import io
import json
import os
import pathlib
import tempfile
import unittest
from datetime import UTC, date, datetime, timedelta
from unittest import mock

REPO = pathlib.Path(__file__).resolve().parents[2]
ISLAND = REPO / "Configs/.config/quickshell/island/scripts/ical_events.py"
BAR = REPO / "Configs/.config/quickshell/bar/scripts/ical_events.py"


def load(path=ISLAND):
    spec = importlib.util.spec_from_file_location("ical_events_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        patcher = mock.patch.dict(os.environ, {"HOME": self.tmp.name, "TZ": "UTC"})
        patcher.start()
        self.addCleanup(patcher.stop)
        for var in ("XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.environ.pop(var, None)
        self.m = load()

    def days(self, start, rule, until_day):
        return [x if isinstance(x, date) and not isinstance(x, datetime) else x.date()
                for x in self.m.occurrences(start, rule, until_day)]


class Parser(Base):
    def test_unfold_joins_continuation_lines(self):
        self.assertEqual(self.m.unfold("SUMMARY:Hello\r\n  world\r\nUID:1"), ["SUMMARY:Hello world", "UID:1"])

    def test_split_prop_handles_quoted_colons_and_params(self):
        name, params, value = self.m.split_prop('DTSTART;TZID="Europe/Lisbon":20260101T100000')
        self.assertEqual((name, params, value), ("DTSTART", {"TZID": "Europe/Lisbon"}, "20260101T100000"))
        name, params, value = self.m.split_prop('ATTENDEE;CN="A: B":mailto:a@example.org')
        self.assertEqual((name, params["CN"], value), ("ATTENDEE", "A: B", "mailto:a@example.org"))
        self.assertIsNone(self.m.split_prop("no colon here"))

    def test_unescape(self):
        self.assertEqual(self.m.unescape(r"a\, b\; c\nd\\e"), "a, b; c\nd\\e")

    def test_parse_dt_forms(self):
        self.assertEqual(self.m.parse_dt("20260315", {}), (date(2026, 3, 15), True))
        self.assertEqual(self.m.parse_dt("20260315", {"VALUE": "DATE"}), (date(2026, 3, 15), True))
        dt, all_day = self.m.parse_dt("20260315T101500Z", {})
        self.assertEqual((dt, all_day), (datetime(2026, 3, 15, 10, 15, tzinfo=UTC), False))
        dt, _ = self.m.parse_dt("20260315T101500", {"TZID": "America/New_York"})
        self.assertEqual(dt.utcoffset(), timedelta(hours=-4))  # DST in force on 15 March 2026
        dt, _ = self.m.parse_dt("20260315T101500", {"TZID": "Not/AZone"})
        self.assertEqual(dt.utcoffset(), timedelta(0))  # unknown zone falls back to the local one (UTC here)

    def test_parse_duration(self):
        p = self.m.parse_duration
        self.assertEqual(p("P1DT2H30M"), timedelta(days=1, hours=2, minutes=30))
        self.assertEqual(p("PT45M"), timedelta(minutes=45))
        self.assertEqual(p("P2W"), timedelta(weeks=2))
        self.assertEqual(p("-PT15M"), timedelta(minutes=-15))
        self.assertEqual(p("garbage"), timedelta(0))

    def test_parse_events_reads_the_fields_we_use(self):
        text = "\r\n".join([
            "BEGIN:VCALENDAR", "BEGIN:VEVENT", "UID:abc", "SUMMARY:Lunch\\, team", "LOCATION:Cafe",
            "DTSTART:20260310T120000Z", "DTEND:20260310T130000Z", "STATUS:confirmed",
            "RRULE:FREQ=WEEKLY;BYDAY=TU", "EXDATE:20260317T120000Z,20260324T120000Z",
            "END:VEVENT", "BEGIN:VEVENT", "SUMMARY:No start", "END:VEVENT", "END:VCALENDAR"])
        events = self.m.parse_events(text)
        self.assertEqual(len(events), 1)  # the event without DTSTART is dropped
        e = events[0]
        self.assertEqual((e["uid"], e["title"], e["location"], e["status"]), ("abc", "Lunch, team", "Cafe", "CONFIRMED"))
        self.assertEqual(e["rrule"], {"FREQ": "WEEKLY", "BYDAY": "TU"})
        self.assertEqual(e["exdates"], {"20260317T120000", "20260324T120000"})


class Recurrence(Base):
    def test_nth_weekday(self):
        self.assertEqual(self.m.nth_weekday(2026, 3, 1, 2), date(2026, 3, 10))    # second Tuesday
        self.assertEqual(self.m.nth_weekday(2026, 3, 4, -1), date(2026, 3, 27))   # last Friday
        self.assertIsNone(self.m.nth_weekday(2026, 2, 0, 5))                       # no 5th Monday in Feb 2026

    def test_nth_last_day(self):
        self.assertEqual(self.m.nth_last_day(2026, 2, -1), date(2026, 2, 28))
        self.assertEqual(self.m.nth_last_day(2024, 2, -1), date(2024, 2, 29))
        self.assertEqual(self.m.nth_last_day(2026, 12, -2), date(2026, 12, 30))

    def test_daily_interval_and_count(self):
        got = self.days(date(2026, 3, 1), {"FREQ": "DAILY", "INTERVAL": "3", "COUNT": "4"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, d) for d in (1, 4, 7, 10)])

    def test_until_is_inclusive_and_window_end_stops_the_series(self):
        got = self.days(date(2026, 3, 1), {"FREQ": "DAILY", "UNTIL": "20260303"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 1), date(2026, 3, 2), date(2026, 3, 3)])
        got = self.days(date(2026, 3, 1), {"FREQ": "DAILY"}, date(2026, 3, 4))
        self.assertEqual(got[-1], date(2026, 3, 4))

    def test_weekly_byday_keeps_week_order(self):
        # 2026-03-02 is a Monday
        got = self.days(date(2026, 3, 2), {"FREQ": "WEEKLY", "BYDAY": "WE,MO", "COUNT": "5"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 2), date(2026, 3, 4), date(2026, 3, 9), date(2026, 3, 11), date(2026, 3, 16)])

    def test_weekly_every_other_week_without_byday_uses_the_start_weekday(self):
        got = self.days(date(2026, 3, 4), {"FREQ": "WEEKLY", "INTERVAL": "2", "COUNT": "3"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 4), date(2026, 3, 18), date(2026, 4, 1)])

    def test_weekly_byday_earlier_in_the_start_week_is_not_produced(self):
        # start on Wednesday with BYDAY=MO,WE: the Monday before the start does not count
        got = self.days(date(2026, 3, 4), {"FREQ": "WEEKLY", "BYDAY": "MO,WE", "COUNT": "3"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 4), date(2026, 3, 9), date(2026, 3, 11)])

    def test_monthly_second_tuesday_and_last_friday(self):
        got = self.days(date(2026, 3, 10), {"FREQ": "MONTHLY", "BYDAY": "2TU", "COUNT": "3"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 10), date(2026, 4, 14), date(2026, 5, 12)])
        got = self.days(date(2026, 3, 27), {"FREQ": "MONTHLY", "BYDAY": "-1FR", "COUNT": "3"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 3, 27), date(2026, 4, 24), date(2026, 5, 29)])

    def test_monthly_on_the_31st_skips_short_months(self):
        got = self.days(date(2026, 1, 31), {"FREQ": "MONTHLY", "COUNT": "4"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 1, 31), date(2026, 3, 31), date(2026, 5, 31), date(2026, 7, 31)])

    def test_monthly_last_day(self):
        got = self.days(date(2026, 1, 31), {"FREQ": "MONTHLY", "BYMONTHDAY": "-1", "COUNT": "3"}, date(2027, 1, 1))
        self.assertEqual(got, [date(2026, 1, 31), date(2026, 2, 28), date(2026, 3, 31)])

    def test_yearly_leap_day_only_in_leap_years(self):
        got = self.days(date(2024, 2, 29), {"FREQ": "YEARLY", "COUNT": "3"}, date(2040, 1, 1))
        self.assertEqual(got, [date(2024, 2, 29), date(2028, 2, 29), date(2032, 2, 29)])

    def test_yearly_bymonth(self):
        got = self.days(date(2026, 3, 5), {"FREQ": "YEARLY", "BYMONTH": "3,9", "COUNT": "4"}, date(2040, 1, 1))
        self.assertEqual(got, [date(2026, 3, 5), date(2026, 9, 5), date(2027, 3, 5), date(2027, 9, 5)])

    def test_unknown_frequency_yields_nothing(self):
        self.assertEqual(list(self.m.occurrences(date(2026, 3, 1), {"FREQ": "SECONDLY"}, date(2027, 1, 1))), [])

    def test_datetimes_keep_their_time_of_day(self):
        start = datetime(2026, 3, 1, 9, 30, tzinfo=UTC)
        got = list(self.m.occurrences(start, {"FREQ": "DAILY", "COUNT": "2"}, date(2027, 1, 1)))
        self.assertEqual(got, [start, start + timedelta(days=1)])

    def test_runaway_rule_is_bounded(self):
        # an impossible rule must end (MAX_STEPS), not loop for ever
        rule = {"FREQ": "MONTHLY", "BYMONTHDAY": "31", "BYMONTH": "2"}
        self.assertEqual(list(self.m.occurrences(date(2026, 1, 31), rule, date(9999, 1, 1))), [])


def vevent(**kw):
    lines = ["BEGIN:VEVENT"] + [f"{k}:{v}" for k, v in kw.items()] + ["END:VEVENT"]
    return "\r\n".join(lines)


class Expand(Base):
    window = (date(2026, 3, 1), date(2026, 4, 30))

    def run_expand(self, *vevents, cal=None):
        text = "BEGIN:VCALENDAR\r\n" + "\r\n".join(vevents) + "\r\nEND:VCALENDAR"
        return self.m.expand(self.m.parse_events(text), *self.window, cal or {"name": "T", "color": "#fff"})

    def test_single_event(self):
        out = self.run_expand(vevent(UID="a", SUMMARY="One", DTSTART="20260310T100000Z", DTEND="20260310T110000Z"))
        self.assertEqual(len(out), 1)
        e = out[0]
        self.assertEqual((e["title"], e["calendar"], e["color"], e["allDay"], e["recurring"]), ("One", "T", "#fff", False, False))
        self.assertEqual(e["start"], "2026-03-10T10:00:00+00:00")
        self.assertEqual(e["end"], "2026-03-10T11:00:00+00:00")

    def test_untitled_and_all_day_default_length(self):
        out = self.run_expand(vevent(UID="a", DTSTART="20260310"))
        self.assertEqual(out[0]["title"], "(untitled)")
        self.assertTrue(out[0]["allDay"])
        self.assertEqual(out[0]["end"], "2026-03-11")

    def test_duration_instead_of_dtend(self):
        out = self.run_expand(vevent(UID="a", DTSTART="20260310T100000Z", DURATION="PT90M"))
        self.assertEqual(out[0]["end"], "2026-03-10T11:30:00+00:00")

    def test_events_that_ended_before_the_window_are_dropped(self):
        out = self.run_expand(vevent(UID="a", DTSTART="20260101T100000Z", DTEND="20260101T110000Z"))
        self.assertEqual(out, [])

    def test_cancelled_event_is_dropped(self):
        out = self.run_expand(vevent(UID="a", DTSTART="20260310T100000Z", STATUS="CANCELLED"))
        self.assertEqual(out, [])

    def test_recurring_with_exdate_and_moved_and_cancelled_occurrences(self):
        base = vevent(UID="r", SUMMARY="Standup", DTSTART="20260302T090000Z", DTEND="20260302T091500Z",
                      RRULE="FREQ=WEEKLY;COUNT=5", EXDATE="20260309T090000Z")
        moved = vevent(UID="r", SUMMARY="Standup (moved)", **{"RECURRENCE-ID": "20260316T090000Z"},
                       DTSTART="20260316T140000Z", DTEND="20260316T141500Z")
        cancelled = vevent(UID="r", **{"RECURRENCE-ID": "20260323T090000Z"}, DTSTART="20260323T090000Z", STATUS="CANCELLED")
        out = self.run_expand(base, moved, cancelled)
        starts = [(e["title"], e["start"][:16]) for e in out]
        self.assertEqual(starts, [("Standup", "2026-03-02T09:00"), ("Standup (moved)", "2026-03-16T14:00"),
                                  ("Standup", "2026-03-30T09:00")])
        self.assertTrue(all(e["recurring"] for e in out))
        self.assertEqual(out[0]["originalStart"], "20260302T090000Z")

    def test_google_calendar_id_is_extracted_and_decoded(self):
        url = "https://calendar.google.com/calendar/ical/me%40example.org/private-abc/basic.ics"
        self.assertEqual(self.m.google_calendar_id({"url": url}), "me@example.org")
        self.assertEqual(self.m.google_calendar_id({"url": "https://example.org/x.ics"}), "")
        self.assertEqual(self.m.google_calendar_id({}), "")


class Reading(Base):
    def test_local_file_with_tilde_and_file_url(self):
        p = pathlib.Path(self.tmp.name) / "x.ics"
        p.write_text("BEGIN:VCALENDAR\nEND:VCALENDAR", encoding="utf-8")
        self.assertIn("VCALENDAR", self.m.read_calendar({"path": "~/x.ics"}))
        self.assertIn("VCALENDAR", self.m.read_calendar({"url": f"file://{p}"}))

    def test_webcal_is_read_as_https(self):
        seen = {}

        class Resp:
            def __enter__(self): return self
            def __exit__(self, *a): return False
            def read(self): return b"BEGIN:VCALENDAR"

        def fake(req, timeout):
            seen["url"] = req.full_url
            return Resp()

        with mock.patch.object(self.m.urllib.request, "urlopen", fake):
            self.assertEqual(self.m.read_calendar({"url": "webcal://example.org/c.ics"}), "BEGIN:VCALENDAR")
        self.assertEqual(seen["url"], "https://example.org/c.ics")


class MainEndToEnd(Base):
    def write_config(self, calendars):
        cfg = pathlib.Path(self.m.CONFIG)
        cfg.parent.mkdir(parents=True, exist_ok=True)
        cfg.write_text(json.dumps({"calendars": calendars}))

    def run_main(self):
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code = self.m.main()
        return code, err.getvalue()

    def test_no_config_is_not_an_error(self):
        code, err = self.run_main()
        self.assertEqual(code, 0)
        self.assertIn("No calendars", err)
        self.assertFalse(os.path.exists(self.m.CACHE))

    def test_writes_sorted_cache_and_keeps_old_events_when_a_calendar_fails(self):
        day = date.today() + timedelta(days=3)
        ics = pathlib.Path(self.tmp.name) / "a.ics"
        ics.write_text(vevent(UID="1", SUMMARY="Later", DTSTART=f"{day:%Y%m%d}T150000Z", DTEND=f"{day:%Y%m%d}T160000Z")
                       + "\n" + vevent(UID="2", SUMMARY="Earlier", DTSTART=f"{day:%Y%m%d}T080000Z", DTEND=f"{day:%Y%m%d}T090000Z"))
        ics.write_text("BEGIN:VCALENDAR\n" + ics.read_text() + "\nEND:VCALENDAR")
        missing = pathlib.Path(self.tmp.name) / "gone.ics"
        self.write_config([{"name": "A", "path": str(ics)}, {"name": "B", "path": str(missing)}])

        code, err = self.run_main()
        self.assertEqual(code, 0)
        data = json.loads(pathlib.Path(self.m.CACHE).read_text())
        self.assertEqual([e["title"] for e in data["events"]], ["Earlier", "Later"])
        self.assertEqual(len(data["errors"]), 1)
        self.assertTrue(data["errors"][0].startswith("B:"))
        self.assertIn("B:", err)

        # calendar B now has an earlier good read in the cache; when it fails again, that read is kept
        data["events"].append({"title": "From B", "calendar": "B", "start": f"{day}T10:00:00+00:00"})
        pathlib.Path(self.m.CACHE).write_text(json.dumps(data))
        self.run_main()
        titles = [e["title"] for e in json.loads(pathlib.Path(self.m.CACHE).read_text())["events"]]
        self.assertIn("From B", titles)
        self.assertEqual(os.listdir(os.path.dirname(self.m.CACHE)), ["calendar.json"])  # no temp file left behind


class Copies(unittest.TestCase):
    def test_both_shells_ship_the_same_script(self):
        self.assertEqual(ISLAND.read_bytes(), BAR.read_bytes(),
                         "the two copies of ical_events.py drifted; copy one over the other")


if __name__ == "__main__":
    unittest.main()
