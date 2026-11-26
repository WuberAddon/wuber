#!/usr/bin/env python3
"""tools/log-digest.py: a long test log in about 10 lines: the counts, the failing tests and their first error line.

Reads the logs of tests/run.lua (serial, one shard, or the join of tools/suite-par.sh), suite-par.sh itself,
tools/quick-check.sh, tools/check.lua, tools/layout-check.lua, scrub-check.py, tools/pr-ready.py and Python
unittest. Failures with the same first error line are grouped ("21 tests: <error> (e.g. <name>)").
Anything else: the first lines that look like errors.

Usage:
  python tools/log-digest.py tests/out/join.log          a file (several files: one digest each)
  some-command 2>&1 | python tools/log-digest.py         standard input (also: -)
  python tools/log-digest.py --max 20 tests/out/shard-3.log   at most 20 lines (default 10)
Exit code: 0 no failure found, 1 a failure (or a REJECTED/REFUSED/unfinished run), 2 could not read a file.
Prints only the log's own lines (shortened); no file is written.
"""
import argparse
import re
import sys

WIDTH = 160

R_FAIL = re.compile(r"^FAIL\s+(.+?)(?:\s+\(shard \d+\))?\s*$")
R_COUNTS = re.compile(r"^(?:shard \d+/\d+: )?(\d+) passed, (\d+) failed(?:, (\d+) pending)?(?:, (\d+) skipped)?")
R_SHARD_EXIT = re.compile(r"^shard (\d+)/(\d+): exit (\d+) at (\d+) s")
R_PY_FAIL = re.compile(r"^(FAIL|ERROR): (\S+) \((.+?)\)")
R_PY_RAN = re.compile(r"^Ran (\d+) tests? in")
R_PY_END = re.compile(r"^(OK|FAILED)\b(.*)")
R_ERRORISH = re.compile(r"(?i)(\berror\b|traceback|exception|\bfailed\b|\bFAIL\b|cannot|not found|refused|denied)")
KEEP_PREFIXES = ("REJECTED", "suite-par:", "quick-check:", "check:", "GAUNTLET layout", "layout-check:",
                 "pr-ready:", "tests: none", "FULL SUITE NEEDED")


def cut(s, n=WIDTH):
    s = s.strip()
    return s if len(s) <= n else s[: n - 3] + "..."


def first_error(lines, i):
    """The first real line of the error printed under a FAIL line (indented), or ''."""
    for l in lines[i + 1: i + 12]:
        if not l.startswith((" ", "\t")):
            break
        t = l.strip()
        if t and t != "stack traceback:" and not t.startswith(("[C]:", "tests/run.lua:1")):
            return t
    return ""


def py_error(lines, i):
    """Python unittest: after FAIL:/ERROR: the last line of the traceback block (AssertionError: ...)."""
    last = ""
    for l in lines[i + 1: i + 60]:
        if l.startswith(("=====", "-----")) and last:
            break
        if l.strip() and not l.startswith(("=====", "-----", "Traceback", "  ")):
            last = l.strip()
    return last


def digest(lines, max_lines=10):
    lines = [l.rstrip("\r\n") for l in lines]
    fails = {}          # name -> first error line (in order)
    counts = None
    keep = []           # suite-par / quick-check / check.lua ... result lines (last of each kind)
    bad_shards = []
    py_ran, py_end = None, None
    failed_list = None
    saw_tests = False
    for i, l in enumerate(lines):
        if l.startswith(("PASS  ", "FAIL  ", "PEND  ")):
            saw_tests = True
        m = R_FAIL.match(l)
        if m:
            name = m.group(1).strip()
            if name not in fails or not fails[name]:
                fails[name] = first_error(lines, i)
            continue
        m = R_PY_FAIL.match(l)
        if m:
            fails["%s (%s)" % (m.group(2), m.group(3))] = py_error(lines, i)
            continue
        m = R_COUNTS.match(l.strip())
        if m:
            counts = m
            continue
        m = R_SHARD_EXIT.match(l)
        if m and m.group(3) not in ("0", "1"):
            bad_shards.append("shard %s/%s exit %s" % (m.group(1), m.group(2), m.group(3)))
            continue
        if l.startswith("failed: "):
            failed_list = l[len("failed: "):].split("; ")
            continue
        m = R_PY_RAN.match(l)
        if m:
            py_ran = m.group(1)
            continue
        m = R_PY_END.match(l.strip())
        if m and py_ran:
            py_end = (m.group(1) + m.group(2)).strip()
            continue
        if l.strip().startswith(KEEP_PREFIXES) or re.search(r"; \d+ hits$", l):
            key = l.strip().split(" ")[0]
            keep = [k for k in keep if k.split(" ")[0] != key] + [l.strip()]
    if not fails and failed_list:
        fails = dict((n, "") for n in failed_list)

    out = []
    if counts:
        c = "%s passed, %s failed" % (counts.group(1), counts.group(2))
        if counts.group(3):
            c += ", %s pending" % counts.group(3)
        if counts.group(4):
            c += ", %s skipped" % counts.group(4)
        out.append("counts: " + c)
    if py_ran:
        out.append("python: ran %s tests, %s" % (py_ran, py_end or "no result line"))
    for k in keep:
        out.append(cut(k))
    if saw_tests and not counts:
        out.append("no final counts line: the run did not finish (or this is part of a log)")
    if bad_shards:
        out.append("unfinished: " + ", ".join(bad_shards[:6]) + (" ..." if len(bad_shards) > 6 else ""))
    if fails:
        groups = {}
        for name, err in fails.items():
            groups.setdefault(err, []).append(name)
        order = sorted(groups.items(), key=lambda kv: -len(kv[1]))
        out.append("failing: %d test%s%s" % (len(fails), "" if len(fails) == 1 else "s",
                                             (" in %d groups by first error" % len(groups)) if len(groups) < len(fails) else ""))
        room = max(2, max_lines - len(out) - 2)
        for err, names in order[:room]:
            if len(names) == 1:
                out.append(cut("- %s%s" % (names[0], (": " + err) if err else "")))
            else:
                out.append(cut("- %d tests: %s (e.g. %s)" % (len(names), err or "no error line", names[0])))
        if len(order) > room:
            rest = sum(len(n) for _, n in order[room:])
            out.append(cut("- and %d more: %s" % (rest, "; ".join(n for _, ns in order[room:] for n in ns))))
    elif not out:
        errs = [l.strip() for l in lines if R_ERRORISH.search(l)]
        if errs:
            out.append("no test summary found; first error lines:")
            out.extend(cut(e) for e in errs[: max_lines - 1])
        else:
            tail = [l for l in lines if l.strip()][-3:]
            out.append("no test summary and no error lines found; last lines:")
            out.extend(cut(t) for t in tail)
    failed = bool(fails) or bool(bad_shards) or (saw_tests and not counts) or (counts is not None and counts.group(2) != "0") or \
        (py_end is not None and py_end.startswith("FAILED")) or \
        any(k.startswith(("REJECTED", "quick-check: FAIL", "pr-ready: FAIL")) or "REFUSED" in k or
            re.search(r"exit [1-9]", k) or re.search(r"; [1-9]\d* hits$", k) or
            re.search(r"\b[1-9]\d* (failures|problems)\b", k) or "result=fail" in k or "result=error" in k for k in keep)
    return out[:max_lines], failed


def main(argv=None):
    p = argparse.ArgumentParser(prog="log-digest.py", description=__doc__.split("\n\n")[0],
                                formatter_class=argparse.RawDescriptionHelpFormatter,
                                epilog="\n".join(__doc__.split("\n")[2:]))
    p.add_argument("files", nargs="*", help="log files (none or -: standard input)")
    p.add_argument("--max", type=int, default=10, help="at most this many lines per log (default 10)")
    a = p.parse_args(argv)
    any_failed, code = False, 0
    for path in a.files or ["-"]:
        try:
            if path == "-":
                text = sys.stdin.read()
            else:
                with open(path, encoding="utf-8", errors="replace") as f:
                    text = f.read()
        except OSError as e:
            print("log-digest: cannot read %s: %s" % (path, e.strerror))
            code = 2
            continue
        lines, failed = digest(text.splitlines(), a.max)
        if len(a.files) > 1:
            print("== " + path)
        for l in lines:
            print(l)
        any_failed = any_failed or failed
    return code or (1 if any_failed else 0)


if __name__ == "__main__":
    sys.exit(main())
