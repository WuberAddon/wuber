"""L25 D3: rerun-fixed.py with a fake repo and a fake lua (a python stub). Run from the repo root."""
import unittest, os, sys, io, tempfile, contextlib
import importlib.util, os
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.environ.get("L25_TOOLS_DIR", HERE)  # point at an older copy of tools/ to see the tests fail before the change


def load(fname, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, fname))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

RF = load("rerun-fixed.py", "rf")

BUGS = """# title
A-01 | Nit | f.lua:1 | x | \\f\\review\\audit\\t.lua | 5 | fixed r1 abc (branch next; test tests/r1/good_test.lua)
A-02 | Nit | f.lua:1 | x | proof | 5 | fixed r1 abc (branch next; test tests/r1/bad_test.lua)
A-03 | Nit | f.lua:1 | x | tests/r2/inrepo_test.lua | 5 | fixed r2
A-04 | Nit | f.lua:1 | x | audit\\pic.png | 5 | fixed r2 (picture only)
A-05 | Nit | f.lua:1 | x | tests/r1/good_test.lua | 5 | open
A-06 | Nit | f.lua:1 | x | proof | 5 | fixed r3 (test tests/rdir)
"""
STUB = "import sys\nsys.exit(1 if any('bad_test' in a for a in sys.argv) else 0)\n"


def run(args):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = RF.main(args)
    return code, buf.getvalue().strip().split("\n")


class Rerun(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        for rel in ("r1/good_test.lua", "r1/bad_test.lua", "r2/inrepo_test.lua", "rdir/a_test.lua"):
            p = os.path.join(self.d, "tests", *rel.split("/"))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w").write("-- fake\n")
        open(os.path.join(self.d, "tests", "run.lua"), "w").write(STUB)
        self.bugs = os.path.join(self.d, "BUGS.md")
        open(self.bugs, "w").write(BUGS)

    def test_dry(self):
        code, out = run(["--bugs", self.bugs, "--repo", self.d, "--dry"])
        self.assertEqual(code, 0)
        self.assertIn("A-01: would run", out[0])
        self.assertIn("--files=r1/good_test", out[0])
        self.assertEqual(out[-1], "fixed repros: 4 re-run, 0 still fail, 1 not re-runnable")
        self.assertTrue(any(l.startswith("A-04: not re-runnable") for l in out))
        self.assertFalse(any(l.startswith("A-05") for l in out))

    def test_run_with_fake_lua(self):
        # the fake lua is a python script: lua = this python, run.lua = the stub
        code, out = run(["--bugs", self.bugs, "--repo", self.d, "--lua", sys.executable])
        self.assertEqual(code, 1)
        self.assertIn("A-01: PASS", out)
        self.assertTrue(any(l.startswith("A-02: STILL FAILS") for l in out))
        self.assertIn("A-03: PASS", out)
        self.assertIn("A-06: PASS", out)
        self.assertEqual(out[-1], "fixed repros: 4 re-run, 1 still fail, 1 not re-runnable")


if __name__ == "__main__":
    unittest.main()
