"""L25 D2: report-lint.py. Run: python -m unittest tools.test_l25_d_report_lint (from the repo root)."""
import unittest
import importlib.util, os
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.environ.get("L25_TOOLS_DIR", HERE)  # point at an older copy of tools/ to see the tests fail before the change


def load(fname, name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(TOOLS, fname))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

RL = load("report-lint.py", "rl")


class Lint(unittest.TestCase):
    def reasons(self, text, items=None):
        return RL.lint(text, items)

    def test_e1_04_example_is_flagged(self):
        t = "## E1-04\n\nThe pop-up is the game's own. It fails because the server/client had no valid pending summon target/area.\n"
        fl = self.reasons(t)
        self.assertEqual(len(fl), 1)
        self.assertEqual(fl[0][0], 3)

    def test_file_line_or_quote_is_fine(self):
        self.assertEqual(self.reasons("It fails because Rides.lua:600 returns early.\n"), [])
        self.assertEqual(self.reasons("It fails because the log says `summoner=nil area=`.\n"), [])
        self.assertEqual(self.reasons('Caused by the line "summoner=nil area=" in the log.\n'), [])

    def test_not_proven_with_probe_is_fine(self):
        t = "The cause is the server: not proven.\nTo prove it: log StaticPopup1.Text at CONFIRM_SUMMON.\n"
        self.assertEqual(self.reasons(t), [])
        t2 = "- The root cause is the server (not proven)\n- To prove it: log StaticPopup1.Text\n"
        self.assertEqual(self.reasons(t2), [])

    def test_not_proven_without_probe_is_flagged(self):
        fl = self.reasons("The root cause is the server, not proven.\n")
        self.assertEqual(len(fl), 2)  # the cause and the missing probe

    def test_other_paragraph_does_not_excuse(self):
        t = "Cause is X because of the server.\n\nOther: not proven.\nTo prove it: look.\n"
        self.assertEqual(len(self.reasons(t)), 1)

    def test_bullets_are_judged_one_by_one(self):
        t = "- a because Foo.lua:12\n- b because the weather\n"
        fl = self.reasons(t)
        self.assertEqual([n for n, _ in fl], [2])

    def test_items(self):
        fl = self.reasons("E1-04 done\n", "- E1-04 why\n- E1-05 what\n")
        self.assertEqual(len(fl), 1)
        self.assertIn("E1-05", fl[0][1])

    def test_main_output_and_exit(self):
        import tempfile, os, io, contextlib
        d = tempfile.mkdtemp()
        p = os.path.join(d, "R.md")
        open(p, "w").write("It broke because magic.\n")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(RL.main([p]), 0)
            self.assertEqual(RL.main([p, "--strict"]), 1)
        out = buf.getvalue().split("\n")
        self.assertTrue(out[0].startswith("REPORT-LINT: 1: "))
        self.assertEqual(out[1], "report lint: 1 flags")


if __name__ == "__main__":
    unittest.main()
