#!/usr/bin/env python3
"""tools/pr-ready.py: checks, push and pull request for a finished branch, in one command.

From a branch in your own git worktree it runs, in order, and stops at the first failure with a short summary:
  1. tools/check.lua
  2. the tests: the whole suite in 16 shards (tools/suite-par.sh), or with --quick only the tests for the
     changed files (tools/tests-for.lua --run; it falls back to the whole suite when that says so), and the
     Python test files (test_*.py) the branch changed
  3. the layout check (tools/layout-check.lua) when a file under Wuber/UI/ changed (--quick: only the shots
     the changed files draw)
  4. the scrub check of the commit being pushed (every file and file name, read from git, nothing unpacked)
     and of the pull request text, with the public list and, with --private-list <file>, that list too. The
     scrub rules and the public list are taken from the base (origin/main), so a branch cannot loosen its
     own check. Hits are shown as file:line:column and pattern name, never the text.
then pushes the checked commit to its branch (never main, never force) and opens a pull request to main from
a template: what changed, why, the test that proves it, the check results and "Fixes #n" (--issue n).

Usage (from your worktree):
  python tools/pr-ready.py --prefix claude/ --title "#12 Fold keeps its place" \
      --what "..." --why "..." --test "..." --issue 12 [--quick] [--private-list FILE] [--draft] [--dry-run]
  --what/--why/--test/--not-proven take text, or @path to read the text from a file.
  --dry-run prints every command and the pull request text, and runs nothing.
Exit codes: 0 done (or dry run), 1 a check failed, 2 bad use (wrong branch, uncommitted or untracked files,
nothing to send, a missing tool, gh not logged in), 3 the push or the pull request failed.
Works on Windows and Linux. Needs git, Lua 5.1 (--lua, else WUBER_LUA, LUA, or lua5.1 on the PATH; never
LuaJIT), bash for the suite (--bash, else PR_READY_BASH; on Windows Git's own bash, never WSL's), python and gh.
Each step's output: tests/out/pr-ready/<step>.log (not committed); python tools/log-digest.py reads them.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tarfile
import io
import time
import types

PREFIXES = ("claude/", "google/")
LOG_DIR = os.path.join("tests", "out", "pr-ready")


def here_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read_text(value):
    """'@path' -> the file's text; anything else as it is."""
    if value and value.startswith("@") and len(value) > 1:
        with open(value[1:], encoding="utf-8") as f:
            return f.read().strip()
    return (value or "").strip()


def _quote(s):
    return s if re.match(r"^[\w@%+=:,./\\-]+$", s) else '"' + s.replace('"', '\\"') + '"'


class Runner:
    """Runs commands, or in a dry run only prints them. The tests replace _exec, query and archive."""

    def __init__(self, cwd, dry_run=False, out=sys.stdout):
        self.cwd, self.dry_run, self.out = cwd, dry_run, out

    def say(self, line):
        print(line, file=self.out)
        self.out.flush()

    def run(self, cmd, env=None, log=None, shown=None):
        """A command that does something (a check, a push). Dry run: printed only, (0, '')."""
        if self.dry_run:
            self.say("would run: " + (shown or " ".join(_quote(c) for c in cmd)))
            return 0, ""
        code, text = self._exec(cmd, env)
        if log:
            os.makedirs(os.path.dirname(log), exist_ok=True)
            with open(log, "w", encoding="utf-8") as f:
                f.write(text)
        return code, text

    def _exec(self, cmd, env):
        full_env = dict(os.environ)
        full_env.update(env or {})
        try:
            p = subprocess.run(cmd, cwd=self.cwd, env=full_env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except OSError as e:
            return 127, "%s: %s" % (cmd[0], e)
        return p.returncode, p.stdout.decode("utf-8", "replace")

    def query(self, cmd):
        """A read-only command (git rev-parse, git show, gh auth status ...): runs even in a dry run."""
        try:
            p = subprocess.run(cmd, cwd=self.cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except OSError as e:
            return 127, str(e)
        return p.returncode, p.stdout.decode("utf-8", "replace").strip()

    def archive(self, rev):
        """The commit's files as tar bytes (git archive), or None."""
        try:
            p = subprocess.run(["git", "archive", "--format=tar", rev], cwd=self.cwd, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE)
        except OSError:
            return None
        return p.stdout if p.returncode == 0 else None


def find_bash(explicit=None, osname=None, which=shutil.which, exec_path=None):
    """The bash for tools/suite-par.sh. On Windows Git's own bash, found from git --exec-path; never WSL's
    launcher (System32\\bash.exe or WindowsApps\\bash.exe)."""
    for c in (explicit, os.environ.get("PR_READY_BASH")):
        if c:
            return c
    if (osname or os.name) != "nt":
        return which("bash")
    if exec_path is None:
        try:
            exec_path = subprocess.run(["git", "--exec-path"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
                                       ).stdout.decode("utf-8", "replace").strip()
        except OSError:
            exec_path = ""
    d = exec_path.replace("\\", "/").rstrip("/")
    for _ in range(4):  # .../Git/mingw64/libexec/git-core -> .../Git
        if not d or "/" not in d:
            break
        d = d.rsplit("/", 1)[0]
        for rel in ("bin/bash.exe", "usr/bin/bash.exe"):
            if os.path.isfile(d + "/" + rel):
                return d + "/" + rel
    b = which("bash")
    if b and not any(x in b.lower().replace("/", "\\") for x in ("\\system32\\", "\\windowsapps\\")):
        return b
    return None


def find_lua(explicit=None):
    return explicit or os.environ.get("WUBER_LUA") or os.environ.get("LUA") or "lua5.1"


def last_lines(text, n=12):
    return [l for l in text.splitlines() if l.strip()][-n:]


def summary_line(step, text):
    """One line of result for the pull request's check list."""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    pats = {"tests": r"\d+ passed, \d+ failed", "check": r"^check:", "layout": r"problems",
            "pytests": r"^(Ran \d+ tests?|OK\b|FAILED)"}
    if step in pats:
        for l in reversed(lines):
            if re.search(pats[step], l):
                return l[:200]
    return lines[-1][:200] if lines else ""


def digest(text):
    """The short failure summary of tools/log-digest.py (or the last lines when it is not there)."""
    try:
        import importlib.util
        p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "log-digest.py")
        spec = importlib.util.spec_from_file_location("log_digest", p)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        return m.digest(text.splitlines())[0]
    except Exception:
        return last_lines(text)


def load_scrub(r, repo, base):
    """scrub-check.py's functions and the public list, from the base when it has them (else this branch)."""
    code, src = r.query(["git", "show", base + ":scrub-check.py"])
    where = "base"
    if code != 0 or "def scan_text" not in src:
        with open(os.path.join(repo, "scrub-check.py"), encoding="utf-8") as f:
            src, where = f.read(), "branch"
    mod = types.ModuleType("scrub_check")
    exec(compile(src, "scrub-check.py", "exec"), mod.__dict__)
    code, pub = r.query(["git", "show", base + ":scrub-patterns.public.txt"])
    if code != 0 or not pub.strip():
        with open(os.path.join(repo, "scrub-patterns.public.txt"), encoding="utf-8") as f:
            pub = f.read()
        where += ", public list from the branch"
    return mod, pub, where


def parse_patterns(mod, text, label):
    """scrub-check.py's load_patterns() reads a file; this gives it the text through a one-file temp copy."""
    import tempfile
    fd, path = tempfile.mkstemp(suffix=".txt")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        return mod.load_patterns(path)
    except ValueError as e:
        raise ValueError("%s list: %s" % (label, str(e).split(":", 1)[-1].strip()))
    finally:
        os.remove(path)


def scrub_scan(mod, tar_bytes, extra_texts, pats, allow):
    """Like scrub-check.py's scan_tree, over a tar in memory: names, then contents; binary files skipped.
    A hit in a file or folder name is shown with that name masked, so no hit's text is ever printed."""
    hits, scanned, binary, seen, bad_names = [], 0, 0, set(), set()
    with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as t:
        for m in t.getmembers():
            parts = m.name.strip("/").split("/")
            for i in range(len(parts)):
                rel = "/".join(parts[: i + 1])
                if rel in seen:
                    continue
                seen.add(rel)
                found = mod.scan_text(rel, parts[i], pats, allow)
                if found:
                    bad_names.add(rel)
                    shown = "/".join(parts[:i] + ["<a name here>"])
                    hits += [(shown, 0, h[2], h[3]) for h in found]
            if not m.isfile():
                continue
            data = t.extractfile(m).read()
            if b"\x00" in data[:8192]:
                binary += 1
                continue
            scanned += 1
            masked = any("/".join(parts[: i + 1]) in bad_names for i in range(len(parts)))
            label = "<a file whose path has a hit>" if masked else m.name
            hits += mod.scan_text(label, data.decode("utf-8", "replace"), pats, allow)
    for label, text in extra_texts:
        scanned += 1
        hits += mod.scan_text(label, text, pats, allow)
    return hits, scanned, binary


def pr_body(a, results, skipped):
    rows = []
    for step, label in (("check", "tools/check.lua"), ("tests", "tests"), ("pytests", "Python tests (changed test_*.py)"),
                        ("layout", "layout check"), ("scrub", "scrub check")):
        if step in results:
            rows.append("- %s: pass (%s)" % (label, results[step]))
        elif step in skipped:
            rows.append("- %s: not run (%s)" % (label, skipped[step]))
    return "\n".join([
        "## What changed", a.what, "",
        "## Why", a.why, "",
        "## Issue", "Fixes #%s" % a.issue if a.issue else "No issue.", "",
        "## Test that fails before and passes after", a.test, "",
        "## Not proven", a.not_proven or "Nothing beyond what the checks below cover.", "",
        "## Check results",
        *rows, "",
        "Checks run by tools/pr-ready.py on the pushed commit.", "",
        "By opening this pull request I agree that my contribution is licensed under the MIT License (see LICENSE).",
    ]) + "\n"


def parse_args(argv):
    p = argparse.ArgumentParser(prog="pr-ready.py", description=__doc__.split("\n\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog="\n".join(__doc__.split("\n")[2:]))
    p.add_argument("--prefix", required=True, choices=PREFIXES, help="branch prefix: claude/ or google/")
    p.add_argument("--title", required=True, help='pull request title, e.g. "#12 Fold keeps its place"')
    p.add_argument("--what", required=True, help="what changed (text or @file)")
    p.add_argument("--why", required=True, help="why (text or @file)")
    p.add_argument("--test", required=True, help="the test that fails before and passes after (text or @file)")
    p.add_argument("--not-proven", default="", help="what the checks cannot prove, e.g. the in-game check (text or @file)")
    p.add_argument("--issue", help='issue number: adds "Fixes #n"')
    p.add_argument("--quick", action="store_true", help="only the tests for the changed files, not the whole suite")
    p.add_argument("--private-list", help="also scrub with this private pattern list (a file outside the repo)")
    p.add_argument("--base", default="origin/main", help="what the branch is compared with (default origin/main)")
    p.add_argument("--shards", type=int, default=16, help="suite shards (default 16)")
    p.add_argument("--lua", help="Lua 5.1 interpreter (default WUBER_LUA, LUA, lua5.1)")
    p.add_argument("--bash", help="bash for the suite (default PR_READY_BASH; on Windows Git's bash)")
    p.add_argument("--python", default=sys.executable, help="python for changed test_*.py files (default this one)")
    p.add_argument("--draft", action="store_true", help="open the pull request as a draft")
    p.add_argument("--no-fetch", action="store_true", help="do not git fetch the base first")
    p.add_argument("--dry-run", action="store_true", help="print what would run and the pull request text; run nothing")
    p.add_argument("--repo", default=None, help="the worktree (default: the one this script is in)")
    a = p.parse_args(argv)
    a.issue = (a.issue or "").lstrip("#") or None
    if a.issue and not a.issue.isdigit():
        p.error("--issue takes a number")
    for k in ("what", "why", "test", "not_proven"):
        setattr(a, k, read_text(getattr(a, k)))
    return a


def main(argv=None, runner=None, out=sys.stdout):
    a = parse_args(sys.argv[1:] if argv is None else argv)
    repo = os.path.abspath(a.repo or here_root())
    r = runner or Runner(repo, a.dry_run, out)
    say = r.say
    t0 = time.time()

    # where we are, and what may go
    code, branch = r.query(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    if code != 0:
        say("pr-ready: STOP: %s is not a git checkout" % repo)
        return 2
    if branch in ("main", "master", "HEAD"):
        say("pr-ready: STOP: on %s; work on your own branch (%s<n>)" % (branch, a.prefix))
        return 2
    if not branch.startswith(a.prefix) or len(branch) <= len(a.prefix):
        say("pr-ready: STOP: branch %s does not start with %s" % (branch, a.prefix))
        return 2
    _, gitdir = r.query(["git", "rev-parse", "--git-dir"])
    _, common = r.query(["git", "rev-parse", "--git-common-dir"])
    if os.path.normcase(os.path.abspath(os.path.join(repo, gitdir))) == \
            os.path.normcase(os.path.abspath(os.path.join(repo, common))):
        say("pr-ready: STOP: this is the main checkout; run it in your own worktree (git worktree add)")
        return 2
    _, dirty = r.query(["git", "status", "--porcelain"])
    if dirty:
        say("pr-ready: STOP: uncommitted or untracked files (commit or remove them; the checks must see exactly the commit that is pushed):")
        for l in dirty.splitlines()[:8]:
            say("  " + l)
        return 2
    code, sha = r.query(["git", "rev-parse", "HEAD"])
    if code != 0 or not re.match(r"^[0-9a-f]{7,64}$", sha):
        say("pr-ready: STOP: cannot read HEAD")
        return 2
    code, _ = r.query(["gh", "auth", "status"])
    if code != 0 and not a.dry_run:
        say("pr-ready: STOP: gh is missing or not logged in (gh auth login); nothing was run or pushed")
        return 2
    if code != 0:
        say("pr-ready: note: gh is missing or not logged in; a real run would stop here")
    say("pr-ready: %s at %s in %s%s" % (branch, sha[:10], repo, " (dry run)" if a.dry_run else ""))

    if not a.no_fetch:
        remote, _, ref = a.base.partition("/")
        if ref:
            code, _ = r.run(["git", "fetch", "-q", remote, ref])
            if code != 0:
                say("pr-ready: note: git fetch %s %s failed; comparing with the local %s" % (remote, ref, a.base))
    code, mb = r.query(["git", "merge-base", a.base, sha])
    if code != 0 or not mb:
        say("pr-ready: STOP: cannot compare with %s (git fetch? --base?)" % a.base)
        return 2
    code, diff = r.query(["git", "-c", "core.quotepath=false", "diff", "--name-only", "--no-renames", mb, sha])
    files = [l.strip() for l in diff.splitlines() if l.strip()] if code == 0 else None
    if files is None:
        say("pr-ready: STOP: git diff against %s failed" % a.base)
        return 2
    if not files:
        say("pr-ready: STOP: no commits on %s that %s does not have" % (branch, a.base))
        return 2
    exists = lambda f: os.path.exists(os.path.join(repo, f))
    present = [f for f in files if exists(f)]
    gone = [f for f in files if not exists(f)]
    ui = [f for f in files if f.startswith("Wuber/UI/")]
    say("changed: %d files%s%s" % (len(files), (", %d under Wuber/UI/" % len(ui)) if ui else "",
                                    (", %d deleted" % len(gone)) if gone else ""))

    lua = find_lua(a.lua)
    log = lambda step: os.path.join(repo, LOG_DIR, step + ".log")
    results, skipped = {}, {}

    def step(name, cmd, env=None, shown=None):
        say("[%s] %s" % (name, shown or " ".join(_quote(c) for c in cmd)))
        s = time.time()
        code, text = r.run(cmd, env=env, log=log(name))
        if code != 0:
            say("pr-ready: FAIL at %s (exit %s, %d s). Log: %s" % (name, code, time.time() - s, os.path.join(LOG_DIR, name + ".log")))
            for l in digest(text):
                say("  " + l)
            return None
        return ("dry run" if a.dry_run else "%s, %d s" % (summary_line(name, text) or "exit 0", time.time() - s))

    # 1 check.lua
    res = step("check", [lua, "tools/check.lua"])
    if res is None:
        return 1
    results["check"] = res
    # 2 tests
    full = not a.quick
    if a.quick:
        if any(f.startswith(("Wuber/", "tests/")) for f in gone):
            say("tests: a Wuber/ or tests/ file was deleted; running the whole suite")
            full = True
        else:
            cmd = [lua, "tools/tests-for.lua", "--run"] + present
            say("[tests] %s tools/tests-for.lua --run <%d changed files>" % (lua, len(present)))
            s = time.time()
            code, text = r.run(cmd, env={"WUBER_LUA": lua}, log=log("tests"))
            if code == 3:
                say("tests-for.lua: this change needs the whole suite; running it")
                full = True
            elif code != 0:
                say("pr-ready: FAIL at tests (exit %s, %d s). Log: %s" % (code, time.time() - s, os.path.join(LOG_DIR, "tests.log")))
                for l in digest(text):
                    say("  " + l)
                return 1
            else:
                results["tests"] = "dry run" if a.dry_run else "quick: %s, %d s" % (summary_line("tests", text) or "exit 0", time.time() - s)
    if full:
        bash = find_bash(a.bash)
        if not bash:
            say("pr-ready: STOP: no bash for tools/suite-par.sh (--bash or PR_READY_BASH)")
            return 2
        res = step("tests", [bash, "tools/suite-par.sh", ".", str(a.shards)], env={"WUBER_LUA": lua})
        if res is None:
            return 1
        results["tests"] = "whole suite, %d shards: %s" % (a.shards, res)
    pyt = [f for f in present if re.match(r"^(tools/)?test_[\w-]+\.py$", f)]
    for f in pyt:
        res = step("pytests", [a.python, f])
        if res is None:
            return 1
        results["pytests"] = (results.get("pytests", "") + "; " if "pytests" in results else "") + f + ": " + res
    # 3 layout
    if ui:
        ui_present = [f for f in ui if exists(f)]
        quick_ui = a.quick and len(ui_present) == len(ui)
        res = step("layout", [lua, "tools/layout-check.lua"] + (["--files"] + ui_present if quick_ui else []))
        if res is None:
            return 1
        results["layout"] = res
    else:
        skipped["layout"] = "no file under Wuber/UI/ changed"
    # 4 scrub: the commit's files and names + the pull request text; rules and public list from the base
    lists_text = "public" + (" + private" if a.private_list else "")
    say("[scrub] commit %s and the pull request text, %s list" % (sha[:10], lists_text))
    if a.private_list and not os.path.isfile(a.private_list):
        say("pr-ready: STOP: no private list at the path given")
        return 2
    if a.dry_run:
        r.run([], shown="scrub of git archive %s (in memory) + the pull request text, %s list" % (sha[:10], lists_text))
        results["scrub"] = "dry run"
    else:
        try:
            mod, pub, where = load_scrub(r, repo, a.base)
            lists = [("public", parse_patterns(mod, pub, "public"))]
            if a.private_list:
                with open(a.private_list, encoding="utf-8") as f:
                    lists.append(("private", parse_patterns(mod, f.read(), "private")))
        except (ValueError, OSError, SyntaxError) as e:
            say("pr-ready: FAIL at scrub: cannot load the scrub rules: %s" % e)
            return 1
        tar = r.archive(sha)
        if tar is None:
            say("pr-ready: FAIL at scrub: git archive %s failed" % sha[:10])
            return 1
        body_now = pr_body(a, results, skipped)
        notes = []
        for label, (pats, allow) in lists:
            hits, scanned, binary = scrub_scan(mod, tar, [("pull request title", a.title), ("pull request text", body_now)], pats, allow)
            if hits:
                say("pr-ready: FAIL at scrub, %s list: %d hits (the text is never shown):" % (label, len(hits)))
                for h in hits[:15]:
                    say("  %s:%d:%d  %s" % h)
                return 1
            notes.append("%s list 0 hits" % label)
        results["scrub"] = "%s (%d text files, %d binary skipped; rules from the %s)%s" % (
            ", ".join(notes), scanned, binary, where, "" if a.private_list else "; private list not run")

    body = pr_body(a, results, skipped)
    # 5 push the checked commit: never main, never force
    if branch in ("main", "master") or not branch.startswith(a.prefix):
        return 2
    say("[push] %s -> origin %s" % (sha[:10], branch))
    code, text = r.run(["git", "push", "origin", sha + ":refs/heads/" + branch])
    if code != 0:
        say("pr-ready: FAIL at push: " + "; ".join(last_lines(text, 3)))
        return 3
    r.run(["git", "branch", "--set-upstream-to", "origin/" + branch])
    # 6 the pull request (unless one is already OPEN for this branch)
    code, url = r.query(["gh", "pr", "list", "--head", branch, "--state", "open", "--json", "url", "--jq", ".[0].url"])
    if not a.dry_run and code == 0 and url.startswith("http"):
        say("pr-ready: a pull request is already open for %s: %s (pushed the new commits; its text was not changed)" % (branch, url))
        say("pr-ready: DONE in %d s" % (time.time() - t0))
        return 0
    if a.dry_run:
        say("--- pull request text ---")
        say("title: " + a.title)
        say(body.rstrip())
        say("---")
        cmd = ["gh", "pr", "create", "--base", "main", "--head", branch, "--title", a.title, "--body-file", "<the text above>"]
        if a.draft:
            cmd.append("--draft")
        r.run(cmd)
        say("pr-ready: dry run done; nothing was run, pushed or opened")
        return 0
    import tempfile
    fd, body_file = tempfile.mkstemp(suffix=".md", prefix="pr-ready-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(body)
    cmd = ["gh", "pr", "create", "--base", "main", "--head", branch, "--title", a.title, "--body-file", body_file]
    if a.draft:
        cmd.append("--draft")
    try:
        code, text = r.run(cmd)
    finally:
        os.remove(body_file)
    if code != 0:
        say("pr-ready: FAIL at gh pr create: " + "; ".join(last_lines(text, 3)))
        return 3
    url = next((l.strip() for l in text.splitlines() if l.strip().startswith("http")), text.strip())
    say("pr-ready: DONE in %d s: %s" % (time.time() - t0, url))
    return 0


if __name__ == "__main__":
    sys.exit(main())
