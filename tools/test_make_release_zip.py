"""Tests for tools/make_release_zip.py scanning.  python tools/test_make_release_zip.py"""
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
# made-up personal words, in a temporary word file the script reads (WUBER_PERSONAL_WORDS)
_WF = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8")
_WF.write("Zork\nQuux\nzorkw\nPlugh\nXyzzy\nFrobnitz\nWibble\n")
_WF.close()
os.environ["WUBER_PERSONAL_WORDS"] = _WF.name
sys.path.insert(0, HERE)
import make_release_zip as M  # noqa: E402


def words(text):
    return [h[2] for h in M.scan_text("x.lua", text)]


class Scan(unittest.TestCase):
    def test_clean(self):
        self.assertEqual(words("-- the author wrote this\nlocal x = 1\nW.CREATOR = {['anita lift']=true, ['farra way']=true, ['hayley cab']=true, ['wuber rocks']=true}"), [])

    def test_each_word(self):
        for w in M.PERSONAL_WORDS:
            for form in (w, w.upper(), w.lower()):
                self.assertEqual(len(words("-- by %s." % form)), 1, form)

    def test_whole_words_only(self):
        for ok in ("zorkwood", "Zorkda", "Quuxsprings", "Frobnitzd", "Wibbles", "xzork"):
            self.assertEqual(words(ok), [], ok)
        self.assertEqual(len(words("zorkw")), 1)
        self.assertEqual(len(words("Zork's")), 1)

    def test_email_and_paths(self):
        self.assertTrue(words("mail me a.b@example.com"))
        drv = "F" + ":"  # (spelled in two parts so the repo's own scan does not read a path here)
        for p in (drv + "\\proj", drv.lower() + "/proj/x", "C" + ":\\Users\\x", "c" + ":/users/x", drv + "\\\\proj",
                  "/f" + "/proj/bin", "/c" + "/Users/x"):
            self.assertTrue(words("see " + p), p)
        self.assertEqual(words("Interface/AddOns/Wuber and Interface\\AddOns, a/b, the f/stop"), [])

    def test_line_numbers(self):
        h = M.scan_text("a.md", "ok\nok\nZork here")
        self.assertEqual(h, [("a.md", 3, "Zork")])


class NoWordFile(unittest.TestCase):
    def test_without_a_word_file_only_the_generic_checks_run(self):
        self.assertEqual(M.load_personal_words(os.path.join(tempfile.gettempdir(), "no-such-word-file.txt")), [])
        self.assertIsNone(M.word_re([]))
        self.assertTrue(M.scan_text("x", "mail a@example.com"))
        self.assertTrue(M.scan_text("x", "see " + "F" + ":\\proj"))


class Cli(unittest.TestCase):
    def run_cli(self, files, extra=()):
        d = tempfile.mkdtemp()
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull)
        g = lambda *a: subprocess.run(["git", "-c", "user.email=a@b", "-c", "user.name=t", *a], cwd=d, check=True, capture_output=True, env=env)
        g("init", "-q")
        os.makedirs(os.path.join(d, "Wuber"))
        for n, t in files.items():
            with open(os.path.join(d, "Wuber", n), "w") as f:
                f.write(t)
        g("add", "-A")
        g("commit", "-qm", "x")
        r = subprocess.run([sys.executable, os.path.join(HERE, "make_release_zip.py"), "--check-only", "HEAD", *extra],
                           cwd=d, capture_output=True, text=True, env=env)
        return r, d

    def test_clean_passes(self):
        r, _ = self.run_cli({"a.lua": "-- the author\n"}, ["--curseforge", tempfile.mkdtemp()])
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_dirty_refuses_with_file_line_word(self):
        r, _ = self.run_cli({"a.lua": "x\n-- Zork asked\n"}, ["--curseforge", tempfile.mkdtemp()])
        self.assertEqual(r.returncode, 1)
        self.assertIn("Wuber/a.lua:2:Zork", r.stderr)

    def test_changelog_and_curseforge_scanned(self):
        cf = tempfile.mkdtemp()
        with open(os.path.join(cf, "wuber-curseforge-flat.html"), "w") as f:
            f.write("<p>from Xyzzy</p>")
        r, _ = self.run_cli({"a.lua": "x\n"}, ["--curseforge", cf])
        self.assertEqual(r.returncode, 1)
        self.assertIn("wuber-curseforge-flat.html:1:Xyzzy", r.stderr)
        cl = os.path.join(tempfile.mkdtemp(), "CHANGELOG.md")
        with open(cl, "w") as f:
            f.write("see " + "F" + ":\\proj\n")
        r, _ = self.run_cli({"a.lua": "x\n"}, ["--changelog", cl, "--curseforge", tempfile.mkdtemp()])
        self.assertEqual(r.returncode, 1)
        self.assertIn("CHANGELOG.md:1:", r.stderr)


TOC = ("## Interface: 16001\n## Title: Wuber\n## Version: 1.2.3-dev\n## X-Curse-Project-ID: 1813140\n"
       "Core\\Base.lua\na.lua\n")
BASE = '-- the author\nlocal _, W = ...\nW.VERSION = "1.2.3-dev"\nW.PREFIX = "WUBER"\n'


def repo(files):
    """A throwaway git repo with Wuber/<files>, committed; (dir, git runner)."""
    d = tempfile.mkdtemp()
    env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull)

    def g(*a, cwd=d):
        return subprocess.run(["git", "-c", "user.email=a@b", "-c", "user.name=t", *a], cwd=cwd, check=True,
                              capture_output=True, env=env).stdout.decode()
    g("init", "-q")
    for n, t in files.items():
        p = os.path.join(d, "Wuber", *n.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", newline="\n") as f:
            f.write(t)
    g("add", "-A")
    g("commit", "-qm", "x")
    return d, g


def clean_changelog():
    p = os.path.join(tempfile.mkdtemp(), "CHANGELOG-1.2.3.md")
    with open(p, "w") as f:
        f.write("the author's notes\n")
    return p


def cli(cwd, *args):
    env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull)
    return subprocess.run([sys.executable, os.path.join(HERE, "make_release_zip.py"), *args],
                          cwd=cwd, capture_output=True, text=True, env=env)


ADDON = {"Wuber.toc": TOC, "Core/Base.lua": BASE, "a.lua": "-- the author\nlocal x = 1\n"}


class Stamp(unittest.TestCase):
    def test_stamp_text(self):
        self.assertIn("## Version: 2.3.2\n", M.stamp_text("Wuber/Wuber.toc", TOC, "2.3.2"))
        self.assertIn('W.VERSION = "2.3.2"\n', M.stamp_text("Wuber/Core/Base.lua", BASE, "2.3.2"))
        with self.assertRaises(SystemExit):
            M.stamp_text("Wuber/Core/Base.lua", "local x = 1\n", "2.3.2")

    def test_build_stamps_only_the_zip(self):
        d, g = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(d, "--version", "1.2.3", "HEAD", out, "--curseforge", tempfile.mkdtemp(), "--changelog", clean_changelog())
        self.assertEqual(r.returncode, 0, r.stderr)
        z = zipfile.ZipFile(out)
        self.assertRegex(z.read("Wuber/Wuber.toc"), rb"## Version: 1\.2\.3\r?\n")
        self.assertRegex(z.read("Wuber/Core/Base.lua"), rb'W\.VERSION = "1\.2\.3"\r?\n')
        # the checkout is untouched: still -dev, nothing to commit
        with open(os.path.join(d, "Wuber", "Wuber.toc")) as f:
            self.assertIn("1.2.3-dev", f.read())
        self.assertEqual(g("status", "--porcelain"), "")
        # everything else is what git archive makes from that commit: names, order, bytes, dates, comment
        plain = os.path.join(tempfile.mkdtemp(), "p.zip")
        g("archive", "--format=zip", "-o", plain, "HEAD", "Wuber")
        p = zipfile.ZipFile(plain)
        self.assertEqual(z.namelist(), p.namelist())
        for a, b in zip(z.infolist(), p.infolist()):
            self.assertEqual((a.date_time, a.external_attr, a.compress_type), (b.date_time, b.external_attr, b.compress_type), a.filename)
            if a.filename not in ("Wuber/Wuber.toc", "Wuber/Core/Base.lua"):
                self.assertEqual(z.read(a), p.read(b), a.filename)
        self.assertEqual(z.comment, g("rev-parse", "HEAD").strip().encode())

    def test_default_ref_is_head(self):
        d, _ = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(d, "--version", "1.2.3", out, "--curseforge", tempfile.mkdtemp(), "--changelog", clean_changelog())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertRegex(zipfile.ZipFile(out).read("Wuber/Wuber.toc"), rb"## Version: 1\.2\.3\r?\n")

    def test_refuses_another_number(self):
        d, _ = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(d, "--version", "1.2.4", "HEAD", out, "--curseforge", tempfile.mkdtemp(), "--changelog", clean_changelog())
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("1.2.3-dev", r.stderr)
        self.assertFalse(os.path.exists(out))

    def test_old_positional_form(self):
        d, _ = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(d, "HEAD", out, "1.2.3-dev", "--curseforge", tempfile.mkdtemp())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertRegex(zipfile.ZipFile(out).read("Wuber/Wuber.toc"), rb"## Version: 1\.2\.3-dev\r?\n")

    def test_toc_and_base_must_agree(self):
        d, _ = repo(dict(ADDON, **{"Core/Base.lua": BASE.replace("1.2.3-dev", "1.2.2-dev")}))
        r = cli(d, "HEAD", os.path.join(tempfile.mkdtemp(), "w.zip"), "--curseforge", tempfile.mkdtemp())
        self.assertNotEqual(r.returncode, 0)

    def test_from_a_subdirectory(self):
        d, _ = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(os.path.join(d, "Wuber", "Core"), "--version", "1.2.3", out, "--curseforge", tempfile.mkdtemp(),
                "--changelog", clean_changelog())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertRegex(zipfile.ZipFile(out).read("Wuber/Core/Base.lua"), rb'W\.VERSION = "1\.2\.3"')

    def test_one_argument_must_be_a_zip(self):
        d, _ = repo(ADDON)
        r = cli(d, "--version", "1.2.3", "HEAD", "--curseforge", tempfile.mkdtemp(), "--changelog", clean_changelog())
        self.assertEqual(r.returncode, 1)
        self.assertIn("ends in .zip", r.stderr)

    def test_version_needs_its_changelog(self):
        d, _ = repo(ADDON)
        out = os.path.join(tempfile.mkdtemp(), "w.zip")
        r = cli(d, "--version", "1.2.3", out, "--curseforge", tempfile.mkdtemp())
        self.assertEqual(r.returncode, 1)
        self.assertIn("CHANGELOG-1.2.3.md", r.stderr)
        self.assertFalse(os.path.exists(out))
        os.makedirs(os.path.join(d, "release"))
        with open(os.path.join(d, "release", "CHANGELOG-1.2.3.md"), "w") as f:
            f.write("the author's notes\n")
        self.assertEqual(cli(d, "--version", "1.2.3", out, "--curseforge", tempfile.mkdtemp()).returncode, 0)

    def test_changelog_found_in_the_main_checkout_from_a_worktree(self):
        d, g = repo(ADDON)
        os.makedirs(os.path.join(d, "release"))
        with open(os.path.join(d, "release", "CHANGELOG-1.2.3.md"), "w") as f:
            f.write("thanks Zork\n")
        wt = os.path.join(tempfile.mkdtemp(), "wt")
        g("worktree", "add", "-q", "--detach", wt)
        r = cli(wt, "--version", "1.2.3", os.path.join(tempfile.mkdtemp(), "w.zip"), "--curseforge", tempfile.mkdtemp())
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("CHANGELOG-1.2.3.md:1:Zork", r.stderr)


if __name__ == "__main__":
    unittest.main()
