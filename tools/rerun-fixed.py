#!/usr/bin/env python
"""Re-run the proof test of every fixed bug (L25 Q5b, METHOD-LEDGER T-21).

  python tools/rerun-fixed.py --bugs <BUGS-NEXT.md> --repo <path> [--lua <exe>] [--dry] [--timeout <secs>]

A bug line is "ID | severity | file:line | what | proof | minutes | status". Lines whose status starts with "fixed" are
re-run. The test is the "test tests/..." in the status, else the proof field when it is a tests/ path inside the repo.
A tests/ file x/y_test.lua runs as: lua tests/run.lua --files=x/y_test (the repo's way to run one test part); a tests/
folder runs every .lua part in it. A hunt repro (a .lua under a repro/ folder, in the repo or outside it, an absolute path
is fine; tests/hunt/README.md) is a one-file proof that tests/run.lua never runs: it runs as
lua <repro> --addon <repo>/Wuber with cwd = the repo (the file hard-codes the tree it was found in), exit 0 = PASS,
exit 1 = STILL FAILS, any other exit (2: it cannot tell) = not re-runnable. Any other proof outside the repo (audit
folders, pictures) or a missing file is "not re-runnable".
--dry prints what would run (as "would run") and runs nothing.
Output: one line per fixed bug "<id>: PASS | STILL FAILS | not re-runnable", last line
"fixed repros: N re-run, F still fail, U not re-runnable". Exit 0, or 1 when any still fails.
"""
import argparse, os, re, subprocess, sys

LUA = os.environ.get("WUBER_LUA") or os.environ.get("LUA") or "lua5.1"
TEST_IN_STATUS = re.compile(r"\btests?[ :]+(tests/[\w./-]+)")
TESTS_PATH = re.compile(r"^(?:\./)?(tests/[\w./-]+)$")


def parse_bugs(text):
    """-> list of (id, proof_field, status)"""
    out = []
    for line in text.split("\n"):
        p = [x.strip() for x in line.split(" | ")]
        if len(p) >= 7 and re.match(r"^[A-Z][A-Za-z0-9]*-[\w-]+$", p[0]) and p[-1].lower().startswith("fixed"):
            out.append((p[0], p[4], p[-1]))
    return out


def find_test(proof, status):
    m = TEST_IN_STATUS.search(status)
    if m:
        return m.group(1).rstrip(".")
    m = TESTS_PATH.match(proof.strip().replace("\\", "/"))
    return m.group(1) if m else None


def find_repro(proof, status, repo):
    """the hunt repro named by the status test or the proof field -> absolute path of an existing file, or None"""
    cands = []
    m = TEST_IN_STATUS.search(status)
    if m:
        cands.append(m.group(1).rstrip("."))
    cands.append(proof.strip())
    for c in cands:
        c = c.replace("\\", "/")
        if not c.endswith(".lua") or not re.search(r"(^|/)repro[\w-]*/[^/]+$", c):
            continue
        full = c if os.path.isabs(c) or re.match(r"^[A-Za-z]:/", c) else os.path.join(repo, *c.lstrip("./").split("/"))
        if os.path.isfile(full):
            return os.path.abspath(full)
    return None


def parts_for(repo, rel):
    """tests/ path -> list of --files parts, or None when it is not in the repo"""
    full = os.path.join(repo, *rel.split("/"))
    if os.path.isfile(full) and rel.endswith(".lua"):
        return [rel[len("tests/"):-4]]
    if os.path.isdir(full):
        ps = []
        for dp, dn, fn in os.walk(full):
            dn.sort()
            for f in sorted(fn):
                if f.endswith(".lua"):
                    ps.append(os.path.relpath(os.path.join(dp, f), os.path.join(repo, "tests")).replace("\\", "/")[:-4])
        return ps or None
    return None


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--bugs", required=True)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--lua", default=LUA)
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--timeout", type=int, default=600)
    a = ap.parse_args(argv)
    repo = os.path.abspath(a.repo)
    bugs = parse_bugs(open(a.bugs, encoding="utf-8", errors="replace").read())
    ran = failed = unrun = 0
    cache = {}
    for bid, proof, status in bugs:
        repro = find_repro(proof, status, repo)
        if repro:
            cmd = [a.lua, repro, "--addon", os.path.join(repo, "Wuber")]
            if a.dry:
                ran += 1
                print("%s: would run %s" % (bid, " ".join(cmd)))
                continue
            if repro not in cache:
                try:
                    cache[repro] = subprocess.run(cmd, cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                                  timeout=a.timeout).returncode
                except subprocess.TimeoutExpired:
                    cache[repro] = 1
            if cache[repro] not in (0, 1):
                unrun += 1
                print("%s: not re-runnable (%s: cannot tell, exit %d)" % (bid, repro, cache[repro]))
                continue
            ran += 1
            if cache[repro] == 0:
                print("%s: PASS" % bid)
            else:
                failed += 1
                print("%s: STILL FAILS (%s)" % (bid, repro))
            continue
        rel = find_test(proof, status)
        parts = parts_for(repo, rel) if rel else None
        if not parts:
            unrun += 1
            print("%s: not re-runnable (%s)" % (bid, rel or "proof outside the repo: " + proof[:60]))
            continue
        key = ",".join(parts)
        if a.dry:
            ran += 1
            print("%s: would run %s tests/run.lua --files=%s" % (bid, a.lua, key))
            continue
        if key not in cache:
            try:
                p = subprocess.run([a.lua, "tests/run.lua", "--files=" + key], cwd=repo, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, timeout=a.timeout)
                cache[key] = p.returncode == 0
            except subprocess.TimeoutExpired:
                cache[key] = False
        ran += 1
        if cache[key]:
            print("%s: PASS" % bid)
        else:
            failed += 1
            print("%s: STILL FAILS (%s)" % (bid, rel))
    print("fixed repros: %d re-run, %d still fail, %d not re-runnable" % (ran, failed, unrun))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
