"""rerun-fixed.py with hunt repros: a fixed line whose proof is a repro/ file runs as "lua <repro> --addon <repo>/Wuber"
(cwd = repo, exit 0 = PASS, 1 = STILL FAILS); a tests/ part keeps the run.lua way. Fake lua = this python. Run from the repo root."""
import unittest, os, sys, io, tempfile, contextlib
import importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.environ.get("L25_TOOLS_DIR", HERE)


def load(fname, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, fname))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

RF = load("rerun-fixed.py", "rf")

# a repro that exits 0 only when --addon equals <cwd>/Wuber, 1 otherwise (2 when it is not given at all)
REPRO = (
    "import sys, os\n"
    "a = sys.argv[sys.argv.index('--addon') + 1] if '--addon' in sys.argv else None\n"
    "if a is None: sys.exit(2)\n"
    "sys.exit(0 if os.path.abspath(a) == os.path.abspath(os.path.join(os.getcwd(), 'Wuber')) else 1)\n"
)
BADREPRO = "import sys\nsys.exit(1)\n"
STUB = "import sys\nsys.exit(1 if any('bad_test' in a for a in sys.argv) else 0)\n"


class Repro(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        self.out = tempfile.mkdtemp()  # a gauntlet folder outside the repo
        os.makedirs(os.path.join(self.d, "Wuber"))
        open(os.path.join(self.d, "Wuber", "Wuber.toc"), "w").write("## Title: fake\n")
        for rel, body in (("hunt/repro/good.lua", REPRO), ("hunt/repro/bad.lua", BADREPRO)):
            p = os.path.join(self.d, "tests", *rel.split("/"))
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w").write(body)
        p = os.path.join(self.d, "tests", "r1", "good_test.lua")
        os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "w").write("-- fake\n")
        open(os.path.join(self.d, "tests", "run.lua"), "w").write(STUB)
        os.makedirs(os.path.join(self.out, "hunt", "repro"))
        self.outside = os.path.join(self.out, "hunt", "repro", "outside.lua")
        open(self.outside, "w").write(REPRO)
        self.bugs = os.path.join(self.d, "BUGS.md")
        open(self.bugs, "w").write(
            "B-01 | Nit | f.lua:1 | x | tests/hunt/repro/good.lua | 5 | fixed r1 abc\n"
            "B-02 | Nit | f.lua:1 | x | tests/hunt/repro/bad.lua | 5 | fixed r1 abc\n"
            "B-03 | Nit | f.lua:1 | x | %s | 5 | fixed r1 abc\n"
            "B-04 | Nit | f.lua:1 | x | tests/r1/good_test.lua | 5 | fixed r2\n" % self.outside)

    def run_rf(self, *extra):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = RF.main(["--bugs", self.bugs, "--repo", self.d] + list(extra))
        return code, buf.getvalue().strip().split("\n")

    def test_repro_runs_with_addon(self):
        code, out = self.run_rf("--lua", sys.executable)
        self.assertIn("B-01: PASS", out)
        self.assertTrue(any(l.startswith("B-02: STILL FAILS") for l in out), out)
        self.assertIn("B-03: PASS", out)  # outside the repo, absolute path
        self.assertIn("B-04: PASS", out)  # guard: a tests/ part still runs through run.lua
        self.assertEqual(code, 1)
        self.assertEqual(out[-1], "fixed repros: 4 re-run, 1 still fail, 0 not re-runnable")

    def test_dry_names_the_addon(self):
        code, out = self.run_rf("--dry")
        self.assertEqual(code, 0)
        self.assertIn("--addon", out[0])
        self.assertIn(os.path.join(os.path.abspath(self.d), "Wuber"), out[0])
        self.assertIn("--files=r1/good_test", out[3])


if __name__ == "__main__":
    unittest.main()
