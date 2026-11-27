"""Tests for tools/log-digest.py (no files outside a temp folder, no network). Run: python tools/test_log_digest.py"""
import importlib.util
import io
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("log_digest", os.path.join(HERE, "log-digest.py"))
ld = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ld)

JOIN = """shard 1/2: exit 0 at 40 s: shard 1/2: 10 passed, 0 failed (results x)
shard 2/2: exit 1 at 41 s: shard 2/2: 7 passed, 3 failed (results y)
PASS  a fine test
PEND  later
      -> waits for something
FAIL  RR one  (shard 2)
      tests/run.lua:929: Ritual Rides 1.4.0 not found
      stack traceback:
      \t[C]: in function 'error'
FAIL  RR two  (shard 2)
      tests/run.lua:929: Ritual Rides 1.4.0 not found
      stack traceback:
FAIL  the fold keeps its place  (shard 2)
      tests/ui/fold_test.lua:40: fold: got 3, want 1

17 passed, 3 failed, 1 pending
failed: RR one; RR two; the fold keeps its place
slowest tests (CPU s):
  25.1\tlab photo
suite-par: 2 shards, 41 s, exit 1
"""

PY = """..F.E
======================================================================
FAIL: test_push (__main__.T.test_push)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "t.py", line 3, in test_push
    self.assertEqual(1, 2)
AssertionError: 1 != 2

======================================================================
ERROR: test_body (__main__.T.test_body)
----------------------------------------------------------------------
Traceback (most recent call last):
  File "t.py", line 9, in test_body
NameError: name 'p' is not defined

----------------------------------------------------------------------
Ran 5 tests in 0.1s

FAILED (failures=1, errors=1)
"""


class T(unittest.TestCase):
    def d(self, text, n=10):
        return ld.digest(text.splitlines(), n)

    def test_suite_join_groups_failures_by_first_error(self):
        lines, failed = self.d(JOIN)
        self.assertTrue(failed)
        self.assertLessEqual(len(lines), 10)
        self.assertEqual(lines[0], "counts: 17 passed, 3 failed, 1 pending")
        self.assertIn("suite-par: 2 shards, 41 s, exit 1", lines)
        self.assertIn("failing: 3 tests in 2 groups by first error", lines)
        self.assertIn("- 2 tests: tests/run.lua:929: Ritual Rides 1.4.0 not found (e.g. RR one)", lines)
        self.assertIn("- the fold keeps its place: tests/ui/fold_test.lua:40: fold: got 3, want 1", lines)
        self.assertFalse(any("stack traceback" in l or "PEND" in l for l in lines))

    def test_a_green_run(self):
        lines, failed = self.d("PASS  a\nPASS  b\n\n2 passed, 0 failed, 0 pending\nsuite-par: 16 shards, 90 s, exit 0\n")
        self.assertFalse(failed)
        self.assertEqual(lines, ["counts: 2 passed, 0 failed, 0 pending", "suite-par: 16 shards, 90 s, exit 0"])

    def test_skipped_and_rejected(self):
        lines, failed = self.d("\n5 passed, 0 failed, 0 pending, 2 skipped\nREJECTED: unfiltered run skipped 2 tests\n")
        self.assertTrue(failed)
        self.assertIn("counts: 5 passed, 0 failed, 0 pending, 2 skipped", lines)
        self.assertIn("REJECTED: unfiltered run skipped 2 tests", lines)

    def test_a_shard_that_did_not_finish(self):
        lines, failed = self.d("shard 4/16: exit 124 at 2400 s: PASS  x\n")
        self.assertTrue(failed)
        self.assertIn("unfinished: shard 4/16 exit 124", lines)

    def test_a_cut_log_says_it_has_no_counts(self):
        lines, failed = self.d("PASS  a\nPASS  b\n")
        self.assertTrue(failed)
        self.assertTrue(any("did not finish" in l for l in lines))

    def test_python_unittest(self):
        lines, failed = self.d(PY)
        self.assertTrue(failed)
        self.assertIn("python: ran 5 tests, FAILED (failures=1, errors=1)", lines)
        self.assertIn("- test_push (__main__.T.test_push): AssertionError: 1 != 2", lines)
        self.assertIn("- test_body (__main__.T.test_body): NameError: name 'p' is not defined", lines)
        lines, failed = self.d("....\n----\nRan 4 tests in 0.1s\n\nOK\n")
        self.assertEqual((lines, failed), (["python: ran 4 tests, OK"], False))

    def test_other_tools_result_lines(self):
        lines, failed = self.d("noise\ncheck: 112 files, 112 modules, 0 failures, 4 warnings (--warn lists them)\n")
        self.assertEqual((lines, failed), (["check: 112 files, 112 modules, 0 failures, 4 warnings (--warn lists them)"], False))
        lines, failed = self.d("x.md:1:1  email\nscanned 3 text files, skipped 0 binary; 1 hits\n")
        self.assertTrue(failed)
        self.assertEqual(lines, ["scanned 3 text files, skipped 0 binary; 1 hits"])
        lines, failed = self.d("quick-check: FAIL: tools/check.lua\n")
        self.assertTrue(failed)
        lines, failed = self.d("suite-par: REFUSED: another suite run (pid 9, started 3 s ago) holds x\n")
        self.assertTrue(failed)

    def test_failing_check_and_layout_lines_count_as_failures(self):
        for line in ("check: 112 files, 112 modules, 3 failures, 4 warnings",
                     "layout-check: 9 runs (x), 1891 shots, 5 problems, 1 known (reported, not failing: --known)",
                     "GAUNTLET layout result=fail shots=10 problems=2 known=0 covered=0 daylight=0 routes=0"):
            lines, failed = self.d(line + "\n")
            self.assertTrue(failed, line)
            self.assertEqual(lines, [line])
        lines, failed = self.d("layout-check: 9 runs (x), 1891 shots, 0 problems, 1 known\n")
        self.assertFalse(failed)

    def test_many_failures_stay_within_the_limit(self):
        text = "".join("FAIL  t%d\n      e%d: boom\n" % (i, i) for i in range(40)) + "\n0 passed, 40 failed, 0 pending\n"
        lines, failed = self.d(text, 10)
        self.assertTrue(failed)
        self.assertLessEqual(len(lines), 10)
        self.assertTrue(lines[-1].startswith("- and "))
        self.assertTrue(all(len(l) <= ld.WIDTH for l in lines))

    def test_unknown_log_shows_error_lines(self):
        lines, failed = self.d("starting\nall good\nError: disk full\nmore\n")
        self.assertEqual(lines, ["no test summary found; first error lines:", "Error: disk full"])

    def test_command_line(self):
        d = tempfile.mkdtemp()
        p = os.path.join(d, "join.log")
        with open(p, "w") as f:
            f.write(JOIN)
        old = sys.stdout
        sys.stdout = io.StringIO()
        try:
            code = ld.main([p])
            out = sys.stdout.getvalue()
            code2 = ld.main([os.path.join(d, "missing.log")])
        finally:
            sys.stdout = old
        self.assertEqual(code, 1)
        self.assertIn("counts: 17 passed, 3 failed, 1 pending", out)
        self.assertEqual(code2, 2)


if __name__ == "__main__":
    unittest.main()
