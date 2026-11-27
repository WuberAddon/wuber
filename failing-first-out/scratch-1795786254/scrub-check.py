#!/usr/bin/env python3
"""scrub-check.py: fail if any personal-data pattern is found in a folder.

    python scrub-check.py <folder> [--patterns FILE] [--skip-dir NAME ...] [--max-show N] [--all]

Exit 0: clean. Exit 1: at least one hit. Exit 2: bad usage (missing folder or pattern file).
Patterns file (default: scrub-patterns.private.txt beside this script, else scrub-patterns.public.txt):
    NAME<TAB>REGEX     a pattern (case-insensitive)
    ALLOW<TAB>REGEX    a line that matches this is exempt ("public on purpose")
    # comment
The output names the pattern and file:line:column only. It NEVER prints the matched text or the line, so a
report cannot leak a name or a key. File and folder NAMES are scanned too (a path hit shows as file:0).
On a git working folder only the files git tracks (git ls-files) are scanned, so untracked output such as
tests/out logs never counts; --all scans every file, tracked or not. A folder git cannot list is scanned whole.
Binary files (NUL in the first 8 KB) are skipped but counted; images are not read (screenshots need an eye,
not a regex). Read-only: it writes nothing.
"""
import os
import re
import subprocess
import sys

DEFAULT_SKIP = {".git"}


def load_patterns(path):
    pats, allow = [], []
    with open(path, encoding="utf-8") as f:
        for n, raw in enumerate(f, 1):
            line = raw.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if "\t" not in line:
                raise ValueError("%s:%d: need NAME<TAB>REGEX" % (path, n))
            name, rx = line.split("\t", 1)
            try:
                c = re.compile(rx, re.I)
            except re.error as e:
                raise ValueError("%s:%d: bad regex: %s" % (path, n, e))
            (allow if name == "ALLOW" else pats).append(c if name == "ALLOW" else (name, c))
    return pats, allow


def scan_text(label, text, pats, allow):
    """[(label, line_no, column, pattern_name)] for every non-exempt match."""
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        exempt = [m.span() for a in allow for m in a.finditer(line)]
        for name, rx in pats:
            for m in rx.finditer(line):
                s, e = m.span()
                if any(xs <= s and e <= xe for xs, xe in exempt):
                    continue
                hits.append((label, i, s + 1, name))
    return hits


def tracked_files(root):
    """Set of git-tracked paths (relative, forward slashes) when root is the top of a git working tree, else None."""
    if not os.path.exists(os.path.join(root, ".git")):
        return None
    try:
        r = subprocess.run(["git", "-C", root, "ls-files", "-z"], capture_output=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    if r.returncode != 0:
        return None
    return set(x for x in r.stdout.decode("utf-8", "replace").split("\0") if x)


def scan_tree(root, pats, allow, skip_dirs=DEFAULT_SKIP, only=None):
    hits, scanned, binary = [], 0, 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        if only is not None:
            filenames = [f for f in filenames
                         if os.path.relpath(os.path.join(dirpath, f), root).replace("\\", "/") in only]
            reldir = os.path.relpath(dirpath, root).replace("\\", "/")
            prefix = "" if reldir == "." else reldir + "/"
            dirnames[:] = [d for d in dirnames if any(t.startswith(prefix + d + "/") for t in only)]
        for d in dirnames + filenames:
            rel = os.path.relpath(os.path.join(dirpath, d), root).replace("\\", "/")
            hits += [(rel, 0, h[2], h[3]) for h in scan_text(rel, d, pats, allow)]
        for fn in filenames:
            p = os.path.join(dirpath, fn)
            rel = os.path.relpath(p, root).replace("\\", "/")
            try:
                with open(p, "rb") as f:
                    data = f.read()
            except OSError:
                continue
            if b"\x00" in data[:8192]:
                binary += 1
                continue
            scanned += 1
            hits += scan_text(rel, data.decode("utf-8", "replace"), pats, allow)
    return hits, scanned, binary


def main(argv):
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        sys.stderr.write(__doc__)
        return 2
    folder, pfile, skip, show, every = args[0], None, set(DEFAULT_SKIP), 40, False
    i = 1
    while i < len(args):
        if args[i] == "--patterns" and i + 1 < len(args):
            pfile = args[i + 1]; i += 2
        elif args[i] == "--skip-dir" and i + 1 < len(args):
            skip.add(args[i + 1]); i += 2
        elif args[i] == "--all":
            every = True; i += 1
        elif args[i] == "--max-show" and i + 1 < len(args):
            show = int(args[i + 1]); i += 2
        else:
            sys.stderr.write("unknown argument: %s\n" % args[i])
            return 2
    here = os.path.dirname(os.path.abspath(__file__))
    if pfile is None:
        for cand in ("scrub-patterns.private.txt", "scrub-patterns.public.txt"):
            if os.path.exists(os.path.join(here, cand)):
                pfile = os.path.join(here, cand)
                break
    if not os.path.isdir(folder):
        sys.stderr.write("not a folder: %s\n" % folder)
        return 2
    if not pfile or not os.path.isfile(pfile):
        sys.stderr.write("no pattern file found\n")
        return 2
    try:
        pats, allow = load_patterns(pfile)
    except ValueError as e:
        sys.stderr.write("%s\n" % e)
        return 2
    only = None if every else tracked_files(folder)
    hits, scanned, binary = scan_tree(folder, pats, allow, skip, only)
    by = {}
    for _, _, _, name in hits:
        by[name] = by.get(name, 0) + 1
    for label, line, col, name in hits[:show]:
        print("%s:%d:%d  %s" % (label, line, col, name))
    if len(hits) > show:
        print("... %d more hits not shown" % (len(hits) - show))
    print("scanned %d text files, skipped %d binary; %d hits" % (scanned, binary, len(hits)))
    for name in sorted(by):
        print("  %-24s %d" % (name, by[name]))
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
