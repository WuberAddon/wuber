"""L25 D1: failing-first.py --base-tools. Run: python -m unittest tools.test_l25_d_failing_first (from the repo root)."""
import unittest
import importlib.util, os
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.environ.get("L25_TOOLS_DIR", HERE)  # point at an older copy of tools/ to see the tests fail before the change


def load(fname, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, fname))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

FF = load("failing-first.py", "ff")

SRC = """
-- guard: infra
test("tool test", function() end)
-- guard: other reason
test("plain guard", function() end)
test("plain test", function() end)
"""


class BaseTools(unittest.TestCase):
    def setUp(self):
        self.added = {n: (k, g, "t.lua") for k, n, g in FF.parse_tests(SRC)}

    def test_parse_sees_infra_guard(self):
        self.assertEqual(self.added["tool test"][1], "infra")
        self.assertTrue(FF.is_infra("infra"))
        self.assertFalse(FF.is_infra("other reason"))

    def test_without_flag_infra_is_a_plain_guard(self):
        res = {n: (True, "") for n in self.added}
        rows, c = FF.judge(self.added, {}, res)
        self.assertEqual(c["guards"], 2)
        self.assertEqual(c["passed_on_base"], 1)
        self.assertEqual(c["infra_proved"] + c["infra_bad"], 0)

    def test_infra_failing_on_base_tools_is_proved(self):
        res = {n: (True, "") for n in self.added}
        rows, c = FF.judge(self.added, {}, res, {"tool test": (False, "boom")})
        self.assertEqual((c["infra_proved"], c["infra_bad"]), (1, 0))
        self.assertIn("infra test proved", [r for r in rows if r[0] == "tool test"][0][3])

    def test_infra_passing_on_base_tools_is_bad(self):
        res = {n: (True, "") for n in self.added}
        rows, c = FF.judge(self.added, {}, res, {"tool test": (True, "")})
        self.assertEqual((c["infra_proved"], c["infra_bad"]), (0, 1))
        self.assertIn("infra guard passes on base tools", [r for r in rows if r[0] == "tool test"][0][3])

    def test_flag_exists(self):
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf), self.assertRaises(SystemExit):
            FF.main(["--help"]) if False else FF.main(["--base-tools"])  # missing --target: argparse exits, but must know the flag
        self.assertNotIn("unrecognized arguments: --base-tools", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
