"""Tests for tools/pr-ready.py. No network, no Lua, no real git or gh: a fake runner answers every command.
The scrub step runs the repository's real scrub-check.py rules on a commit built in memory.
Run: python tools/test_pr_ready.py"""
import importlib.util
import io
import os
import tarfile
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("pr_ready", os.path.join(HERE, "pr-ready.py"))
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)
with open(os.path.join(os.path.dirname(HERE), "scrub-check.py"), encoding="utf-8") as f:
    SCRUB_SRC = f.read()

SHA = "0123456789abcdef0123456789abcdef01234567"
PUB = "# test list\nemail\t[a-z0-9.]+@[a-z0-9]+\\.[a-z]+\n"
ADDRESS = "someone" + "@" + "example.org"


class FakeRunner(pr.Runner):
    """Records every command that would do something; read-only git/gh answers come from the arguments."""

    def __init__(self, repo, dry_run=False, branch="claude/12", files=("Wuber/Core/Base.lua",), deleted=(),
                 dirty="", main_checkout=False, fail=None, codes=None, open_pr="", gh_ok=True, tree=None, pub=PUB):
        super().__init__(repo, dry_run, io.StringIO())
        self.branch, self.dirty, self.main_checkout = branch, dirty, main_checkout
        self.files = list(files) + list(deleted)
        for f in files:
            p = os.path.join(repo, f)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, "w").close()
        self.fail, self.codes, self.open_pr, self.gh_ok, self.pub = fail, codes or {}, open_pr, gh_ok, pub
        self.tree = tree if tree is not None else {"Wuber/Core/Base.lua": "local x = 1\n", "README.md": "Wuber\n"}
        self.ran, self.queries, self.archived = [], [], []

    def query(self, cmd):
        self.queries.append(list(cmd))
        j = " ".join(cmd)
        if j == "git rev-parse --abbrev-ref HEAD":
            return 0, self.branch
        if j == "git rev-parse --git-dir":
            return 0, ".git" if self.main_checkout else "/repo/.git/worktrees/x"
        if j == "git rev-parse --git-common-dir":
            return 0, ".git" if self.main_checkout else "/repo/.git"
        if j == "git status --porcelain":
            return 0, self.dirty
        if j == "git rev-parse HEAD":
            return 0, SHA
        if j == "gh auth status":
            return (0, "") if self.gh_ok else (1, "not logged in")
        if cmd[:2] == ["git", "merge-base"]:
            return 0, "abc123"
        if "diff" in cmd:
            assert "--no-renames" in cmd and cmd[-1] == SHA
            return 0, "\n".join(self.files)
        if j == "git show origin/main:scrub-check.py":
            return 0, SCRUB_SRC
        if j == "git show origin/main:scrub-patterns.public.txt":
            return 0, self.pub
        if cmd[:3] == ["gh", "pr", "list"]:
            assert "--state" in cmd and cmd[cmd.index("--state") + 1] == "open"
            return 0, self.open_pr
        raise AssertionError("unexpected query %r" % (cmd,))

    def archive(self, rev):
        self.archived.append(rev)
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode="w") as t:
            for name, text in self.tree.items():
                data = text.encode("utf-8")
                info = tarfile.TarInfo(name)
                info.size = len(data)
                t.addfile(info, io.BytesIO(data))
        return buf.getvalue()

    def kind(self, cmd):
        j = " ".join(cmd)
        for k in ("layout-check.lua", "check.lua", "suite-par.sh", "tests-for.lua", "git fetch", "git push",
                  "git branch", "gh pr create", "test_"):
            if k in j:
                return k
        raise AssertionError("unexpected command %r" % (cmd,))

    def _exec(self, cmd, env):
        k = self.kind(cmd)
        self.ran.append((k, list(cmd), dict(env or {})))
        if k == "gh pr create":
            with open(cmd[cmd.index("--body-file") + 1]) as f:
                self.body = f.read()
        if k == self.fail:
            return 1, {"suite-par.sh": "FAIL  a test\n      x.lua:3: got 1, want 2\n\n1 passed, 1 failed, 0 pending\n"}.get(k, "it broke\n")
        if k in self.codes:
            return self.codes[k]
        return 0, {"check.lua": "check: 112 files, 112 modules, 0 failures, 4 warnings\n",
                   "suite-par.sh": "\n4955 passed, 0 failed, 6 pending\nsuite-par: 16 shards, 90 s, exit 0\n",
                   "tests-for.lua": "\n12 passed, 0 failed, 0 pending\n",
                   "layout-check.lua": "layout-check: 9 runs, 1891 shots, 0 problems\n",
                   "test_": "....\nRan 4 tests in 0.1s\n\nOK\n",
                   "gh pr create": "https://github.com/o/r/pull/77\n"}.get(k, "")

    def kinds(self):
        return [k for k, _, _ in self.ran]


BASE = ["--prefix", "claude/", "--title", "#12 Fold keeps its place", "--what", "The fold keeps its place.",
        "--why", "It jumped back.", "--test", "fold_test: keeps its place (failed before).", "--no-fetch",
        "--lua", "lua5.1", "--bash", "bash"]
SENT = ["git push", "git branch", "gh pr create"]


class T(unittest.TestCase):
    def setUp(self):
        self.repo = tempfile.mkdtemp()
        os.environ.pop("PR_READY_BASH", None)

    def go(self, extra=(), args=None, **kw):
        r = FakeRunner(self.repo, dry_run="--dry-run" in extra, **kw)
        code = pr.main((args or BASE) + ["--repo", self.repo] + list(extra), runner=r)
        return code, r, r.out.getvalue()

    def assertNothingSent(self, r):
        self.assertFalse(any(k in SENT for k in r.kinds()), r.kinds())

    def test_happy_path_runs_every_check_then_pushes_the_checked_commit_and_opens_the_pr(self):
        code, r, out = self.go(["--issue", "12"])
        self.assertEqual(code, 0, out)
        self.assertEqual(r.kinds(), ["check.lua", "suite-par.sh"] + SENT)
        self.assertEqual(r.ran[1][1][-3:], ["tools/suite-par.sh", ".", "16"])
        self.assertEqual(r.ran[1][2]["WUBER_LUA"], "lua5.1")
        self.assertEqual(r.archived, [SHA])
        self.assertEqual(r.ran[2][1], ["git", "push", "origin", SHA + ":refs/heads/claude/12"])
        create = r.ran[4][1]
        self.assertEqual(create[create.index("--base") + 1], "main")
        self.assertEqual(create[create.index("--head") + 1], "claude/12")
        self.assertNotIn("--draft", create)
        for s in ("## What changed\nThe fold keeps its place.", "## Why\nIt jumped back.", "Fixes #12",
                  "fold_test: keeps its place (failed before).", "4955 passed, 0 failed, 6 pending",
                  "check: 112 files", "public list 0 hits", "rules from the base",
                  "layout check: not run (no file under Wuber/UI/ changed)", "private list not run"):
            self.assertIn(s, r.body)
        self.assertIn("https://github.com/o/r/pull/77", out)
        self.assertFalse(os.path.exists(create[create.index("--body-file") + 1]))   # its temp file is gone

    def test_never_main_never_force(self):
        for b in ("main", "master", "HEAD", "claude/"):
            code, r, out = self.go(branch=b)
            self.assertEqual((code, r.ran), (2, []), b)
        code, r, _ = self.go()
        push = [c for k, c, _ in r.ran if k == "git push"][0]
        self.assertFalse(any(c.startswith(("-f", "--force", "+")) for c in push))
        self.assertTrue(push[-1].endswith(":refs/heads/claude/12"))

    def test_branch_prefix(self):
        code, r, out = self.go(branch="google/12")
        self.assertEqual((code, r.ran), (2, []))
        self.assertIn("does not start with claude/", out)
        args = list(BASE)
        args[1] = "google/"
        code, r, _ = self.go(args=args, branch="google/12")
        self.assertEqual(code, 0)
        self.assertIn(SHA + ":refs/heads/google/12", r.ran[2][1])
        args[1] = "someone/"
        with self.assertRaises(SystemExit):
            pr.parse_args(args)

    def test_refuses_main_checkout_uncommitted_and_untracked_files_and_no_gh(self):
        for kw, words in (({"main_checkout": True}, "main checkout"), ({"dirty": " M Wuber/Core/Base.lua"}, "uncommitted"),
                          ({"dirty": "?? Wuber/Core/New.lua"}, "untracked"), ({"gh_ok": False}, "gh is missing"),
                          ({"files": ()}, "no commits")):
            code, r, out = self.go(**kw)
            self.assertEqual((code, r.ran), (2, []), kw)
            self.assertIn(words, out)

    def test_every_failing_check_stops_before_the_push(self):
        cases = ((("check.lua",), {}, []), (("suite-par.sh",), {}, ["check.lua"]),
                 (("layout-check.lua",), {"files": ("Wuber/UI/Fold.lua",)}, ["check.lua", "suite-par.sh"]),
                 (("test_",), {"files": ("tools/x.py", "tools/test_x.py")}, ["check.lua", "suite-par.sh"]))
        for (fail,), kw, before in cases:
            code, r, out = self.go(fail=fail, **kw)
            self.assertEqual(code, 1, fail)
            self.assertEqual(r.kinds(), before + [fail])
            self.assertEqual(r.archived, [])
            self.assertIn("FAIL at", out)
        code, r, out = self.go(["--quick"], fail="tests-for.lua")
        self.assertEqual((code, r.kinds()), (1, ["check.lua", "tests-for.lua"]))
        code, r, out = self.go(fail="suite-par.sh")
        self.assertIn("a test: x.lua:3: got 1, want 2", out)          # the digest names the failing test

    def test_scrub_catches_a_hit_in_a_file_a_file_name_and_the_pr_text_and_never_shows_it(self):
        for kw, extra, where in (({"tree": {"docs/a.md": "write to " + ADDRESS + "\n"}}, [], "docs/a.md:1:10"),
                                 ({"tree": {"docs/" + ADDRESS + ".txt": "mail " + ADDRESS + "\n"}}, [], "docs/<a name here>:0:1"),
                                 ({}, ["--what", "Ask " + ADDRESS], "pull request text:2:5")):
            code, r, out = self.go(extra, **kw)
            self.assertEqual(code, 1, where)
            self.assertNothingSent(r)
            self.assertIn("FAIL at scrub, public list", out)
            self.assertIn(where, out)
            self.assertIn("email", out)
            self.assertNotIn(ADDRESS, out)

    def test_a_failed_git_archive_stops_before_the_push(self):
        r = FakeRunner(self.repo)
        r.archive = lambda rev: None
        code = pr.main(BASE + ["--repo", self.repo], runner=r)
        self.assertEqual(code, 1)
        self.assertIn("git archive", r.out.getvalue())
        self.assertNothingSent(r)

    def test_dry_run_without_gh_still_shows_the_plan(self):
        code, r, out = self.go(["--dry-run"], gh_ok=False)
        self.assertEqual((code, r.ran), (0, []))
        self.assertIn("a real run would stop here", out)

    def test_the_branch_cannot_loosen_its_own_scrub(self):
        with open(os.path.join(self.repo, "scrub-patterns.public.txt"), "w") as f:
            f.write("# emptied on the branch\n")
        code, r, out = self.go(tree={"a.md": ADDRESS + "\n", "scrub-patterns.public.txt": "# emptied\n"})
        self.assertEqual(code, 1)
        self.assertNothingSent(r)

    def test_private_list_is_used_and_its_path_never_printed(self):
        d = tempfile.mkdtemp()
        priv = os.path.join(d, "very-private-list.txt")
        with open(priv, "w") as f:
            f.write("realname\tzorblax\n")
        tree = {"a.md": "by zorblax\n"}
        code, r, out = self.go(tree=tree)
        self.assertEqual(code, 0, out)                    # not in the public list
        code, r, out = self.go(["--private-list", priv], tree=tree)
        self.assertEqual(code, 1)
        self.assertIn("FAIL at scrub, private list", out)
        self.assertNotIn("zorblax", out)
        self.assertNothingSent(r)
        code, r, out = self.go(["--private-list", priv])
        self.assertEqual(code, 0, out)
        self.assertIn("public list 0 hits, private list 0 hits", r.body)
        for run in (out, r.body, self.go(["--private-list", priv, "--dry-run"])[2]):
            self.assertNotIn("very-private-list", run)
            self.assertNotIn(d, run)
        code, r, out = self.go(["--private-list", priv + ".missing"])
        self.assertEqual(code, 2)
        self.assertNothingSent(r)

    def test_ui_change_adds_the_layout_check(self):
        code, r, _ = self.go(files=("Wuber/UI/Fold.lua", "Wuber/Core/Base.lua"))
        self.assertEqual(code, 0)
        self.assertEqual(r.kinds()[:3], ["check.lua", "suite-par.sh", "layout-check.lua"])
        self.assertEqual(r.ran[2][1][-1], "tools/layout-check.lua")
        self.assertIn("layout check: pass", r.body)
        code, r, _ = self.go(["--quick"], files=("Wuber/UI/Fold.lua",))
        self.assertEqual(r.kinds()[:3], ["check.lua", "tests-for.lua", "layout-check.lua"])
        self.assertEqual(r.ran[1][1][-2:], ["--run", "Wuber/UI/Fold.lua"])
        self.assertEqual(r.ran[2][1][-2:], ["--files", "Wuber/UI/Fold.lua"])

    def test_a_deleted_ui_or_wuber_file_gets_the_full_runs(self):
        code, r, out = self.go(["--quick"], files=("Wuber/Core/Base.lua",), deleted=("Wuber/UI/Old.lua",))
        self.assertEqual(code, 0, out)
        self.assertEqual(r.kinds()[:3], ["check.lua", "suite-par.sh", "layout-check.lua"])
        self.assertEqual(r.ran[2][1][-1], "tools/layout-check.lua")

    def test_quick_falls_back_to_the_suite_when_tests_for_says_so(self):
        code, r, out = self.go(["--quick"], files=("tests/harness.lua",), codes={"tests-for.lua": (3, "full suite needed\n")})
        self.assertEqual(code, 0, out)
        self.assertEqual(r.kinds()[:3], ["check.lua", "tests-for.lua", "suite-par.sh"])
        self.assertIn("whole suite", r.body)

    def test_changed_python_tests_are_run(self):
        code, r, _ = self.go(files=("tools/x.py", "tools/test_x.py"))
        self.assertEqual(code, 0)
        self.assertEqual(r.kinds()[:3], ["check.lua", "suite-par.sh", "test_"])
        self.assertIn("tools/test_x.py: OK", r.body)

    def test_an_open_pull_request_is_not_opened_twice(self):
        code, r, out = self.go(open_pr="https://github.com/o/r/pull/5")
        self.assertEqual(code, 0)
        self.assertIn("git push", r.kinds())
        self.assertNotIn("gh pr create", r.kinds())
        self.assertIn("already open", out)

    def test_dry_run_runs_nothing_and_prints_the_text(self):
        code, r, out = self.go(["--dry-run", "--issue", "#12", "--draft"], files=("Wuber/UI/Fold.lua",))
        self.assertEqual(code, 0, out)
        self.assertEqual((r.ran, r.archived), ([], []))
        for s in ("would run: lua5.1 tools/check.lua", "would run: bash tools/suite-par.sh . 16",
                  "would run: lua5.1 tools/layout-check.lua", "would run: git push origin " + SHA + ":refs/heads/claude/12",
                  "--draft", "Fixes #12", "## What changed", "nothing was run, pushed or opened"):
            self.assertIn(s, out)

    def test_push_or_pr_failure_is_exit_3(self):
        code, r, _ = self.go(codes={"git push": (1, "rejected")})
        self.assertEqual(code, 3)
        self.assertNotIn("gh pr create", r.kinds())
        code, r, _ = self.go(codes={"gh pr create": (1, "no permission")})
        self.assertEqual(code, 3)

    def test_a_failed_fetch_is_said_and_the_run_goes_on(self):
        args = [a for a in BASE if a != "--no-fetch"]
        code, r, out = self.go(args=args, codes={"git fetch": (1, "offline")})
        self.assertEqual(code, 0, out)
        self.assertIn("git fetch origin main failed", out)

    def test_text_from_a_file_and_issue_numbers(self):
        p = os.path.join(tempfile.mkdtemp(), "what.md")
        with open(p, "w") as f:
            f.write("From a file.\n")
        a = pr.parse_args(BASE + ["--what", "@" + p, "--issue", "#7"])
        self.assertEqual((a.what, a.issue), ("From a file.", "7"))
        with self.assertRaises(SystemExit):
            pr.parse_args(BASE + ["--issue", "seven"])

    def test_bash_choice(self):
        self.assertEqual(pr.find_bash("/x/bash"), "/x/bash")
        os.environ["PR_READY_BASH"] = "/y/bash"
        try:
            self.assertEqual(pr.find_bash(), "/y/bash")
        finally:
            del os.environ["PR_READY_BASH"]
        self.assertEqual(pr.find_bash(osname="posix", which=lambda n: "/usr/bin/bash"), "/usr/bin/bash")
        git = tempfile.mkdtemp().replace("\\", "/") + "/Git"
        os.makedirs(git + "/usr/bin")
        open(git + "/usr/bin/bash.exe", "w").close()
        c, d = "C" + ":", "D" + ":"       # (a drive letter written plainly would trip the scrub's path pattern)
        wsl = lambda n: c + "\\Windows\\System32\\bash.exe"
        self.assertEqual(pr.find_bash(osname="nt", which=wsl, exec_path=git + "/mingw64/libexec/git-core"), git + "/usr/bin/bash.exe")
        for bad in (c + "\\Windows\\System32\\bash.exe", c + "\\Users\\u\\AppData\\Local\\Microsoft\\WindowsApps\\bash.exe"):
            self.assertIsNone(pr.find_bash(osname="nt", which=lambda n, b=bad: b, exec_path=""))
        self.assertEqual(pr.find_bash(osname="nt", which=lambda n: d + "\\tools\\msys\\bash.exe", exec_path=""), d + "\\tools\\msys\\bash.exe")


if __name__ == "__main__":
    unittest.main()
