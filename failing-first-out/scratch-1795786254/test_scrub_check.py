import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "scrub-check.py")

PATTERNS = (
    "real-name\t(?<![A-Za-z0-9_])Zork(?![A-Za-z0-9_])\n"
    "email-address\t[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+\n"
    "drive-path\t(?<![A-Za-z0-9])[A-Za-z]:[\\\\/]\n"
    "ALLOW\tAuthor: Zork Public\n"
)


def run(folder, patterns=PATTERNS, extra=()):
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as pf:
        pf.write(patterns)
    try:
        r = subprocess.run([sys.executable, "-I", SCRIPT, folder, "--patterns", pf.name, *extra],
                           capture_output=True, text=True)
    finally:
        os.unlink(pf.name)
    return r


def put(root, rel, text, mode="w"):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, mode, **({} if "b" in mode else {"encoding": "utf-8"})) as f:
        f.write(text)


class ScrubCheck(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()

    def test_clean_folder_passes(self):
        put(self.d, "a/b.lua", "print('hello')\n")
        r = run(self.d)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("0 hits", r.stdout)

    def test_name_is_found_with_file_and_line(self):
        put(self.d, "a/b.lua", "x = 1\nowner = 'Zork'\n")
        r = run(self.d)
        self.assertEqual(r.returncode, 1)
        self.assertIn("a/b.lua:2:", r.stdout)
        self.assertIn("real-name", r.stdout)

    def test_output_never_shows_the_matched_text_or_line(self):
        put(self.d, "k.txt", "mail zork.person" + "@" + "example.com now\n")
        r = run(self.d)
        self.assertEqual(r.returncode, 1)
        self.assertNotIn("zork.person", r.stdout + r.stderr)
        self.assertNotIn("example.com", r.stdout + r.stderr)

    def test_whole_word_only(self):
        put(self.d, "w.txt", "Zorkland and xZork are fine\n")
        self.assertEqual(run(self.d).returncode, 0)

    def test_drive_path_found(self):
        put(self.d, "p.txt", "see F" + ":\\project\\x\n")
        r = run(self.d)
        self.assertEqual(r.returncode, 1)
        self.assertIn("drive-path", r.stdout)

    def test_allow_line_is_exempt(self):
        put(self.d, "t.toc", "## Author: Zork Public\n")
        self.assertEqual(run(self.d).returncode, 0)

    def test_allow_does_not_cover_other_hit_on_same_line(self):
        put(self.d, "t.toc", "## Author: Zork Public and mail a" + "@b.co\n")
        self.assertEqual(run(self.d).returncode, 1)

    def test_file_name_is_scanned(self):
        put(self.d, "Zork-notes.txt", "nothing\n")
        put(self.d, "Zork/inside.txt", "nothing\n")
        r = run(self.d)
        self.assertEqual(r.returncode, 1)  # '-' and '/' are word boundaries, so both names hit
        self.assertIn("Zork-notes.txt:0:", r.stdout)
        self.assertIn("Zork:0:", r.stdout)

    def test_binary_files_skipped_and_counted(self):
        put(self.d, "img.bin", b"\x00\x01Zork\x00", mode="wb")
        r = run(self.d)
        self.assertEqual(r.returncode, 0)
        self.assertIn("skipped 1 binary", r.stdout)

    def _git_repo_with_untracked_log(self):
        put(self.d, "a.lua", "print('hello')\n")
        put(self.d, "tests/out/shard-1.log", "see F" + ":\\project\\x\n")
        subprocess.run(["git", "-C", self.d, "init", "-q"], check=True, capture_output=True)
        subprocess.run(["git", "-C", self.d, "add", "a.lua"], check=True, capture_output=True)

    def test_git_folder_scans_only_tracked_files(self):
        self._git_repo_with_untracked_log()
        r = run(self.d)
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("scanned 1 text files", r.stdout)

    def test_all_flag_scans_untracked_files_too(self):
        self._git_repo_with_untracked_log()
        r = run(self.d, extra=("--all",))
        self.assertEqual(r.returncode, 1)
        self.assertIn("tests/out/shard-1.log:1:", r.stdout)

    def test_tracked_file_with_a_hit_still_fails(self):
        self._git_repo_with_untracked_log()
        put(self.d, "b.txt", "see F" + ":\\project\n")
        subprocess.run(["git", "-C", self.d, "add", "b.txt"], check=True, capture_output=True)
        r = run(self.d)
        self.assertEqual(r.returncode, 1)
        self.assertIn("b.txt:1:", r.stdout)
        self.assertNotIn("shard-1.log", r.stdout)

    def test_git_folder_skipped(self):
        put(self.d, ".git/config", "Zork\n")
        self.assertEqual(run(self.d).returncode, 0)

    def test_bad_usage(self):
        self.assertEqual(run(os.path.join(self.d, "nope")).returncode, 2)
        self.assertEqual(subprocess.run([sys.executable, "-I", SCRIPT], capture_output=True).returncode, 2)

    def test_bad_pattern_file_line(self):
        r = run(self.d, patterns="no tab here\n")
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
