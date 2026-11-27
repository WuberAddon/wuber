#!/usr/bin/env python3
"""strip-process-wording.py: remove wording that shows the private way of working from a Wuber checkout.

What it changes (comments, docs, tags and fixture labels only; never a player-facing word,
a behaviour or a test assertion):
  tag     process tags in comments, like "(BRIEF19 R6)", "(SPEC7 2.8)", "(job 2749)", "(BRIEF15, PLAN 2.3.2 feature 2)"
  google  "Google" named as a tester or reviewer in comments ("Google's shots" -> "a reviewer's shots")
  writer  AI model names used as writer labels in tests/fixtures/gauntlet/chat-lines.lua (writer-1 .. writer-4)
  doc     the agy / Google lane wording and the google/<n> branch prefix in the contributor docs

Only comments are touched in code files (Lua: after "--", Python/shell: whole-line "#" comments).
Markdown prose is touched only in the files listed in MD_FILES. Running it twice changes nothing more.

Usage:
  python tools/strip-process-wording.py [--root DIR] --dry-run    list every change, write nothing
  python tools/strip-process-wording.py [--root DIR] --apply      make the changes
  python tools/strip-process-wording.py [--root DIR] --count      count the wording that is still there, by kind
"""
import argparse
import os
import re
import subprocess
import sys

CODE_EXT = {".lua": "lua", ".py": "hash", ".sh": "hash"}
MD_FILES = (
    "lab/README.md", "tests/README.md", "docs/DESIGN-GROUP-FINDER.md",
    "tools/README.md", "tools/architecture-intro.md",
)
WRITER_FILE = "tests/fixtures/gauntlet/chat-lines.lua"
WRITERS = {"writer-flash": "writer-1", "writer-hydrogen": "writer-2", "writer-neon": "writer-3", "writer-sonnet": "writer-4"}
SKIP_PARTS = ("_to_delete", "tests/out/", "release/")
SELF = ("tools/strip-process-wording.py", "tools/test_strip_process_wording.py")

# ---- tag groups -------------------------------------------------------------------------
TAG_WORD = r"(?:BRIEF\d+|SPEC\d*(?!\.md))" # job-number tags stay as comments
# a group that holds only tags and their section numbers; a group with real words in it is kept (see INNER, TOPIC, BARE)
TAG_REST = r"(?:[ ,;/]+(?:[A-Z]\d{1,2}[a-z]?|[A-Z]|[a-d]|\d[\d.]*(?:-[A-Z]?\d+)?|#\d+|(?:PLAN|feature|review|sections?|and|step|owner|shots?|tour|item|lead|FIXROUND-[\d.]+|LATER)|\"[a-z ]+\"|\d\d[:]\d\d|\d+ \w{3,5}|[A-Z]+\d+))*"
GROUP = re.compile(r"\s*\(" + TAG_WORD + TAG_REST + r"\)")
# a tag inside another parenthesis: "(W.Drive, Drive_*.lua; SPEC3 3.1)", "(round 11, BRIEF11)"
INNER = re.compile(r"[;,]\s*(?:BRIEF\d+|SPEC\d*(?!\.md))(?:\s+(?:sections?\s+)?\d[\d.,]*(?:\s+and\s+\d[\d.]*)?|\s+[A-Z]\d+)?(?=[);:,])")
# "(SPEC5 roles, review #17: a reloading" -> "(a reloading"; "BRIEF18: one dropped" -> "one dropped"
TOPIC = re.compile(r"\bSPEC\d+ [a-z]+(?:, review #\d+)?(?:[:,]\s*|(?=\)))")
NUMREF = re.compile(r"(?:\((?=SPEC\d+ [\d.]+;)|[:,]\s*(?=SPEC\d+ [\d.]+(?:\s+step \d)?(?:\s*\"[a-z]+\")?[);,])|\s(?=SPEC\d+ [\d.]+(?:\s+step \d)?\s*$))SPEC\d+ [\d.]+(?:\s+step \d)?(?:\s*\"[a-z]+\")?(?:(?<=\()\s*|(?=[);,])|\s*$)")
BARE = re.compile(r"\bBRIEF\d+(?:\s+[A-Z]\d+)?(?:,? \d+ \w+ \d\d[:]\d\d|\s+\d\d[:]\d\d)?:\s*")

# ---- Google as a tester ------------------------------------------------------------------
GOOGLE = [
    (re.compile(r"Google's"), "a reviewer's"),
    (re.compile(r"Google review"), "an outside review"),
    (re.compile(r"Google audit"), "an outside audit"),
    (re.compile(r"Google lead"), "review lead"),
    (re.compile(r"Google finding"), "review finding"),
    (re.compile(r"Google (saw|caught|asked)"), r"a reviewer \1"),
    (re.compile(r"\(Google, "), "(a review, "),
    (re.compile(r"\bGoogle\b"), "a reviewer"),
]

# ---- docs: exact rewrites (path, old, new) -------------------------------------------------
BR = "<n>"
DOC = [
    ("AGENTS.md", "Branch names: `claude/<n>`, `google/<n>`, `author/<topic>`", "Branch names: `claude/<n>`, `author/<topic>`"),
    ("AGENTS.md", "- Claude and Google's agy may both work in this repository, completely separately. GitHub (issues and pull requests) is the only shared place. The `google` label on an issue is added only by the maintainer. Nobody starts, drives or reads another tool.\n",
     "- Several contributors and tools may work in this repository at the same time, each on their own branch. GitHub (issues and pull requests) is the only shared place; nobody starts, drives or reads another contributor's tool.\n"),
    ("AGENTS.md", "--prefix <claude/ or google/>", "--prefix claude/"),
    ("AGENTS.md", "\n## If you are Google's agent\nEverything above applies. Only what differs:\n- Branch `google/<n>`. Work in your own clone, never in anyone else's checkout or worktree.\n- When asked to review a pull request: change no file, push nothing, and post the review with `gh pr review <n> --comment --body \"...\"`.\n- Never push main, tags or releases. The `google` label is added only by the maintainer.\n",
     "\n## If you are asked to review a pull request\nChange no file, push nothing, and post the review with `gh pr review <n> --comment --body \"...\"`. Never push main, tags or releases.\n"),
    ("AGENTS.md", "- Choosing the work, and labelling an issue `google`.\n", "- Choosing the work.\n"),
    ("CODE-RULES.md", "(`claude/<n>`, `google/<n>`, `author/<topic>`)", "(`claude/<n>`, `author/<topic>`)"),
    ("CONTRIBUTING.md", "Branch names: `claude/<n>`, `google/<n>`, `author/<topic>`", "Branch names: `claude/<n>`, `author/<topic>`"),
    ("CONTRIBUTING.md", "- The `google` label is only added by the maintainer.\n", ""),
    (".agents/skills/wow-addon-workflow/SKILL.md", "(`claude/<n>`, `google/<n>`, `author/<topic>`)", "(`claude/<n>`, `author/<topic>`)"),
    ("ROLES.md", "Claude and Google's agy may both work in this repository, completely separately; GitHub is the only shared place.", "Several contributors and tools may work in this repository at the same time, each on their own branch; GitHub is the only shared place."),
    ("ROLES.md", "- Issues labelled `google` are started by the maintainer, by hand. Only the maintainer adds that label.\n", ""),
    ("ROLES.md", "(`claude/<n>`, `google/<n>`, `author/<topic>`)", "(`claude/<n>`, `author/<topic>`)"),
    ("tools/README.md", "--prefix claude/|google/", "--prefix claude/"),
]
DOC = [(p, o.replace("<n>", BR), n.replace("<n>", BR)) for p, o, n in DOC]


def lua_comment_start(line):
    """Index of the "--" that starts a comment, or -1 (quotes are skipped)."""
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 1
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "-" and line.startswith("--", i):
            return i
        i += 1
    return -1


def strip_tags(text):
    """Remove process tags from comment or prose text; returns the new text."""
    lead = re.match(r"^(\s*)", text).group(1)
    body = text[len(lead):]
    starts = GROUP.match(" " + body) if body.startswith("(") else None
    if starts:
        body = body[len(starts.group(0)) - 1:].lstrip()
    body = GROUP.sub("", body)
    body = INNER.sub("", body)
    body = TOPIC.sub("", body)
    body = BARE.sub("", body)
    body = NUMREF.sub(lambda m: "(" if m.group(0).startswith("(") else "", body)
    return lead + body


TIDY = (  # what a removed tag can leave behind: "()", "(;", "( word"
    (re.compile(r"\s+\(\s*\)"), ""),
    (re.compile(r"\(\s*;\s+"), "("),
    (re.compile(r"(?<=\s)\(\s+(?!or \))(?=\S)"), "("),
)


def tidy(text):
    for rx, rep in TIDY:
        text = rx.sub(rep, text)
    return text


def strip_google(text):
    for rx, rep in GOOGLE:
        text = rx.sub(rep, text)
    return text


def edit_line(line, kind):
    """kind: lua, hash or md. Returns (newline, set of rule names)."""
    nl = "\n" if line.endswith("\n") else ""
    raw = line[:-1] if nl else line
    if raw.endswith("\r"):
        raw, nl = raw[:-1], "\r" + nl
    if kind == "lua":
        k = lua_comment_start(raw)
        if k < 0:
            return line, set()
        head, com = raw[:k], raw[k:]
        m = re.match(r"^-+\s?", com)
        mark, text = com[:m.end()], com[m.end():]
    elif kind == "hash":
        m = re.match(r"^(\s*#+\s?)(.*)$", raw)
        if not m:
            return line, set()
        head, mark, text = "", m.group(1), m.group(2)
    else:
        head, mark, text = "", "", raw
    out = text
    rules = set()
    for name, fn in (("tag", strip_tags), ("google", strip_google), ("tidy", tidy)):
        if kind == "md" and name != "tag":
            continue
        new = fn(out)
        if new != out:
            rules.add(name)
            out = new
    if not rules:
        return line, set()
    if not out.strip() and head.strip():
        return head.rstrip() + nl, rules  # a trailing comment that was only a tag goes away
    return head + mark + out + nl, rules


def tracked_files(root):
    r = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True, check=True)
    return [f for f in r.stdout.splitlines() if not any(s in f for s in SKIP_PARTS) and f not in SELF]


def plan(root):
    """Every change as (kind, path, lineno, old, new); the files' new text is built by apply()."""
    changes = []
    files = tracked_files(root)
    for rel in files:
        ext = os.path.splitext(rel)[1]
        kind = CODE_EXT.get(ext) or ("md" if rel in MD_FILES else None)
        path = os.path.join(root, rel)
        if rel == WRITER_FILE:
            with open(path, encoding="utf-8", newline="") as f:
                for n, line in enumerate(f, 1):
                    new = line
                    for a, b in WRITERS.items():
                        new = new.replace('writer = "' + a + '"', 'writer = "' + b + '"')
                    if new != line:
                        changes.append(("writer", rel, n, line.rstrip("\r\n"), new.rstrip("\r\n")))
            continue
        if not kind:
            continue
        try:
            with open(path, encoding="utf-8", newline="") as f:
                lines = f.readlines()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(lines, 1):
            new, rules = edit_line(line, kind)
            if new != line:
                changes.append((",".join(sorted(rules)), rel, n, line.rstrip("\r\n"), new.rstrip("\r\n")))
    for rel, old, new in DOC:
        path = os.path.join(root, rel)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        if old in text:
            changes.append(("doc", rel, 0, old.strip(), new.strip()))
    return changes


def apply(root, changes):
    by_file = {}
    for kind, rel, n, old, new in changes:
        by_file.setdefault(rel, []).append((kind, n, old, new))
    for rel, items in by_file.items():
        path = os.path.join(root, rel)
        with open(path, encoding="utf-8", newline="") as f:
            text = f.read()
        lines = text.splitlines(True)
        ext = os.path.splitext(rel)[1]
        kind = CODE_EXT.get(ext) or "md"
        for k, n, old, new in items:
            if k == "doc":
                continue
            line = lines[n - 1]
            if k == "writer":
                for a, b in WRITERS.items():
                    line = line.replace('writer = "' + a + '"', 'writer = "' + b + '"')
                lines[n - 1] = line
            else:
                lines[n - 1] = edit_line(line, kind)[0]
        text = "".join(lines)
        for drel, o, nw in DOC:
            if drel == rel and o in text:
                text = text.replace(o, nw)
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(text)


COUNT_RULES = (
    ("BRIEF/SPEC tag lines", re.compile(r"\b(?:BRIEF\d+|SPEC\d+)\b")),
    ("job-number lines", re.compile(r"\bjobs? \d{2,4}\b")),
    ("Google as a tester", re.compile(r"\bGoogle\b")),
    ("agy / google/<n> / google label", re.compile(r"\bagy\b|google/<n>|\x60google\x60|best-for: ")),
    ("model-name writer labels", re.compile(r"writer-(?:flash|hydrogen|neon|sonnet)")),
)


def count(root):
    res = {name: [0, 0] for name, _ in COUNT_RULES}
    for rel in tracked_files(root):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as f:
                lines = f.readlines()
        except (UnicodeDecodeError, OSError):
            continue
        for line in lines:
            for name, rx in COUNT_RULES:
                if rx.search(line):
                    res[name][0] += 1
                    if rel.startswith("Wuber/"):
                        res[name][1] += 1
    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description="Remove process wording (tags, tester names, lane wording) from comments and docs.",
                                 epilog="Run with --dry-run first; it writes nothing.")
    ap.add_argument("--root", default=".", help="the checkout to work on (default: current folder)")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true", help="list every change, write nothing")
    g.add_argument("--apply", action="store_true", help="make the changes")
    g.add_argument("--count", action="store_true", help="count the wording still present, by kind (lines; and inside Wuber/)")
    a = ap.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    root = os.path.abspath(a.root)
    if a.count:
        for name, (all_, addon) in count(root).items():
            print("%-34s %5d lines (%d inside Wuber/)" % (name, all_, addon))
        return 0
    changes = plan(root)
    for kind, rel, n, old, new in changes:
        print("%s %s:%d\n  - %s\n  + %s" % (kind, rel, n, old[:200], new[:200]))
    tally = {}
    for c in changes:
        tally[c[0]] = tally.get(c[0], 0) + 1
    print("%d change(s): %s" % (len(changes), ", ".join("%s %d" % kv for kv in sorted(tally.items())) or "none"))
    if a.apply:
        apply(root, changes)
        print("applied")
    return 0


if __name__ == "__main__":
    sys.exit(main())