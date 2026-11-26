#!/usr/bin/env python
"""Failing-first gate: a test added since BASE must FAIL on BASE's addon code.

  python tools/failing-first.py --target <tree> --base <commit> [--repo <git repo>] [--out <dir>]
                                [--scratch <dir>] [--timeout <secs>] [--keep]

Added tests = test names (test("..", T.test("..", testOutside(, pending("..) found in the target's tests/ folder
that are not found in BASE's tests/ folder. They are run in a scratch copy of the target tree whose Wuber/ is
replaced by 'git archive <base> Wuber', so the target's tests and helpers run on the old addon.
  - passes on base       -> the gate FAILS, unless the test is a guard: a line "name<TAB>reason" in
                            tests/fixtures/guards.txt (reason required), or a comment line "-- guard: <reason>"
                            directly above its test( line.
  - fails on base        -> good (failing-first). A crash that is not an assertion (nil call, missing helper)
                            counts the same and is labelled "error" in the report.
  - pending              -> reported, not judged.
--base-tools (L25 C8): a test whose line above says "-- guard: infra" (a test of a tool or of tests/lib) is
also run in a second scratch whose tools/ and tests/lib/ are the base's (tests/run.lua and the test files stay the
target's). It must FAIL there ("infra test proved"); if it passes it is reported "infra guard passes on base
tools" and the gate fails. Without the flag an infra guard counts as a guard, as before.
tests/run.lua's WUBER_ONLY_TESTS / WUBER_BREAKIT_OUT hooks are used when it has them; when it has not
(v2.4 before the break-it merge) the scratch copy's run.lua gets a tiny patch with the same effect.
--base-fake auto|yes|no (round fga, job 2611): when tests/harness.lua or tests/lib/ changed since BASE (auto), the
base run also uses the base's fake game, so a test of a fake-game fix must fail on the old fake. --base-tools now
also swaps tests/harness.lua (it is part of the fake).
Exit 0 pass, 1 fail, 2 could not run. Last line: GAUNTLET failing-first result=... (see main).
"""
import argparse, os, re, shutil, subprocess, sys, tarfile, io, time

LUA = os.environ.get("WUBER_LUA") or os.environ.get("LUA") or "lua5.1"
CALL = re.compile(r'''(?<![\w.])((?:T\.)?(?:test|testOutside|pending))\(\s*(?:"((?:[^"\\\n]|\\.)*)"|'((?:[^'\\\n]|\\.)*)')(?!\s*\.\.)''')
GUARD = re.compile(r'^\s*--\s*guard:\s*(\S.*?)\s*$')


def unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def parse_tests(text):
    """-> list of (kind, name, guard_reason_or_None) for one Lua file's text."""
    out, lines = [], text.split("\n")
    for i, line in enumerate(lines):
        for m in CALL.finditer(line):
            if line[:m.start()].strip().startswith("--"):
                continue
            kind = "pending" if m.group(1).endswith("pending") else "test"
            name = unescape(m.group(2) if m.group(2) is not None else m.group(3))
            g = GUARD.match(lines[i - 1]) if i > 0 else None
            out.append((kind, name, g.group(1) if g else None))
    return out


def collect_dir(root):
    res = {}
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in ("out", ".git")]
        for f in fn:
            if f.endswith(".lua"):
                p = os.path.join(dp, f)
                try:
                    txt = open(p, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                for kind, name, g in parse_tests(txt):
                    res.setdefault(name, (kind, g, os.path.relpath(p, root).replace("\\", "/")))
    return res


def collect_base(repo, base):
    r = subprocess.run(["git", "-C", repo, "archive", base, "tests"], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError("git archive %s tests failed: %s" % (base, r.stderr.decode(errors="replace")[:300]))
    names = set()
    with tarfile.open(fileobj=io.BytesIO(r.stdout)) as tf:
        for m in tf:
            if m.isfile() and m.name.endswith(".lua"):
                txt = tf.extractfile(m).read().decode("utf-8", "replace")
                for _k, name, _g in parse_tests(txt):
                    names.add(name)
    return names


def load_guards(path):
    g = {}
    if os.path.exists(path):
        for n, line in enumerate(open(path, encoding="utf-8").read().split("\n"), 1):
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t", 1)
            if len(parts) < 2 or not parts[1].strip():
                raise ValueError("%s:%d: a guard needs a reason (name<TAB>reason)" % (path, n))
            g[parts[0]] = parts[1].strip()
    return g


def parse_out(text):
    """WUBER_BREAKIT_OUT lines -> {name: (ok, why)}"""
    res, last = {}, None
    for line in text.split("\n"):
        p = line.split("\t")
        if p[0] in ("ok", "fail") and len(p) >= 3:
            last = p[2]
            res[last] = (p[0] == "ok", "")
        elif p[0] == "why" and last is not None and len(p) >= 2:
            res[last] = (False, p[1])
    return res


def is_error(why):
    # a crash that is not an assertion of the test (eq/ok report "<what>: got ..., want ...")
    return bool(re.search(r"attempt to|bad argument|nil value|module '|cannot open|unexpected symbol|stack traceback", why or "")) and "want" not in (why or "")[:200]


def is_infra(reason):
    return bool(reason) and reason.strip().lower().startswith("infra")


def judge(added, guards, results, infra_results=None):
    """added: {name: (kind, guard_comment, file)}; results: {name: (ok, why)} -> rows, counts"""
    rows, c = [], dict(new=0, failed_on_base=0, guards=0, passed_on_base=0, pending=0, notrun=0, infra_proved=0, infra_bad=0)
    for name in sorted(added):
        kind, comment, f = added[name]
        c["new"] += 1
        if kind == "pending":
            c["pending"] += 1
            rows.append((name, f, "pending", "reported, not judged"))
            continue
        res = results.get(name)
        if infra_results is not None and is_infra(guards.get(name) or comment):
            ires = infra_results.get(name)
            if ires is None:
                c["notrun"] += 1
                rows.append((name, f, "NOT RUN", "no result from the base-tools run"))
            elif ires[0]:
                c["infra_bad"] += 1
                rows.append((name, f, "INFRA GUARD PASSES ON BASE TOOLS", "infra guard passes on base tools"))
            else:
                c["infra_proved"] += 1
                rows.append((name, f, "INFRA PROVED", "infra test proved: fails on the base tools (%s)" % (ires[1] or "")))
            continue
        if res is None:
            reason = guards.get(name) or comment
            if reason:  # job 211: a test tests/run.lua never runs (e.g. a layout-check --selftest test), excused with a reason
                c["guards"] += 1
                rows.append((name, f, "NOT RUN (guard)", reason))
                continue
            c["notrun"] += 1
            rows.append((name, f, "NOT RUN", "no result from the base run"))
        elif not res[0]:
            c["failed_on_base"] += 1
            tag = "FAIL (error, not an assertion)" if is_error(res[1]) else "FAIL (assertion)"
            rows.append((name, f, tag, res[1]))
        else:
            reason = guards.get(name) or comment
            if reason:
                c["guards"] += 1
                rows.append((name, f, "PASS (guard)", reason))
            else:
                c["passed_on_base"] += 1
                rows.append((name, f, "PASS ON BASE", "passes on the old addon: not failing-first"))
    return rows, c


RUN_PATCH = [
    ("local results = {}", "local results = {}\nlocal WF = {}\ndo local p = os.getenv('WF_ONLY') if p then local fh = io.open(p) for l in fh:lines() do WF[l] = true end fh:close() WF.on = true WF.out = io.open(os.getenv('WF_OUT'), 'a') end end"),
    ("local function test(name, fn)", "local function test(name, fn)\n\tif WF.on and not WF[name] then skipped = skipped + 1 return end"),
    ("results[#results + 1] = { name = name, ok = ok }", "results[#results + 1] = { name = name, ok = ok }\n\tif WF.out then WF.out:write((ok and 'ok' or 'fail') .. '\\t0\\t' .. name .. '\\n') if not ok then WF.out:write('why\\t' .. tostring(err):sub(1, 300):gsub('[\\t\\r\\n]', ' ') .. '\\n') end WF.out:flush() end"),
]


def patch_run(path):
    txt = open(path, encoding="utf-8", newline="").read()
    if "WUBER_ONLY_TESTS" in txt:
        return "env"
    nl = "\r\n" if "\r\n" in txt else "\n"
    for a, b in RUN_PATCH:
        if txt.count(a) != 1:
            raise RuntimeError("tests/run.lua: anchor %r found %d times; cannot patch" % (a, txt.count(a)))
        txt = txt.replace(a, b.replace("\n", nl))
    open(path, "w", encoding="utf-8", newline="").write(txt)
    return "patch"


def make_scratch(target, repo, base, scratch, base_tools=False):
    def ign(d, names):
        rel = os.path.relpath(d, target).replace("\\", "/")
        skip = {".git", "node_modules"}
        if rel == ".":
            skip |= {"Wuber", "release", "failing-first-out"}  # the default --out sits in the target: never copy it into itself
        if rel == "tests":
            skip |= {"out"}
        return [n for n in names if n in skip]
    shutil.copytree(target, scratch, ignore=ign)
    r = subprocess.run(["git", "-C", repo, "archive", base, "Wuber"], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError("git archive %s Wuber failed: %s" % (base, r.stderr.decode(errors="replace")[:300]))
    with tarfile.open(fileobj=io.BytesIO(r.stdout)) as tf:
        tf.extractall(scratch)
    if base_tools:  # tools/ and tests/lib/ from the base; tests/run.lua and the test files stay the target's
        for sub in (("tools", "tests/lib", "tests/harness.lua") if base_tools is True else base_tools):
            r = subprocess.run(["git", "-C", repo, "archive", base, sub], capture_output=True)
            if r.returncode != 0:
                raise RuntimeError("git archive %s %s failed: %s" % (base, sub, r.stderr.decode(errors="replace")[:300]))
            dst = os.path.join(scratch, *sub.split("/"))
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            with tarfile.open(fileobj=io.BytesIO(r.stdout)) as tf:
                tf.extractall(scratch)
    os.makedirs(os.path.join(scratch, "tests", "out"), exist_ok=True)


def fake_changed(target, base):
    """True when tests/harness.lua or tests/lib/ differ between BASE and the target tree (round fga, job 2611:
    a fake-game round's new tests must fail on the base's fake, not only on the base's addon)."""
    r = subprocess.run(["git", "-C", target, "diff", "--quiet", base, "--", "tests/harness.lua", "tests/lib"], capture_output=True)
    return r.returncode == 1


def run_base(scratch, names, timeout, env_extra):
    mode = patch_run(os.path.join(scratch, "tests", "run.lua"))
    lst, out = os.path.join(scratch, "wf-only.txt"), os.path.join(scratch, "wf-out.txt")
    open(lst, "w", encoding="utf-8").write("\n".join(names) + "\n")
    open(out, "w").close()
    env = dict(os.environ)
    env.update(env_extra)
    if mode == "env":
        env.update(WUBER_ONLY_TESTS=lst, WUBER_BREAKIT_OUT=out)
    else:
        env.update(WF_ONLY=lst, WF_OUT=out)
    log = open(os.path.join(scratch, "wf-run.log"), "w")
    try:
        p = subprocess.run([LUA, "tests/run.lua"], cwd=scratch, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
        code = p.returncode
    except subprocess.TimeoutExpired:
        code = None
    log.close()
    return parse_out(open(out, encoding="utf-8", errors="replace").read()), code, mode


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True)
    ap.add_argument("--base", required=True)
    ap.add_argument("--repo")
    ap.add_argument("--out")
    ap.add_argument("--scratch")
    ap.add_argument("--timeout", type=int, default=1500)
    ap.add_argument("--base-tools", action="store_true", help="also run '-- guard: infra' tests on the base's tools/ and tests/lib/")
    ap.add_argument("--rec-dir", help="own copy of WuberRec (WUBER_REC_DIR)")
    ap.add_argument("--base-fake", choices=("auto", "yes", "no"), default="auto",
                    help="run the new tests on the base's fake game too (tests/harness.lua, tests/lib/); auto = when the target changed it")
    a = ap.parse_args(argv)
    target = os.path.abspath(a.target)
    repo = os.path.abspath(a.repo) if a.repo else target
    out = os.path.abspath(a.out or os.path.join(target, "failing-first-out"))
    os.makedirs(out, exist_ok=True)

    def fail2(msg):
        print("failing-first: " + msg)
        print("GAUNTLET failing-first result=error new=0 failed_on_base=0 guards=0 passed_on_base=0 pending=0")
        return 2
    try:
        now = collect_dir(os.path.join(target, "tests"))
        before = collect_base(repo, a.base)
        added = {n: v for n, v in now.items() if n not in before}
        guards = load_guards(os.path.join(target, "tests", "fixtures", "guards.txt"))
        runnable = [n for n, v in added.items() if v[0] == "test"]
        results, code, mode, infra_results = {}, 0, "none", None
        infra_names = [n for n in runnable if is_infra(guards.get(n) or added[n][1])] if a.base_tools else []
        if a.base_tools:
            infra_results = {}
        if runnable:
            scratch = os.path.abspath(a.scratch or os.path.join(out, "scratch-%d" % int(time.time())))
            fake = a.base_fake == "yes" or (a.base_fake == "auto" and fake_changed(target, a.base))
            if fake:
                print("failing-first: the fake game changed since the base: new tests run on the base's addon AND fake game")
            make_scratch(target, repo, a.base, scratch, ("tests/lib", "tests/harness.lua") if fake else False)
            env = {"WUBER_LAB_DIR": os.environ.get("WUBER_LAB_DIR") or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lab", "WuberLab")}
            if os.environ.get("WUBER_RR141"):
                env["WUBER_RR141"] = os.environ["WUBER_RR141"]
            if a.rec_dir or os.environ.get("WUBER_REC_DIR"):
                env["WUBER_REC_DIR"] = a.rec_dir or os.environ["WUBER_REC_DIR"]
            results, code, mode = run_base(scratch, runnable, a.timeout, env)
            if code is None:
                return fail2("the base run timed out after %ds" % a.timeout)
            if not results:
                return fail2("the base run produced no per-test results (exit %s); see %s" % (code, os.path.join(scratch, "wf-run.log")))
            if infra_names:
                scratch2 = scratch + "-basetools"
                make_scratch(target, repo, a.base, scratch2, True)
                infra_results, code2, _m = run_base(scratch2, infra_names, a.timeout, env)
                if code2 is None:
                    return fail2("the base-tools run timed out after %ds" % a.timeout)
    except Exception as e:
        return fail2("%s: %s" % (type(e).__name__, e))
    rows, c = judge(added, guards, results, infra_results)
    md = ["# Failing-first: %d new test(s) since %s, run on the base addon (hook: %s)" % (c["new"], a.base, mode), "",
          "| test | file | on base | note |", "|---|---|---|---|"]
    for n, f, r, note in rows:
        md.append("| %s | %s | %s | %s |" % (n.replace("|", "/"), f, r, (note or "").replace("|", "/")))
    open(os.path.join(out, "failing-first.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
    for n, f, r, note in rows:
        if r in ("PASS ON BASE", "NOT RUN", "INFRA GUARD PASSES ON BASE TOOLS"):
            print("%s: %s  (%s)" % (r.lower() if r.startswith("INFRA") else r, n, f))
    bad = c["passed_on_base"] + c["notrun"] + c["infra_bad"]
    res = "fail" if bad else "pass"
    print("GAUNTLET failing-first result=%s new=%d failed_on_base=%d guards=%d passed_on_base=%d pending=%d%s" % (
        res, c["new"], c["failed_on_base"], c["guards"], c["passed_on_base"], c["pending"], ((" notrun=%d" % c["notrun"]) if c["notrun"] else "") + ((" infra_proved=%d infra_bad=%d" % (c["infra_proved"], c["infra_bad"])) if a.base_tools else "")))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
