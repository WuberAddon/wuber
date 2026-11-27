#!/usr/bin/env python3
"""Wuber: turns a clip (or a folder of numbered png frames) into a flipbook sheet and mends the loop seam.

    python tools/art/flipbook.py clip.mp4 --frames 32 --cell 256 --cols 8 --out sheet.tga --png preview.png
    python tools/art/flipbook.py --plans            # the two-plan comparison, from arithmetic alone

How it works: it never shortens the loop. It takes N + K frames evenly over the whole chosen span, and
output frame i (i < K) is a mix of sample i and sample N + i, the weight moving from the late sample to the
early one. So the step from the last output frame to the first is as small as an ordinary step.
Needs Python 3, Pillow, numpy; ffmpeg and ffprobe on PATH for clips (png folders need no ffmpeg).
Writes the sheet as a 32-bit TGA the way tools/make_media.py does, and a report beside it (.json).
Tool only: it writes nothing into Wuber/.
"""
import argparse
import glob
import json
import math
import os
import struct
import subprocess
import sys

import numpy as np
from PIL import Image

MAX_SHEET = 2048
ADDON_FPS = 20       # Wuber/FX/Effects.lua FPS: the one shared driver steps flipbooks 20 times a second
ADDON_MAX_LIVE = 12  # Effects.lua MAX_LIVE: flipbooks animating at once; the rest are shown still


class FlipbookError(Exception):
    pass


def write_tga(img, path):
    """Uncompressed true-colour TGA, 32 bits, 8 alpha bits, rows stored bottom-up (as tools/make_media.py)."""
    img = img.convert("RGBA")
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    px = img.tobytes("raw", "BGRA")
    stride = w * 4
    rows = [px[i * stride:(i + 1) * stride] for i in range(h)]
    rows.reverse()
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


def pow2_up(n):
    p = 1
    while p < n:
        p *= 2
    return p


def sample_times(start, end, n, k):
    """N + K times evenly over [start, end): the first is start, the last is end less one step."""
    step = (end - start) / float(n + k)
    return [start + j * step for j in range(n + k)]


def mend(frames, n, k):
    """frames: N + K float arrays. Returns N frames, the first K cross-faded from the late samples."""
    out = [f for f in frames[:n]]
    for i in range(k):
        late = (k - i) / float(k + 1)  # weight of the late sample: high first, then falling
        out[i] = frames[n + i] * late + frames[i] * (1.0 - late)
    return out


def mad(a, b):
    return float(np.mean(np.abs(a - b)))


def seam_score(frames):
    """Step from the last frame to the first, against the mean step between neighbours (ratio 1 = ordinary)."""
    steps = [mad(frames[i + 1], frames[i]) for i in range(len(frames) - 1)]
    mean_step = sum(steps) / len(steps) if steps else 0.0
    seam = mad(frames[-1], frames[0])
    return {"seam": seam, "mean_step": mean_step, "ratio": seam / mean_step if mean_step > 0 else 0.0}


# ----- reading frames ------------------------------------------------------------------------------

def fit_square(img, cell, mode):
    img = img.convert("RGB")
    w, h = img.size
    if mode == "crop":
        s = min(w, h)
        l, t = (w - s) // 2, (h - s) // 2
        img = img.crop((l, t, l + s, t + s)).resize((cell, cell), Image.LANCZOS)
        return img
    s = max(w, h)
    canvas = Image.new("RGB", (s, s), (0, 0, 0))
    canvas.paste(img, ((s - w) // 2, (s - h) // 2))
    return canvas.resize((cell, cell), Image.LANCZOS)


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height,r_frame_rate:format=duration", "-of", "json", path],
                         capture_output=True, text=True)
    if out.returncode != 0:
        raise FlipbookError("ffprobe could not read " + path + ": " + out.stderr.strip())
    d = json.loads(out.stdout)
    st = d["streams"][0]
    a, b = st["r_frame_rate"].split("/")
    fps = float(a) / float(b) if float(b) else 24.0
    return int(st["width"]), int(st["height"]), fps, float(d["format"]["duration"])


def clip_frame(path, t, w, h, cell, mode):
    """One frame at time t, scaled and squared by ffmpeg, as a float array (cell, cell, 3)."""
    if mode == "crop":
        vf = "crop=min(iw\\,ih):min(iw\\,ih),scale=%d:%d:flags=lanczos" % (cell, cell)
    else:
        vf = "scale=%d:%d:force_original_aspect_ratio=decrease:flags=lanczos,pad=%d:%d:(ow-iw)/2:(oh-ih)/2:black" % (cell, cell, cell, cell)
    cmd = ["ffmpeg", "-v", "error", "-ss", "%.4f" % t, "-i", path, "-frames:v", "1", "-vf", vf,
           "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    out = subprocess.run(cmd, capture_output=True)
    if out.returncode != 0 or len(out.stdout) != cell * cell * 3:
        raise FlipbookError("ffmpeg gave no frame at %.3f s of %s" % (t, path))
    return np.frombuffer(out.stdout, dtype=np.uint8).reshape(cell, cell, 3).astype(np.float64)


def load_samples(src, n, k, cell, mode, start, end, fps_in):
    """Returns (float frames, sample times, source info)."""
    need = n + k
    if os.path.isdir(src):
        files = sorted(glob.glob(os.path.join(src, "*.png")))
        if not files:
            raise FlipbookError("no png frames in " + src)
        total = len(files)
        fps = fps_in or 24.0
        dur = total / fps
        s = 0.0 if start is None else start
        e = dur if end is None else min(end, dur)
        i0, i1 = int(round(s * fps)), int(round(e * fps))
        avail = i1 - i0
        if avail < need:
            raise FlipbookError("the clip is too short for %d frames: %d source frames in the span, %d needed (%d + %d to mend the seam)"
                                % (n, avail, need, n, k))
        times = sample_times(s, e, n, k)
        frames = []
        for t in times:
            idx = min(total - 1, max(0, int(round(t * fps))))
            frames.append(np.asarray(fit_square(Image.open(files[idx]), cell, mode), dtype=np.float64))
        return frames, times, {"source": "png folder", "fps_in": fps, "duration": dur, "span": [s, e]}
    w, h, fps, dur = probe(src)
    s = 0.0 if start is None else start
    e = dur if end is None else min(end, dur)
    if e <= s:
        raise FlipbookError("the span is empty (start %.2f, end %.2f)" % (s, e))
    avail = int(math.floor((e - s) * fps + 1e-6))
    if avail < need:
        raise FlipbookError("the clip is too short for %d frames: about %d source frames in the span, %d needed (%d + %d to mend the seam). Use fewer frames."
                            % (n, avail, need, n, k))
    times = sample_times(s, e, n, k)
    frames = [clip_frame(src, t, w, h, cell, mode) for t in times]
    return frames, times, {"source": "clip", "fps_in": fps, "duration": dur, "span": [s, e], "size_in": [w, h]}


# ----- sheet ---------------------------------------------------------------------------------------

def to_rgba(frame, black_alpha):
    f = np.clip(frame, 0, 255)
    if black_alpha:
        a = f.max(axis=2)
        safe = np.where(a > 0, a, 1.0)
        rgb = np.where(a[..., None] > 0, f * 255.0 / safe[..., None], 0.0)
        out = np.dstack([rgb, a])
    else:
        out = np.dstack([f, np.full(f.shape[:2], 255.0)])
    return np.clip(np.rint(out), 0, 255).astype(np.uint8)


def layout(count, cell, cols):
    rows = int(math.ceil(count / float(cols)))
    return pow2_up(cols * cell), pow2_up(rows * cell), rows


def capacity(cell, cols):
    rows = MAX_SHEET // cell
    return cols * rows if cols * cell <= MAX_SHEET else 0


def make_sheet(frames, cell, cols, black_alpha):
    w, h, rows = layout(len(frames), cell, cols)
    sheet = np.zeros((h, w, 4), dtype=np.uint8)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        sheet[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = to_rgba(f, black_alpha)
    return Image.fromarray(sheet, "RGBA"), w, h


def plan_line(frames, cell, w, h, fps):
    size = w * h * 4 + 18
    return {"frames": frames, "cell": cell, "sheet": [w, h], "tga_bytes": size, "memory_bytes": w * h * 4,
            "seconds_per_loop": frames / float(fps)}


def mb(n):
    return "%.1f MB" % (n / 1048576.0)


def plans_table(fps=16):
    p1 = plan_line(32, 256, 2048, 1024, fps)
    p2 = plan_line(64, 256, 2048, 2048, fps)
    rows = []
    rows.append("Plan                                   Sheet        TGA file  Memory   Loop")
    for name, p in (("A: 32 frames of 256, 8 x 4", p1), ("B: 64 frames of 256, 8 x 8", p2)):
        rows.append("%-38s %-12s %-9s %-8s %.0f s at %d a second" % (
            name, "%d x %d" % tuple(p["sheet"]), mb(p["tga_bytes"]), mb(p["memory_bytes"]), p["seconds_per_loop"], fps))
    rows.append("In the addon (FX/Effects.lua): one shared driver steps every flipbook %d times a second, so %d a second plays at its own pace." % (ADDON_FPS, fps))
    rows.append("At most %d flipbooks move at once (crowns first); the rest show one still frame. Memory is per file, shared by every use." % ADDON_MAX_LIVE)
    rows.append("B costs twice A for the file and for video memory, and loads in one go the first time it shows.")
    return "\n".join(rows)


def sheets_line(name, w, h, cell, cols, count, blend):
    return ('%s = { file = "%s", w = %d, h = %d, cell = %d, cols = %d, blend = "%s" },   -- count = %d (in BOOKS)'
            % (name, name, w, h, cell, cols, blend, count))


def run(args):
    n = args.frames
    if n < 2:
        raise FlipbookError("need at least 2 frames")
    k = args.blend if args.blend is not None else max(1, int(round(n / 8.0)))
    if k < 0 or k >= n:
        raise FlipbookError("--blend must be from 0 to %d" % (n - 1))
    cell, cols = args.cell, args.cols
    per_sheet = capacity(cell, cols)
    if per_sheet == 0:
        raise FlipbookError("%d columns of %d px are wider than %d px" % (cols, cell, MAX_SHEET))
    sheets_needed = int(math.ceil(n / float(per_sheet)))
    if sheets_needed > 1 and not args.split:
        raise FlipbookError("%d frames of %d px do not fit one %d x %d sheet (%d fit). Use fewer frames, or --split to write %d sheets."
                            % (n, cell, MAX_SHEET, MAX_SHEET, per_sheet, sheets_needed))
    raw, times, info = load_samples(args.src, n, k, cell, args.square, args.start, args.end, args.fps_in)
    plain = raw[:n]
    mended = mend(raw, n, k) if k > 0 else plain
    before, after = seam_score(plain), seam_score(mended)

    out = args.out
    base, ext = os.path.splitext(out)
    chunks = [mended[i:i + per_sheet] for i in range(0, n, per_sheet)]
    files = []
    sheet_info = []
    for ci, chunk in enumerate(chunks):
        path = out if len(chunks) == 1 else "%s_%d%s" % (base, ci + 1, ext or ".tga")
        img, w, h = make_sheet(chunk, cell, cols, args.black_alpha)
        write_tga(img, path)
        if args.png:
            ppath = args.png if len(chunks) == 1 else "%s_%d%s" % (os.path.splitext(args.png)[0], ci + 1, os.path.splitext(args.png)[1] or ".png")
            bg = Image.new("RGBA", img.size, (40, 40, 40, 255))
            bg.alpha_composite(img)
            bg.convert("RGB").save(ppath)
        size = os.path.getsize(path)
        files.append(path)
        sheet_info.append({"file": path, "frames": len(chunk), "sheet": [w, h], "tga_bytes": size, "memory_bytes": w * h * 4})
    name = os.path.splitext(os.path.basename(out))[0]
    first = sheet_info[0]
    report = {
        "frames": n, "cell": cell, "cols": cols, "blend_frames": k, "source": info,
        "sampled_times": [round(times[0], 4), round(times[-1], 4)], "sheets": sheet_info,
        "sheet_width": first["sheet"][0], "sheet_height": first["sheet"][1],
        "tga_bytes": sum(s["tga_bytes"] for s in sheet_info), "memory_bytes": sum(s["memory_bytes"] for s in sheet_info),
        "fps_out": args.fps_out, "seconds_per_loop": n / float(args.fps_out),
        "seam_before": before, "seam_after": after,
        "sheets_line": sheets_line(name, first["sheet"][0], first["sheet"][1], cell, cols, n, "ADD" if args.black_alpha else "BLEND"),
        "black_alpha": bool(args.black_alpha),
    }
    # the gap between the late and the early end is spread over K + 1 steps, so K must be about the
    # "before" ratio for the seam step to match an ordinary one
    suggested = int(min(n - 1, max(1, math.ceil(before["ratio"]) - 1)))
    report["suggested_blend"] = suggested
    rpath = base + ".json"
    with open(rpath, "w") as f:
        json.dump(report, f, indent=2)
    lines = [
        "frames %d of %d px, %d columns, seam mended over %d frames" % (n, cell, cols, k),
        "span used %.2f s to %.2f s (last sample at %.2f s)" % (info["span"][0], info["span"][1], times[-1]),
        "sheet %d x %d%s, file %s, memory in the game %s" % (first["sheet"][0], first["sheet"][1],
                                                          " (x%d sheets)" % len(chunks) if len(chunks) > 1 else "",
                                                          mb(report["tga_bytes"]), mb(report["memory_bytes"])),
        "loop %.2f s at %d a second" % (report["seconds_per_loop"], args.fps_out),
        "seam, last to first frame: before %.2f (ordinary step %.2f, ratio %.2f), after %.2f (ordinary step %.2f, ratio %.2f)"
        % (before["seam"], before["mean_step"], before["ratio"], after["seam"], after["mean_step"], after["ratio"]),
        "paste into SHEETS: " + report["sheets_line"],
        "report: " + rpath,
    ]
    if after["ratio"] > 1.25 and k < suggested:
        lines.insert(5, "the seam step is still %.1f times an ordinary step: the late and early ends differ a lot, so try --blend %d (a longer cross-fade)"
                     % (after["ratio"], suggested))
    return report, "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Clip to flipbook sheet, with the loop seam mended by cross-fading.")
    ap.add_argument("src", nargs="?", help="a clip (mp4 or anything ffmpeg reads) or a folder of numbered png frames")
    ap.add_argument("--frames", type=int, default=32)
    ap.add_argument("--cell", type=int, default=256)
    ap.add_argument("--cols", type=int, default=8)
    ap.add_argument("--fps-out", type=float, default=16, help="for the printed numbers only")
    ap.add_argument("--fps-in", type=float, default=None, help="frame rate of a png folder (default 24)")
    ap.add_argument("--start", type=float, default=None, help="seconds (default the whole clip)")
    ap.add_argument("--end", type=float, default=None, help="seconds (default the whole clip)")
    ap.add_argument("--blend", type=int, default=None, help="frames at the end cross-faded into the start (default N/8; 0 = none)")
    ap.add_argument("--black-alpha", action="store_true", help="alpha from brightness, colour un-multiplied (clips on black)")
    ap.add_argument("--square", choices=("crop", "fit"), default="crop", help="centre crop (default) or fit with black bars")
    ap.add_argument("--out", default="sheet.tga")
    ap.add_argument("--png", default=None, help="write a preview png")
    ap.add_argument("--split", action="store_true", help="when the frames do not fit one sheet, write several")
    ap.add_argument("--plans", action="store_true", help="print the two-plan comparison and stop")
    args = ap.parse_args(argv)
    if args.plans:
        print(plans_table(int(args.fps_out)))
        return 0
    if not args.src:
        ap.error("give a clip or a folder of png frames (or --plans)")
    try:
        _, text = run(args)
    except FlipbookError as e:
        print("flipbook: " + str(e), file=sys.stderr)
        return 2
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
