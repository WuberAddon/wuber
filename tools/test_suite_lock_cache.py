"""Tests for the PC-wide suite lock and the result cache of tools/suite-par.sh.  python tools/test_suite_lock_cache.py

A made-up lua5.1 (a small bash script) stands in for the real interpreter, so no real test runs: it logs every
call, and "--join" prints a passing summary. Every tree is a throw-away git work tree in a temporary folder.
"""
import os
import shutil
import subprocess
import tempfile
import threading
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.path.join(HERE, "suite-par.sh").replace("\\", "/")

FAKE_LUA = """#!/bin/bash
echo "start $(date +%s.%N) $*" >> "$FAKE_LOG"
case "$*" in
  *--join*) echo "10 passed, 0 failed, 0 skipped"; echo "end $(date +%s.%N)" >> "$FAKE_LOG"; exit "${FAKE_JOIN_EXIT:-0}" ;;
esac
sleep "${FAKE_SLEEP:-0}"
echo "end $(date +%s.%N)" >> "$FAKE_LOG"
"""


def p(path):
    return str(path).replace("\\", "/")


class Base(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="wuber-suitelock-")
        self.lockdir = p(os.path.join(self.root, "locks"))
        self.cache = p(os.path.join(self.root, "cache"))
        self.lua = p(os.path.join(self.root, "fakelua.sh"))
        with open(self.lua, "w", newline="\n") as f:
            f.write(FAKE_LUA)
        os.chmod(self.lua, 0o755)
        self.log = p(os.path.join(self.root, "calls.log"))
        self.trees = {}

    def tearDown(self):
        # the temporary folder is left to the system's temp cleanup (nothing in this repo deletes folders)
        pass

    def tree(self, name="a", text="one\n"):
        d = os.path.join(self.root, name)
        os.makedirs(os.path.join(d, "tests"), exist_ok=True)
        with open(os.path.join(d, "tests", "run.lua"), "w", newline="\n") as f:
            f.write("-- the fake interpreter never reads this\n")
        with open(os.path.join(d, "src.lua"), "w", newline="\n") as f:
            f.write(text)
        with open(os.path.join(d, ".gitignore"), "w", newline="\n") as f:
            f.write("tests/out/\n")  # as in the real repository
        subprocess.run(["git", "init", "-q", d], check=True)
        return p(d)

    def env(self, **extra):
        e = dict(os.environ)
        for k in ("WUBER_SUITE_LOCK", "WUBER_SUITE_CACHE", "WUBER_SUITE_FRESH", "WUBER_SHARDS", "WUBER_SUITE_NESTED", "WUBER_SUITE_PARENT", "WUBER_SUITE_SLOTS"):
            e.pop(k, None)
        # one slot unless a test says otherwise: the old tests below are about a single holder
        e.update(WUBER_LUA=self.lua, FAKE_LOG=self.log, WUBER_SUITE_POLL="1", WUBER_SUITE_SLOTS="3")
        e.update(extra)
        return e

    def run_suite(self, tree, *args, **env):
        return subprocess.run(["bash", SUITE, tree, "2", *args], env=self.env(**env), capture_output=True,
                              text=True, timeout=120)

    def calls(self):
        if not os.path.exists(self.log):
            return []
        with open(self.log) as f:
            return [ln.split() for ln in f.read().splitlines() if ln.startswith("start ")]


class Cache(Base):
    def test_miss_then_hit(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        r1 = self.run_suite(t, **env)
        self.assertEqual(r1.returncode, 0, r1.stdout + r1.stderr)
        self.assertNotIn("CACHE HIT", r1.stdout)
        self.assertEqual(len(self.calls()), 3, "2 shards + the join")
        r2 = self.run_suite(t, **env)
        self.assertEqual(r2.returncode, 0, r2.stdout + r2.stderr)
        self.assertIn("CACHE HIT", r2.stdout)
        self.assertIn("10 passed, 0 failed", r2.stdout)
        self.assertEqual(len(self.calls()), 3, "a hit starts no test")

    def test_hit_for_the_same_content_in_another_folder(self):
        env = dict(WUBER_SUITE_CACHE=self.cache)
        self.run_suite(self.tree("a"), **env)
        r = self.run_suite(self.tree("b"), **env)
        self.assertIn("CACHE HIT", r.stdout)
        self.assertEqual(len(self.calls()), 3)

    def test_miss_on_a_changed_file(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        self.run_suite(t, **env)
        with open(os.path.join(t, "src.lua"), "a", newline="\n") as f:
            f.write("two\n")
        r = self.run_suite(t, **env)
        self.assertNotIn("CACHE HIT", r.stdout)
        self.assertEqual(len(self.calls()), 6, "the changed tree ran for real")
        r = self.run_suite(t, **env)
        self.assertIn("CACHE HIT", r.stdout, "and its own result is cached now")

    def test_miss_on_a_new_untracked_file_and_on_other_arguments(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        self.run_suite(t, **env)
        r = self.run_suite(t, "some filter", **env)
        self.assertNotIn("CACHE HIT", r.stdout, "another filter is another key")
        with open(os.path.join(t, "new.lua"), "w", newline="\n") as f:
            f.write("x\n")
        r = self.run_suite(t, **env)
        self.assertNotIn("CACHE HIT", r.stdout, "a new file is a changed tree")

    def test_miss_on_another_interpreter(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        self.run_suite(t, **env)
        other = p(os.path.join(self.root, "otherlua.sh"))
        shutil.copyfile(self.lua, other)
        with open(other, "a", newline="\n") as f:
            f.write("# a different build\n")
        os.chmod(other, 0o755)
        r = self.run_suite(t, WUBER_SUITE_CACHE=self.cache, WUBER_LUA=other)
        self.assertNotIn("CACHE HIT", r.stdout)

    def test_forced_fresh(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        self.run_suite(t, **env)
        for extra, e2 in (
            (("--fresh",), {}),
            ((), {"WUBER_SUITE_FRESH": "1"}),
            (("--compare-transcript",), {}),
            (("--update-transcript",), {}),
        ):
            before = len(self.calls())
            r = self.run_suite(t, *extra, **env, **e2)
            self.assertNotIn("CACHE HIT", r.stdout, extra)
            self.assertEqual(len(self.calls()), before + 3, "a real run for %s %s" % (extra, e2))
        with open(self.log) as f:
            self.assertNotIn("--fresh", f.read(), "--fresh is not passed on to run.lua")
        r = self.run_suite(t, **env)
        self.assertIn("CACHE HIT", r.stdout, "a plain run may still hit")

    def test_a_failed_run_is_not_cached(self):
        t = self.tree()
        env = dict(WUBER_SUITE_CACHE=self.cache)
        r = self.run_suite(t, FAKE_JOIN_EXIT="1", **env)
        self.assertEqual(r.returncode, 1)
        r = self.run_suite(t, **env)
        self.assertNotIn("CACHE HIT", r.stdout)
        self.assertEqual(r.returncode, 0)

    def test_default_cache_is_tests_out_cache_of_the_tree(self):
        t = self.tree()
        self.run_suite(t)
        r = self.run_suite(t)
        self.assertIn("CACHE HIT", r.stdout)
        self.assertEqual(len(self.calls()), 3)
        self.assertTrue(os.path.isdir(os.path.join(t, "tests", "out", "cache")))

class FreshAndNested(Base):
    """The slot lock itself is tested in tests/lessons/l26_suite_lock_test.lua (tools/suite-guard.sh holds it)."""

    def test_a_fresh_run_still_takes_and_frees_a_slot(self):
        t = self.tree()
        lk = p(os.path.join(self.root, "locks"))
        env = dict(WUBER_SUITE_CACHE=self.cache, WUBER_SUITE_LOCK=lk)
        self.run_suite(t, **env)
        r = self.run_suite(t, "--fresh", **env)
        self.assertNotIn("CACHE HIT", r.stdout)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual([f for f in os.listdir(lk) if f.startswith("held.")], [], "the slot is freed on exit")

    def test_a_nested_run_takes_no_lock_and_uses_no_cache(self):
        t = self.tree()
        lk = p(os.path.join(self.root, "locks"))
        os.makedirs(lk)
        for i in range(3):  # every slot taken by a live pid (this test process)
            with open(os.path.join(lk, "held.%d" % (os.getpid() + i)), "w") as f:
                f.write("%d %d\n" % (os.getpid(), int(time.time())))
        env = dict(WUBER_SUITE_CACHE=self.cache, WUBER_SUITE_LOCK=lk, WUBER_SUITE_PARENT=str(os.getpid()))
        for _ in range(2):
            r = self.run_suite(t, **env)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertNotIn("CACHE HIT", r.stdout)
        self.assertEqual(len(self.calls()), 6)


if __name__ == "__main__":
    unittest.main()
