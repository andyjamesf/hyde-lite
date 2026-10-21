"""tools/qml-lint.baseline: well-formed, and every accepted increase is on record.

The baseline only ever goes down, except for an increase the owner accepted. Such an increase is written in the
baseline itself as a line

    #! accepted DATE SHELL CATEGORY FROM->TO FILE[:LINE]: why it is inherent; how it could go

and this test keeps the record and the numbers from drifting apart.
"""
import datetime
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = ROOT / "tools/qml-lint.baseline"
ZERO = {"unused-imports", "id-shadows-member", "required"}
RECORD = re.compile(r"^#! accepted (\d{4}-\d{2}-\d{2}) (\S+) (\S+) (\d+)->(\d+) (\S+?)(?::(\d+))?: (.{20,})$")


def read():
    counts, records, bad = {}, [], []
    for n, line in enumerate(BASELINE.read_text().splitlines(), 1):
        if line.startswith("#!"):
            m = RECORD.match(line)
            records.append((n, m)) if m else bad.append(f"line {n}: not a valid record: {line[:80]}")
        elif line.startswith("#") or not line.strip():
            continue
        else:
            m = re.fullmatch(r"(\S+) (\d+) ([a-z-]+)", line)
            if not m:
                bad.append(f"line {n}: not 'SHELL COUNT CATEGORY': {line[:80]}")
                continue
            key = (m.group(1), m.group(3))
            if key in counts:
                bad.append(f"line {n}: {key} is listed twice")
            counts[key] = int(m.group(2))
    return counts, records, bad


class Baseline(unittest.TestCase):
    def test_well_formed_and_no_zero_category(self):
        counts, _, bad = read()
        self.assertEqual(bad, [])
        self.assertTrue(counts)
        self.assertEqual({c for _, c in counts} & ZERO, set(), "a category that must stay at zero is in the baseline")
        self.assertEqual({s for s, _ in counts}, {"bar", "island"})

    def test_every_accepted_increase_matches_the_numbers(self):
        counts, records, _ = read()
        for n, m in records:
            date, shell, cat, frm, to, path, line, why = m.groups()
            where = f"record on line {n} ({shell} {cat})"
            self.assertIn((shell, cat), counts, f"{where}: no such baseline entry")
            frm, to = int(frm), int(to)
            self.assertGreater(to, frm, f"{where}: an accepted increase must go up")
            self.assertLessEqual(counts[(shell, cat)], to,
                                 f"{where}: the baseline ({counts[(shell, cat)]}) is above the accepted {to}; "
                                 "raise it only with a new record")
            self.assertGreaterEqual(counts[(shell, cat)], frm,
                                    f"{where}: the baseline fell below {frm}, so this note is obsolete: remove it")
            self.assertTrue((ROOT / path).is_file(), f"{where}: {path} does not exist (moved or deleted? update the note)")
            datetime.date.fromisoformat(date)  # a real date

    def test_no_two_records_for_the_same_entry(self):
        _, records, _ = read()
        keys = [(m.group(2), m.group(3)) for _, m in records]
        self.assertEqual(len(keys), len(set(keys)))


if __name__ == "__main__":
    unittest.main()
