import os, sys, tempfile, unittest
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib.util
spec = importlib.util.spec_from_file_location("ff", os.path.join(os.path.dirname(os.path.abspath(__file__)), "failing-first.py"))
ff = importlib.util.module_from_spec(spec); spec.loader.exec_module(ff)


class T(unittest.TestCase):
    def test_parse(self):
        src = '-- guard: it only keeps a rule\ntest("a b", function() end)\nT.test('"'"'c "q"'"'"', f)\npending("p", "x", f)\n-- test("commented", f)\nlocal x = mytest("no", f)\ntest("esc \\"x\\"", f)\n'
        got = ff.parse_tests(src)
        self.assertEqual(got[0], ("test", "a b", "it only keeps a rule"))
        self.assertEqual(got[1], ("test", 'c "q"', None))
        self.assertEqual(got[2][:2], ("pending", "p"))
        self.assertEqual(got[3][:2], ("test", 'esc "x"'))
        self.assertEqual(len(got), 4)
        self.assertEqual(ff.parse_tests('test("run1 f: " .. n .. " x", f)'), [])

    def test_guards_need_reason(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "g.txt")
            open(p, "w").write("# c\nname one\tbecause\n")
            self.assertEqual(ff.load_guards(p), {"name one": "because"})
            open(p, "w").write("name two\t \n")
            with self.assertRaises(ValueError):
                ff.load_guards(p)
            open(p, "w").write("name three\n")
            with self.assertRaises(ValueError):
                ff.load_guards(p)

    def test_parse_out(self):
        r = ff.parse_out("ok\t0.1\tA\nfail\t0.2\tB\nwhy\tx: got 1, want 2\nok\t0\tC\n")
        self.assertEqual(r, {"A": (True, ""), "B": (False, "x: got 1, want 2"), "C": (True, "")})

    def test_judge(self):
        added = {"p": ("test", None, "f"), "f": ("test", None, "f"), "g": ("test", None, "f"),
                 "gc": ("test", "why", "f"), "e": ("test", None, "f"), "pe": ("pending", None, "f"), "n": ("test", None, "f")}
        res = {"p": (True, ""), "f": (False, "x: got 1, want 2"), "g": (True, ""), "gc": (True, ""), "e": (False, "attempt to call field 'zz' (a nil value)")}
        rows, c = ff.judge(added, {"g": "listed"}, res)
        self.assertEqual((c["new"], c["failed_on_base"], c["guards"], c["passed_on_base"], c["pending"], c["notrun"]), (7, 2, 2, 1, 1, 1))
        d = {r[0]: r[2] for r in rows}
        self.assertEqual(d["e"], "FAIL (error, not an assertion)")
        self.assertEqual(d["f"], "FAIL (assertion)")
        self.assertEqual(d["p"], "PASS ON BASE")

    def test_patch_run(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "run.lua")
            open(p, "w", newline="").write("local skipped=0\r\nlocal results = {}\r\nlocal function test(name, fn)\r\n\tlocal ok,err=true\r\n\tresults[#results + 1] = { name = name, ok = ok }\r\nend\r\n")
            self.assertEqual(ff.patch_run(p), "patch")
            t = open(p, newline="").read()
            self.assertIn("WF.on and not WF[name]", t)
            self.assertNotIn("\r\n\n", t.replace("\r\n", "\n\n"[:0] + "\r\n"))
            open(p, "w").write("WUBER_ONLY_TESTS")
            self.assertEqual(ff.patch_run(p), "env")
            open(p, "w").write("nothing")
            with self.assertRaises(RuntimeError):
                ff.patch_run(p)

    def test_is_error(self):
        self.assertTrue(ff.is_error("tests/x.lua:3: attempt to index a nil value"))
        self.assertFalse(ff.is_error("rider shows 3: got 1, want 2"))


if __name__ == "__main__":
    unittest.main()
