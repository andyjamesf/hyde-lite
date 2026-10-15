"""tools/check_data.py: the JSONC stripper and the TOML/JSON/include validation, on a throwaway git repo.

    python3 -I tools/tests/test_check_data.py
"""
import contextlib
import importlib.util
import io
import json
import pathlib
import subprocess
import tempfile
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_data", TOOLS / "check_data.py")
cd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cd)


class Strip(unittest.TestCase):
    def loads(self, text):
        return json.loads(cd.strip_jsonc(text))

    def test_line_and_block_comments(self):
        self.assertEqual(self.loads('{"a": 1, // note\n "b": /* x */ 2}'), {"a": 1, "b": 2})

    def test_trailing_commas(self):
        self.assertEqual(self.loads('{"a": [1, 2,], "b": {"c": 3,},}'), {"a": [1, 2], "b": {"c": 3}})

    def test_strings_are_left_alone(self):
        text = '{"url": "http://x.org/a,b", "s": "// not a comment", "t": "/* nor this */", "e": "a\\"b, ]"}'
        self.assertEqual(self.loads(text), json.loads(text))

    def test_comment_between_tokens_keeps_them_apart(self):
        with self.assertRaises(json.JSONDecodeError):
            self.loads("1/*x*/2")

    def test_unterminated_block_comment_is_rejected(self):
        with self.assertRaises(json.JSONDecodeError):
            self.loads('{"a": 1 /* never closed')


class Main(unittest.TestCase):
    def repo(self, files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = pathlib.Path(tmp.name)
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        for rel, text in files.items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text)
        subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
        return root

    def run_main(self, root):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = cd.main(root)
        return code, out.getvalue()

    def test_clean_repo(self):
        root = self.repo({"a.toml": "x = 1\n", "b.json": '{"k": [1]}', "notes.txt": "{not json"})
        code, out = self.run_main(root)
        self.assertEqual(code, 0)
        self.assertIn("1 toml, 1 json, 0 includes, 0 problems", out)

    def test_bad_toml_and_json_are_reported(self):
        root = self.repo({"a.toml": "x = \n", "b.json": '{"k": }'})
        code, out = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("a.toml: TOML:", out)
        self.assertIn("b.json: JSON:", out)

    def test_jsonc_directories_may_have_comments_others_may_not(self):
        text = '{"a": 1, // c\n}'
        root = self.repo({"Configs/.config/Code/settings.json": text, "plain.json": text})
        code, out = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("plain.json: JSON:", out)
        self.assertNotIn("settings.json", out)

    def test_dots_includes_must_exist(self):
        root = self.repo({
            "dots.toml": '[global]\ninclude = ["Scripts/dots/a.toml", "Scripts/dots/missing.toml"]\n',
            "Scripts/dots/a.toml": "x = 1\n",
        })
        code, out = self.run_main(root)
        self.assertEqual(code, 1)
        self.assertIn("include not found: Scripts/dots/missing.toml", out)
        self.assertNotIn("a.toml: include", out)

    def test_group_includes_are_relative_to_the_file(self):
        root = self.repo({
            "Scripts/dots-groups/g.toml": '[global]\ninclude = ["../dots/a.toml"]\n',
            "Scripts/dots/a.toml": "x = 1\n",
        })
        self.assertEqual(self.run_main(root)[0], 0)

    def test_untracked_and_deleted_files_are_ignored(self):
        root = self.repo({"a.toml": "x = 1\n"})
        (root / "later.toml").write_text("x = \n")  # untracked: not checked
        (root / "a.toml").unlink()  # tracked but gone: skipped, not an error
        self.assertEqual(self.run_main(root)[0], 0)


if __name__ == "__main__":
    unittest.main()
