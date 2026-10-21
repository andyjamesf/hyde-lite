"""services/Fuzzy.qml (shared fuzzy scoring for the launcher and every picker) run in Node from the QML source."""
import json
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import qml_js  # noqa: E402

SRC = (Path(__file__).resolve().parents[2] / "Configs/.config/quickshell/island/services/Fuzzy.qml").read_text()
# `score` reads and writes the singleton's _cache and `currentFirst` is pure: stand in for `_cache`.
PRELUDE = "\n".join([
    f"const _cache = {qml_js.extract_property(SRC, '_cache')};",
    qml_js.extract_function(SRC, "score"),
    qml_js.extract_function(SRC, "currentFirst"),
])


def run(body):
    return qml_js.run_node(f"{PRELUDE}\n{body}")


def scores(*calls):
    """calls: [(q, text, extraSeps, subBase, lengthPenalty)] -> scores, all in one process so the cache is shared."""
    padded = [list(c) + [None] * (5 - len(c)) for c in calls]
    return run(f"console.log(JSON.stringify({json.dumps(padded)}.map(a => score(a[0], a[1], a[2] ?? undefined, a[3] ?? undefined, a[4] ?? undefined))));")


@unittest.skipUnless(shutil.which("node"), "node not installed")
class Score(unittest.TestCase):
    def test_ranking_exact_prefix_word_substring_subsequence(self):
        exact, prefix, word, sub, subseq, none = scores(("firefox", "Firefox"), ("fire", "Firefox"), ("fox", "Red Fox"),
                                                        ("ire", "Firefox"), ("frx", "Firefox"), ("zzz", "Firefox"))
        self.assertEqual(exact, 120)
        self.assertTrue(100 - 20 <= prefix < 100, prefix)
        self.assertTrue(85 - 15 <= word <= 85, word)
        self.assertTrue(70 - 20 <= sub <= 70, sub)
        self.assertTrue(1 <= subseq < 50, subseq)
        self.assertEqual(none, 0)
        self.assertTrue(exact > prefix > word > sub > subseq > none, (exact, prefix, word, sub, subseq, none))

    def test_empty_and_missing_text_score_zero(self):
        self.assertEqual(scores(("a", ""), ("a", None), ("a", "")), [0, 0, 0])

    def test_is_case_insensitive_on_the_text_only(self):
        # the query must already be lower case (callers do it); the text is lowered here
        self.assertEqual(scores(("abc", "ABC"), ("abc", "AbC")), [120, 120])

    def test_prefix_prefers_the_shorter_text(self):
        a, b = scores(("ab", "abc"), ("ab", "abcdefghijklmnop"))
        self.assertGreater(a, b)

    def test_word_start_beats_a_plain_substring(self):
        word, mid = scores(("bar", "foo bar"), ("bar", "foobar"))
        self.assertGreater(word, mid)

    def test_earlier_word_start_is_better(self):
        a, b = scores(("x", "a x"), ("x", "abcdefg x"))
        self.assertGreater(a, b)

    def test_separators(self):
        # space - _ . always start a word; others only when passed in extraSeps
        hyphen, underscore, dot, slash_plain, slash_sep, colon_sep = scores(
            ("bar", "foo-bar"), ("bar", "foo_bar"), ("bar", "foo.bar"), ("bar", "a/bar"), ("bar", "a/bar", "/"), ("bar", "game:bar", ":"))
        self.assertTrue(hyphen > 70 and underscore > 70 and dot > 70, (hyphen, underscore, dot))
        self.assertEqual(slash_plain, 70 - 2)           # only a substring at index 2
        self.assertGreater(slash_sep, slash_plain)
        self.assertGreater(colon_sep, 70)

    def test_special_characters_are_literals(self):
        # none of these may throw, and a regex metacharacter in the query must not act as one
        got = scores((".", "abc"), ("a.c", "abc"), ("(", "f(x)"), ("[", "a[b"), ("*", "a*b"), ("\\", "a\\b"), ("+", "1+1"),
                     ("a|b", "a"), ("$", "cost $5"), ("^", "x^2"))
        self.assertEqual(got[0], 0)       # "." is not "any character"
        self.assertEqual(got[1], 0)       # "." in "a.c" is a literal dot, so it is not a wildcard for "b"
        self.assertTrue(got[2] > 0 and got[3] > 0 and got[4] > 0 and got[5] > 0 and got[6] > 0)
        self.assertEqual(got[7], 0)       # "a|b" is not alternation
        self.assertTrue(got[8] > 0 and got[9] > 0)

    def test_special_characters_in_extra_separators(self):
        got = scores(("x", "a]x", "]"), ("x", "a\\x", "\\"), ("x", "a^x", "^"), ("x", "a-x", "-"), ("x", "a]x"))
        self.assertTrue(got[0] > 70 and got[1] > 70 and got[2] > 70 and got[3] > 70, got)
        self.assertLessEqual(got[4], 70)  # without "]" as a separator it is only a substring

    def test_subsequence_gaps_and_options(self):
        tight, gappy = scores(("abc", "a1b2c"), ("abc", "a---b---c"))
        self.assertGreater(tight, 0)
        self.assertGreater(tight, gappy)
        # subBase replaces the 50, lengthPenalty false drops the length term
        default, higher, nopen = scores(("ac", "abbbbbbbbbbbbc"), ("ac", "abbbbbbbbbbbbc", None, 90), ("ac", "abbbbbbbbbbbbc", None, None, False))
        self.assertGreater(higher, default)
        self.assertGreater(nopen, default)
        self.assertEqual(scores(("ac", "abc", None, 50, False))[0], 50 - 8)

    def test_subsequence_needs_the_letters_in_order(self):
        self.assertEqual(scores(("ba", "ab"), ("abc", "acb")), [0, 0])

    def test_the_cache_follows_the_query_and_the_separators(self):
        # same process, alternating: a stale regex would give the wrong answer
        got = scores(("bar", "foo bar"), ("baz", "foo baz"), ("bar", "foo bar"), ("baz", "foo bar"), ("x", "a/x"), ("x", "a/x", "/"),
                     ("x", "a/x"), ("x", "a/x", "/"))
        self.assertEqual(got[0], got[2])
        self.assertEqual(got[3], 0)
        self.assertEqual(got[4], got[6])
        self.assertEqual(got[5], got[7])
        self.assertGreater(got[5], got[4])


@unittest.skipUnless(shutil.which("node"), "node not installed")
class CurrentFirst(unittest.TestCase):
    def test_moves_the_current_item_to_the_front_and_keeps_the_rest_in_order(self):
        got = run("""const l = [{key:'a'},{key:'b'},{key:'c'},{key:'d'}];
console.log(JSON.stringify([currentFirst(l,'c').map(x=>x.key), currentFirst(l,'a').map(x=>x.key), currentFirst(l,'z').map(x=>x.key),
  currentFirst([], 'a'), currentFirst(l,'d').map(x=>x.key), l.map(x=>x.key)]));""")
        self.assertEqual(got, [["c", "a", "b", "d"], ["a", "b", "c", "d"], ["a", "b", "c", "d"], [], ["d", "a", "b", "c"],
                               ["a", "b", "c", "d"]])

    def test_duplicates_of_the_current_key_all_come_first(self):
        got = run("console.log(JSON.stringify(currentFirst([{key:'a',n:1},{key:'b',n:2},{key:'a',n:3}], 'a').map(x=>x.n)));")
        self.assertEqual(got, [1, 3, 2])


if __name__ == "__main__":
    unittest.main()
