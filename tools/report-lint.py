#!/usr/bin/env python
"""REPORT lint (L25 C16, lesson L3): a cause must be proven or marked unproven.

  python tools/report-lint.py <REPORT.md> [--items ITEMS.md] [--strict]

For every bullet or paragraph that states a cause ("because", "caused by", "the cause is", "root cause"):
  - it must carry a file:line (Foo.lua:123) or a quoted log line (in backticks or double quotes), or
  - its paragraph (the blank-line block) must say "not proven" AND have a line starting "To prove it:".
Also flagged: "not proven" in a paragraph with no line starting "To prove it:".
--items ITEMS.md: every item id (E1-04 style, at the start of a line or heading in ITEMS.md) must appear in the report.
Prints "REPORT-LINT: <line no>: <reason>" per flag and a last line "report lint: N flags".
Exit 0 always, 1 with --strict when there are flags.
"""
import argparse, re, sys

CAUSE = re.compile(r"\b(because|caused by|the cause is|root cause)\b", re.I)
FILELINE = re.compile(r"[\w./\\-]+\.(?:lua|py|md|toc|xml|txt|ps1|sh|json):\d+")
QUOTED = re.compile(r"`[^`\n]{3,}`|\"[^\"\n]{4,}\"|\u201c[^\u201d\n]{4,}\u201d")
NOTPROVEN = re.compile(r"\bnot proven\b", re.I)
TOPROVE = re.compile(r"^\s*(?:[-*+]\s+|\d+[.)]\s+)?(?:\*\*)?To prove it:", re.I)
BULLET = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
ITEM_ID = re.compile(r"^[\s#>*+\-|]*\**([A-Z][A-Z0-9]*-\d+)\b")


def blocks(lines):
    """-> list of blocks, each a list of (line_no, text); blank lines and headings separate blocks."""
    out, cur = [], []
    for n, t in enumerate(lines, 1):
        if not t.strip() or t.lstrip().startswith("#"):
            if cur:
                out.append(cur)
            cur = []
            if t.lstrip().startswith("#"):
                cur = [(n, t)]
            continue
        cur.append((n, t))
    if cur:
        out.append(cur)
    return out


def units(block):
    """split a block into bullets (a bullet and its continuation lines) or one paragraph."""
    us = []
    for n, t in block:
        if BULLET.match(t) or not us:
            us.append([(n, t)])
        else:
            us[-1].append((n, t))
    return us


def lint(text, items_text=None):
    lines = text.split("\n")
    flags, fence = [], False
    clean = []
    for t in lines:
        if t.lstrip().startswith("```"):
            fence = not fence
            clean.append("")
        else:
            clean.append("" if fence else t)
    for blk in blocks(clean):
        btext = "\n".join(t for _n, t in blk)
        proven_ok = bool(NOTPROVEN.search(btext)) and any(TOPROVE.match(t) for _n, t in blk)
        for n, t in blk:
            if NOTPROVEN.search(t) and not any(TOPROVE.match(x) for _m, x in blk):
                flags.append((n, 'says "not proven" with no line starting "To prove it:"'))
        for u in units(blk):
            utext = "\n".join(t for _n, t in u)
            m = CAUSE.search(utext)
            if not m or proven_ok:
                continue
            if FILELINE.search(utext) or QUOTED.search(utext):
                continue
            ln = next(n for n, t in u if CAUSE.search(t))
            flags.append((ln, 'states a cause ("%s") with no file:line and no quoted log line, and no "not proven" plus "To prove it:"' % m.group(1)))
    if items_text is not None:
        ids = []
        for t in items_text.split("\n"):
            m = ITEM_ID.match(t)
            if m and m.group(1) not in ids:
                ids.append(m.group(1))
        for i in ids:
            if not re.search(r"\b%s\b" % re.escape(i), text):
                flags.append((0, "item %s of ITEMS.md is not in the report" % i))
    return sorted(flags)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("report")
    ap.add_argument("--items")
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args(argv)
    text = open(a.report, encoding="utf-8", errors="replace").read()
    items = open(a.items, encoding="utf-8", errors="replace").read() if a.items else None
    fl = lint(text, items)
    for n, why in fl:
        print("REPORT-LINT: %d: %s" % (n, why))
    print("report lint: %d flags" % len(fl))
    return 1 if (fl and a.strict) else 0


if __name__ == "__main__":
    sys.exit(main())
