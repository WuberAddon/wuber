"""Tests for tools/art/flipbook.py.  python -m unittest tools.art.test_flipbook  (or python tools/art/test_flipbook.py)"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import flipbook as F  # noqa: E402

N = 16


def make_clip(folder, secs=2.0, fps=24, size=256):
    """A turning spiral that also grows and brightens: it does not loop cleanly. Encoded by ffmpeg (mpeg4)."""
    frames = int(secs * fps)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    cx = cy = size / 2.0
    dx, dy = xx - cx, yy - cy
    r = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    os.makedirs(folder, exist_ok=True)
    for i in range(frames):
        u = i / float(frames - 1)
        rad = size * (0.12 + 0.34 * u)  # grows
        arms = 0.5 + 0.5 * np.sin(3 * th + r * 0.12 - u * 6.28 * 1.3)
        v = arms * np.clip(1.0 - r / rad, 0, 1) * (0.4 + 0.6 * u)
        img = np.dstack([v * 255, v * 180 * (1 - u * 0.5), v * 255 * u]).astype(np.uint8)
        Image.fromarray(img, "RGB").save(os.path.join(folder, "f%04d.png" % i))
    clip = os.path.join(folder, "clip.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", str(fps), "-i", os.path.join(folder, "f%04d.png"),
                    "-c:v", "mpeg4", "-q:v", "2", "-pix_fmt", "yuv420p", clip], check=True)
    return clip


class Flipbook(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.clip = make_clip(os.path.join(cls.tmp.name, "src"))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_tool(self, name, *extra, src=None):
        out = os.path.join(self.tmp.name, name + ".tga")
        argv = [src or self.clip, "--frames", str(N), "--cell", "64", "--cols", "4", "--out", out,
                "--png", os.path.join(self.tmp.name, name + ".png")] + list(extra)
        rc = F.main(argv)
        self.assertEqual(rc, 0)
        with open(os.path.join(self.tmp.name, name + ".json")) as f:
            return out, json.load(f)

    def read_tga(self, path):
        with open(path, "rb") as f:
            data = f.read()
        w = int.from_bytes(data[12:14], "little")
        h = int.from_bytes(data[14:16], "little")
        self.assertEqual(data[16], 32)
        px = np.frombuffer(data[18:], dtype=np.uint8).reshape(h, w, 4)[::-1]  # bottom-up
        return px[..., [2, 1, 0, 3]]  # BGRA to RGBA

    def test_sheet_size_and_cells(self):
        out, rep = self.run_tool("a")
        px = self.read_tga(out)
        self.assertEqual(px.shape[:2], (256, 256))  # 4 cols x 4 rows of 64
        self.assertEqual(rep["frames"], N)
        self.assertEqual(rep["sheet_width"], 256)
        self.assertEqual(rep["memory_bytes"], 256 * 256 * 4)
        self.assertEqual(os.path.getsize(out), 18 + 256 * 256 * 4)
        for i in range(N):
            r, c = divmod(i, 4)
            cell = px[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64, :3]
            self.assertGreater(cell.max(), 40, "cell %d is empty" % i)
            self.assertTrue((px[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64, 3] == 255).all())
        self.assertIn("cell = 64, cols = 4", rep["sheets_line"])

    def test_non_pow2_sheet_rounds_up(self):
        w, h, rows = F.layout(10, 256, 3)
        self.assertEqual((w, h), (1024, 1024))
        self.assertEqual(rows, 4)

    def test_seam_mended(self):
        _, rep = self.run_tool("b")
        before, after = rep["seam_before"], rep["seam_after"]
        self.assertGreater(before["ratio"], 2.0, "the test clip should not loop cleanly")
        self.assertLess(after["ratio"], before["ratio"] / 2, "clearly better than before")
        self.assertLess(after["seam"], before["seam"] / 2)
        self.assertEqual(rep["suggested_blend"], 7)
        _, long = self.run_tool("b8", "--blend", "8")
        self.assertLessEqual(long["seam_after"]["ratio"], 1.25, "a long enough cross-fade closes the seam")
        _, none = self.run_tool("b0", "--blend", "0")
        self.assertAlmostEqual(none["seam_after"]["ratio"], none["seam_before"]["ratio"])

    def test_whole_span_used(self):
        _, rep = self.run_tool("c")
        first, last = rep["sampled_times"]
        dur = rep["source"]["span"][1]
        self.assertAlmostEqual(first, 0.0, places=3)
        step = dur / (N + rep["blend_frames"])
        self.assertAlmostEqual(last, dur - step, places=3)
        self.assertEqual(rep["source"]["span"][0], 0.0)

    def test_start_end(self):
        _, rep = self.run_tool("c2", "--start", "0.5", "--end", "1.5", "--frames", "8")
        self.assertAlmostEqual(rep["sampled_times"][0], 0.5, places=3)
        self.assertLess(rep["sampled_times"][1], 1.5)

    def test_black_alpha_corners_clear(self):
        out, rep = self.run_tool("d", "--black-alpha")
        px = self.read_tga(out)
        for i in range(N):
            r, c = divmod(i, 4)
            cell = px[r * 64:(r + 1) * 64, c * 64:(c + 1) * 64]
            for (y, x) in ((0, 0), (0, 63), (63, 0), (63, 63)):
                self.assertEqual(cell[y, x, 3], 0, "corner of frame %d is not clear" % i)
            self.assertGreater(cell[..., 3].max(), 20)

    def test_png_folder(self):
        out, rep = self.run_tool("e", src=os.path.join(self.tmp.name, "src"))
        self.assertEqual(rep["source"]["source"], "png folder")
        self.assertLess(rep["seam_after"]["ratio"], rep["seam_before"]["ratio"] / 2)

    def test_too_short_refused(self):
        out = os.path.join(self.tmp.name, "short.tga")
        err = self.capture_stderr(lambda: F.main([self.clip, "--frames", "64", "--cell", "64", "--cols", "8", "--out", out]))
        self.assertEqual(err[0], 2)
        self.assertIn("too short", err[1])
        self.assertFalse(os.path.exists(out))

    def test_too_many_for_one_sheet(self):
        out = os.path.join(self.tmp.name, "big.tga")
        err = self.capture_stderr(lambda: F.main([self.clip, "--frames", "40", "--cell", "512", "--cols", "4", "--out", out]))
        self.assertEqual(err[0], 2)
        self.assertIn("--split", err[1])

    def capture_stderr(self, fn):
        import io
        import contextlib
        buf = io.StringIO()
        with contextlib.redirect_stderr(buf):
            rc = fn()
        return rc, buf.getvalue()

    def test_plans_table(self):
        t = F.plans_table(16)
        self.assertEqual(len(t.splitlines()), 6)
        self.assertIn("2048 x 1024", t)
        self.assertIn("2048 x 2048", t)
        self.assertIn("20 times a second", t)
        self.assertIn("12 flipbooks", t)


if __name__ == "__main__":
    unittest.main()
