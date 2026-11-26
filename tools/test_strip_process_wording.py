"""Tests for tools/strip-process-wording.py (temp folders only, no network). Run: python tools/test_strip_process_wording.py"""
import importlib.util
import io
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("spw", os.path.join(HERE, "strip-process-wording.py"))
spw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(spw)


def make_repo(files):
    d = tempfile.mkdtemp(prefix="spw-")
    subprocess.run(["git", "init", "-q"], cwd=d, check=True)
    for rel, text in files.items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(text)
    subprocess.run(["git", "add", "-A"], cwd=d, check=True)
    return d


def read(d, rel):
    with open(os.path.join(d, rel), encoding="utf-8", newline="") as f:
        return f.read()


def run(d, *args):
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = spw.main(["--root", d] + list(args))
    return code, buf.getvalue()


class EditLine(unittest.TestCase):
    def lua(self, s):
        return spw.edit_line(s + "\n", "lua")[0].rstrip("\n")

    def test_leading_tag_group_goes(self):
        self.assertEqual(self.lua("-- (BRIEF19 R6) At its default place"), "-- At its default place")

    def test_tag_group_in_the_middle(self):
        self.assertEqual(self.lua("x = 1 -- the emblem (BRIEF15, PLAN 2.3.2 feature 2): a portal"), "x = 1 -- the emblem: a portal")

    def test_job_group(self):
        self.assertEqual(self.lua("-- (speed, job 2749) re-set many labels"), "-- (speed, job 2749) re-set many labels")  # job tags stay

    def test_tag_inside_other_parentheses(self):
        self.assertEqual(self.lua("-- the engine (W.Drive, Drive_*.lua; SPEC3 3.1) runs"), "-- the engine (W.Drive, Drive_*.lua) runs")

    def test_topic_and_review_tag(self):
        self.assertEqual(self.lua("-- (SPEC5 roles, review #17: a reloading captain) stays"), "-- (a reloading captain) stays")

    def test_trailing_comment_that_was_only_a_tag_is_dropped(self):
        self.assertEqual(self.lua("local a = 1 -- (BRIEF18)"), "local a = 1")

    def test_string_with_dashes_and_tag_is_not_a_comment(self):
        s = 'print("a -- (BRIEF18) b")'
        self.assertEqual(self.lua(s), s)

    def test_player_text_in_code_is_untouched(self):
        s = 'local t = "Google (BRIEF1) says"'
        self.assertEqual(self.lua(s), s)

    def test_google_as_tester(self):
        self.assertEqual(self.lua("-- read '{pric...' in Google's shots"), "-- read '{pric...' in a reviewer's shots")
        self.assertEqual(self.lua("-- Google review G1"), "-- an outside review G1")
        self.assertEqual(self.lua("-- Google caught the edge"), "-- a reviewer caught the edge")

    def test_hash_comments(self):
        self.assertEqual(spw.edit_line("# (job 2630) known fallbacks\n", "hash")[0], "# (job 2630) known fallbacks\n")
        s = 'x = "# (job 12)"\n'
        self.assertEqual(spw.edit_line(s, "hash")[0], s)

    def test_nested_tag_leaves_no_stray_bracket(self):
        self.assertEqual(self.lua("-- hidden ((BRIEF20 B1) in the game a texture keeps it)"), "-- hidden (in the game a texture keeps it)")

    def test_tidy_leaves_calls_and_real_brackets_alone(self):
        s = "-- the clock: time() and W.Char() and test( line and realm  (, id 0) and before ( or )"
        self.assertEqual(spw.tidy(s), s)
        self.assertEqual(spw.tidy("a pick (; the card reads x)"), "a pick (the card reads x)")
        self.assertEqual(spw.tidy("Before the step (): whether it"), "Before the step: whether it")

    def test_crlf_is_kept(self):
        self.assertEqual(spw.edit_line("-- (BRIEF3) hi\r\n", "lua")[0], "-- hi\r\n")


class Whole(unittest.TestCase):
    def setUp(self):
        self.d = make_repo({
            "Wuber/A.lua": "-- (BRIEF17) peek\nlocal s = 'keep -- (BRIEF9)'\n",
            "tests/fixtures/gauntlet/chat-lines.lua": '{ n = 1, text = "hi", writer = "writer-sonnet" },\n{ n = 2, text = "yo", writer = "author" },\n',
            "AGENTS.md": "- **One issue per branch and per pull request.** Branch names: `claude/<n>`, `google/<n>`, `author/<topic>` (n = the issue number).\n",
            "other.txt": "(BRIEF1) not code, not listed\n",
        })

    def test_dry_run_writes_nothing_and_lists_changes(self):
        before = read(self.d, "Wuber/A.lua")
        code, out = run(self.d, "--dry-run")
        self.assertEqual(code, 0)
        self.assertEqual(read(self.d, "Wuber/A.lua"), before)
        self.assertIn("Wuber/A.lua:1", out)
        self.assertIn("writer tests/fixtures/gauntlet/chat-lines.lua:1", out)
        self.assertIn("doc AGENTS.md", out)
        self.assertNotIn("other.txt", out)

    def test_apply_then_nothing_left(self):
        run(self.d, "--apply")
        self.assertEqual(read(self.d, "Wuber/A.lua"), "-- peek\nlocal s = 'keep -- (BRIEF9)'\n")
        lines = read(self.d, "tests/fixtures/gauntlet/chat-lines.lua")
        self.assertIn('writer = "writer-4"', lines)
        self.assertIn('writer = "author"', lines)
        self.assertNotIn("google/", read(self.d, "AGENTS.md"))
        self.assertIn("claude/<n>", read(self.d, "AGENTS.md"))
        self.assertEqual(read(self.d, "other.txt"), "(BRIEF1) not code, not listed\n")
        code, out = run(self.d, "--dry-run")
        self.assertIn("0 change(s)", out)

    def test_count(self):
        code, out = run(self.d, "--count")
        self.assertIn("BRIEF/SPEC tag lines", out)
        self.assertIn("model-name writer labels", out)


if __name__ == "__main__":
    unittest.main()