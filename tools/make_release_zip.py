"""The CurseForge zip: only the committed addon folder Wuber\\ (as Interface\\AddOns expects), from a git ref.

    python tools/make_release_zip.py --version 2.3.2 [git ref, default HEAD] <out.zip>
        THE release build (BRIEF21 S1): from master, which says "2.3.2-dev", stamps 2.3.2 into the ZIP's copy
        only (## Version in Wuber/Wuber.toc, W.VERSION in Wuber/Core/Base.lua: see STAMPS). The checkout, the
        index and the branch are untouched (the stamped files go in as git objects through a temporary index).
        Refuses a number the ref doesn't say (master "2.3.3-dev" can't become 2.3.2). Every other entry is the
        bytes git archive makes from that commit, with its date, and the zip comment is its commit id.
    python tools/make_release_zip.py <git ref> <out.zip> [expected version]
        the old form: the ref as committed, no stamping.
    With --version, release/CHANGELOG-<version>.md must exist (this checkout or the main one) unless --changelog
    names one. Runs from anywhere in the repo: every git call runs at its root.

Builds the zip with `git archive` (so only committed files, never a stray local file), then checks it:
every entry is under Wuber/, nothing from lab, tests, tools or docs, Wuber/Wuber.toc says the expected
## Version (and Core/Base.lua's W.VERSION says the same) and keeps ## X-Curse-Project-ID, and every
file the TOC lists is in the zip.

It REFUSES to build (exit 1, file:line:word on stderr) if any shipped file, the changelog
(release/CHANGELOG-<version>.md, else the newest CHANGELOG-*.md; release/ is untracked, so it is looked for
in this checkout and then in the main checkout when run from a worktree) or the CurseForge page text
(wuber-curseforge-flat.html / -now.html in the folder $WUBER_CF_DIR names) holds a personal
word (the list in the file $WUBER_PERSONAL_WORDS names; none when unset), an email address or a local path. Game character names in W.CREATOR are fine.

    python tools/make_release_zip.py --check-only [git ref] [--changelog F] [--curseforge DIR]
        scans without building (default ref HEAD); same exit codes.
"""
import glob
import io
import os
import re
import struct
import subprocess
import sys
import tempfile
import zipfile

# Personal words are NOT kept in this file: they come from the optional file named by the environment variable
# WUBER_PERSONAL_WORDS (one word per line; blank lines and # lines are ignored). Without that file only the
# generic checks run (e-mail addresses, drive-letter paths, Users folders). Whole words, case-insensitive.
def load_personal_words(path=None):
    path = path or os.environ.get("WUBER_PERSONAL_WORDS")
    if not path or not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as f:
        return [w.strip() for w in f if w.strip() and not w.lstrip().startswith("#")]


def word_re(words):
    if not words:
        return None
    return re.compile(r"(?<![A-Za-z0-9_])(%s)(?![A-Za-z0-9_])" % "|".join(re.escape(w) for w in words), re.I)


PERSONAL_WORDS = load_personal_words()
_WORD_RE = word_re(PERSONAL_WORDS)
_EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+")
# Drive-letter paths and Users folders (either slash, also doubled backslashes), and the git-bash drive forms.
_PATH_RE = re.compile(r"(?<![A-Za-z0-9])(?:[Ff]:[\\/]|[Cc]:[\\/]+Users)|(?<![A-Za-z0-9_./-])/(?:[fF]/|[cC]/Users)", re.I)
_TEXT_EXT = re.compile(r"\.(lua|toc|xml|txt|md|html?|json|cfg)$", re.I)
CF_FILES = ["wuber-curseforge-flat.html", "wuber-curseforge-now.html"]

# What a release build changes in the zip's copy (all that differed between master and release-2.3.2):
# (path in the repo, pattern whose group 2 is the version). Each must match exactly once.
STAMPS = [
    ("Wuber/Wuber.toc", re.compile(r"^(## Version: *)(\S+)", re.M)),
    ("Wuber/Core/Base.lua", re.compile(r'^(W\.VERSION = ")([^"\r\n]*)(")', re.M)),
]
_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+$")


def fail(msg):
    sys.stderr.write(msg + "\n")
    raise SystemExit(1)


ROOT = None  # the repo root every git call runs in (main() sets it), so a subdirectory works too


def repo_root():
    r = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if r.returncode != 0 or not r.stdout.strip():
        fail("not in a git checkout: %s" % r.stderr.strip())
    return r.stdout.strip()


def git(*args, env=None, data=None):
    r = subprocess.run(["git", *args], capture_output=True, env=env, input=data, cwd=ROOT)
    if r.returncode != 0:
        fail("git %s: %s" % (" ".join(args), r.stderr.decode("utf-8", "replace").strip()))
    return r.stdout


def stamp_text(path, text, version):
    """The text with the version stamped in (path must be in STAMPS; exactly one match)."""
    rx = dict(STAMPS)[path]
    found = rx.findall(text)
    if len(found) != 1:
        fail("%s: %d version lines (want exactly 1) for %s" % (path, len(found), rx.pattern))
    return rx.sub(lambda m: m.group(1) + version + (m.group(3) if m.lastindex >= 3 else ""), text)


def source_version(path, text):
    return dict(STAMPS)[path].search(text).group(2) if dict(STAMPS)[path].search(text) else None


def stamped_archive(ref, version):
    """git archive bytes of ref's Wuber/ with the version stamped into STAMPS' files."""
    commit = git("rev-parse", "--verify", ref + "^{commit}").decode().strip()
    ctime = git("log", "-1", "--format=%ct", commit).decode().strip()
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ, GIT_INDEX_FILE=os.path.join(d, "index"))
        git("read-tree", commit, env=env)
        for path, _ in STAMPS:
            ls = git("ls-tree", "--full-tree", commit, "--", path).decode().split()
            if len(ls) < 4:
                fail("%s: not in %s" % (path, ref))
            mode, blob = ls[0], ls[2]
            text = git("cat-file", "blob", blob).decode("utf-8")
            was = source_version(path, text)
            if was is not None and was != version and was.split("-")[0] != version:
                fail("%s says %s: a %s build can only be stamped %s (use the old form for anything else)"
                     % (path, was, was, was.split("-")[0]))
            new = git("hash-object", "-w", "--stdin", data=stamp_text(path, text, version).encode("utf-8")).decode().strip()
            git("update-index", "--cacheinfo", "%s,%s,%s" % (mode, new, path), env=env)
        tree = git("write-tree", env=env).decode().strip()
    # a tree has no date or commit: give it the commit's, as git archive <commit> does
    data = git("archive", "--format=zip", "--mtime=@" + ctime, tree, "Wuber")
    eocd = data.rfind(b"PK\x05\x06")
    if eocd < 0 or eocd + 22 != len(data):
        fail("git archive made a zip without a plain end record")
    return data[:eocd + 20] + struct.pack("<H", len(commit)) + commit.encode()


def scan_text(name, text):
    """[(name, line number, offending text)] for personal words, emails and local paths."""
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        for rx in (_WORD_RE, _EMAIL_RE, _PATH_RE):
            if rx is None:
                continue
            for m in rx.finditer(line):
                hits.append((name, i, m.group(0)))
    return hits


# Wuber is never called "free": its summons are paid (BRIEF22 T1). A shipped Lua line (not a comment) that has
# the word "free" and says Wuber is refused, unless it is one of these real uses, which do not describe Wuber:
#   - free summons / ride / raincheck / raid: a gift, a raincheck or a raid's own summons (not Wuber's price)
#   - "Free, no adverts, no invites": the raid-summons button's tooltip (Driver/Build.lua)
#   - the free OpenMap addon: another addon
# Lines with "free" but no "Wuber" (OpenMap, free seats, a Lua variable) are never flagged.
_FREE_RE = re.compile(r"(?<![A-Za-z0-9_])free(?![A-Za-z0-9_])", re.I)
FREE_ALLOWED = [re.compile(p, re.I) for p in (
    r"free (?:raid |summon|ride|raincheck)",
    r"Free, no adverts, no invites",
    r"free OpenMap addon|OpenMap \(free|Free addon: drivers",
)]


def scan_free(name, text):
    """[(name, line number, line)] where shipped Lua text calls Wuber free."""
    hits = []
    if not name.lower().endswith(".lua"):
        return hits
    for i, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("--") or not _FREE_RE.search(line) or "wuber" not in line.lower():
            continue
        if any(rx.search(line) for rx in FREE_ALLOWED):
            continue
        hits.append((name, i, line.strip()[:80]))
    return hits


def scan_zip(z):
    hits = []
    for n in z.namelist():
        if n.endswith("/") or not _TEXT_EXT.search(n):
            continue
        text = z.read(n).decode("utf-8", "replace")
        hits += scan_text(n, text) + scan_free(n, text)
    return hits


def find_changelog(roots, want):
    """release/CHANGELOG-<want>.md in the first root that has one, else the newest CHANGELOG-*.md there."""
    for root in roots:
        rel = os.path.join(root, "release")
        exact = os.path.join(rel, "CHANGELOG-%s.md" % want) if want else None
        if exact and os.path.exists(exact):
            return exact
    for root in roots:
        found = sorted(glob.glob(os.path.join(root, "release", "CHANGELOG-*.md")))
        if found:
            return found[-1]
    return None


def checkout_roots():
    """This checkout, then the main checkout when this is a worktree (release/ is untracked: it lives there)."""
    root = ROOT or repo_root()
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            capture_output=True, text=True, cwd=root).stdout.strip()
    roots = [root]
    main_root = os.path.dirname(common.rstrip("/\\")) if common else None
    if main_root and os.path.normcase(os.path.abspath(main_root)) != os.path.normcase(os.path.abspath(root)):
        roots.append(main_root)
    return roots


def scan_extras(roots, want, changelog=None, cf_dir=None):
    """Changelog and CurseForge page text. Missing files are skipped. roots: a list of checkouts (or one)."""
    hits = []
    if isinstance(roots, str):
        roots = [roots]
    if changelog is None:
        changelog = find_changelog(roots, want)
    scan_extras.changelog = changelog
    files = [changelog] if changelog else []
    cf_dir = cf_dir or os.environ.get("WUBER_CF_DIR")
    files += [os.path.join(cf_dir, f) for f in CF_FILES] if cf_dir else []
    for f in files:
        if os.path.exists(f):
            with open(f, "rb") as fh:
                hits += scan_text(f, fh.read().decode("utf-8", "replace"))
    return hits


def refuse(hits):
    if not hits:
        return
    for name, line, word in hits[:200]:
        sys.stderr.write("%s:%d:%s\n" % (name, line, word))
    sys.stderr.write("REFUSING: %d personal word/email/path/free-word hits (use 'the author'; see CLAUDE.md)\n" % len(hits))
    raise SystemExit(1)


def opt(args, flag):
    if flag in args:
        i = args.index(flag)
        v = args[i + 1]
        del args[i:i + 2]
        return v
    return None


def main():
    global ROOT
    ROOT = repo_root()
    args = sys.argv[1:]
    changelog, cf_dir, version = opt(args, "--changelog"), opt(args, "--curseforge"), opt(args, "--version")
    check_only = "--check-only" in args
    if check_only:
        args.remove("--check-only")
        args = [args[0] if args else "HEAD", None] + args[1:]
    elif version is not None:
        if not _VERSION_RE.match(version):
            fail("--version %s: a release number is a.b.c" % version)
        if len(args) == 1:
            if not args[0].lower().endswith(".zip"):
                fail("--version with one argument: it is the zip to write and ends in .zip\n" + __doc__)
            args = ["HEAD"] + args
        if len(args) == 3 and args[2] != version:
            fail("--version %s but expected version %s" % (version, args[2]))
        args = args[:2] + [version]
    if len(args) < 2 or any(a.startswith("--") for a in args if a):
        raise SystemExit(__doc__)
    ref, out = args[0], args[1]
    want = args[2] if len(args) > 2 else version
    if version is not None and changelog is None:
        roots = checkout_roots()
        if not any(os.path.exists(os.path.join(r, "release", "CHANGELOG-%s.md" % version)) for r in roots):
            fail("no release/CHANGELOG-%s.md in %s: write it first (or name one with --changelog)"
                 % (version, " or ".join(roots)))
    if version is not None and not check_only:
        data = stamped_archive(ref, version)
    else:
        data = git("archive", "--format=zip", ref, "Wuber")
    z = zipfile.ZipFile(io.BytesIO(data))
    refuse(scan_zip(z) + scan_extras(checkout_roots(), want, changelog, cf_dir))
    if check_only:
        print("%s: clean (no personal words, emails or local paths)" % ref)
        return
    names = [n for n in z.namelist() if not n.endswith("/")]
    bad = [n for n in names if not n.startswith("Wuber/") or re.search(r"(^|/)(tests?|tools|lab|docs)/|\.md$", n, re.I)]
    if bad:
        fail("not addon files: %s" % bad[:10])
    if any("ritual" in n.lower() for n in names):
        fail("a file name says ritual")
    toc = z.read("Wuber/Wuber.toc").decode("utf-8")
    m = re.search(r"^## Version: *(\S+)", toc, re.M)
    if not m:
        fail("Wuber/Wuber.toc has no ## Version")
    ver = m.group(1)
    if want and ver != want:
        fail("TOC says %s, wanted %s" % (ver, want))
    base = source_version("Wuber/Core/Base.lua", z.read("Wuber/Core/Base.lua").decode("utf-8")) \
        if "Wuber/Core/Base.lua" in names else None
    if base != ver:
        fail("Wuber/Core/Base.lua says W.VERSION %s, the TOC %s" % (base, ver))
    if not re.search(r"^## X-Curse-Project-ID: *1813140\s*$", toc, re.M):
        fail("X-Curse-Project-ID missing")
    listed = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
    missing = [l for l in listed if "Wuber/" + l.replace("\\", "/") not in names]
    if missing:
        fail("TOC files missing from the zip: %s" % missing)
    # Wuber/Bindings.xml (the game's Key Bindings list) is loaded by the game itself: it must ship, and the TOC must not
    # list it (a listed copy registers twice)
    if "Wuber/Bindings.xml" not in names:
        fail("Wuber/Bindings.xml is missing from the zip")
    if any(l.replace("\\", "/").lower().endswith("bindings.xml") for l in listed):
        fail("the TOC lists Bindings.xml: the game loads it by itself")
    with open(out, "wb") as f:
        f.write(data)
    print("%s: %d files, %.1f KB, Wuber/Wuber.toc ## Version: %s%s, %d TOC files all present; changelog scanned: %s"
          % (out, len(names), len(data) / 1024, ver, " (stamped into the zip only)" if version else "", len(listed),
             getattr(scan_extras, "changelog", None) or "none found"))

if __name__ == "__main__":
    main()
