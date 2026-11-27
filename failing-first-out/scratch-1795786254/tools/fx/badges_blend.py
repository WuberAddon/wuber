"""Wuber driver badges and the gold coin: 3D enamel-and-gold tokens rendered in Cycles.

Each badge is a gold-rimmed token with a coloured enamel face and a raised gold symbol on
both sides (the back is the front turned 180 degrees about the vertical axis, so a half
turn brings the token back to its start: the loop has no seam). Badges turn with easing so
the face lingers and the edge flicks past. The coin is a plain gold coin with a W.

Symbols are drawn as 2D masks with PIL, traced with scikit-image and extruded as curves.

    python3 tools/fx/badges_blend.py OUTDIR [frames] [res] [samples] [only]
    (writes OUTDIR/<id>/f00.png ... for bolt, star, flame, moon, crystal, skull, coin)
"""
import math
import os
import sys

import bpy  # noqa: I001 (bpy first)
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage import measure

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_blend as C  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fxr/badges"
FRAMES = int(sys.argv[2]) if len(sys.argv) > 2 else 10
RES = int(sys.argv[3]) if len(sys.argv) > 3 else 240
SAMPLES = int(sys.argv[4]) if len(sys.argv) > 4 else 32
ONLY = sys.argv[5].split(",") if len(sys.argv) > 5 else None

M = 512  # mask size


def P(x, y):
    """unit coords (-1..1, y up) -> mask pixels"""
    return (M / 2 + x * M / 2 * 0.92, M / 2 - y * M / 2 * 0.92)


def poly(d, pts, fill=255):
    d.polygon([P(x, y) for x, y in pts], fill=fill)


def ellipse(d, cx, cy, rx, ry, fill=255):
    x0, y0 = P(cx - rx, cy + ry)
    x1, y1 = P(cx + rx, cy - ry)
    d.ellipse((x0, y0, x1, y1), fill=fill)


def sym_bolt(d):
    poly(d, [(0.22, 0.98), (-0.52, -0.02), (-0.06, -0.02), (-0.30, -0.98), (0.56, 0.16), (0.08, 0.16), (0.48, 0.98)])


def sym_star(d):
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = 0.98 if i % 2 == 0 else 0.42
        pts.append((r * math.cos(a), r * math.sin(a) - 0.05))
    poly(d, pts)


def tear(cx, cy, w, h, lean=0.0, n=90):
    """A flame tongue: round bottom at (cx, cy - h/2), sharp tip at the top, leaning."""
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = math.sin(t) * math.sin(t / 2) ** 1.6
        y = math.cos(t)          # tip at t = 0 (y = 1)
        u = (y + 1) / 2          # 0 bottom .. 1 tip
        x = x * w + lean * u ** 2.2
        pts.append((cx + x, cy + y * h / 2))
    return pts


def sym_flame(d):
    poly(d, tear(0.0, 0.02, 0.70, 1.92, 0.10))     # the main flame
    poly(d, tear(-0.36, -0.30, 0.36, 1.10, -0.22))  # left tongue
    poly(d, tear(0.38, -0.22, 0.38, 1.20, 0.20))    # right tongue
    poly(d, tear(0.02, -0.40, 0.26, 0.86, -0.06), fill=0)  # the hot hollow inside


def sym_moon(d):
    ellipse(d, -0.08, 0.0, 0.82, 0.82)
    ellipse(d, 0.26, 0.20, 0.70, 0.70, fill=0)
    # a little sparkle beside it
    s = 0.24
    poly(d, [(0.55, 0.62 + s), (0.55 + s * 0.28, 0.62), (0.55, 0.62 - s), (0.55 - s * 0.28, 0.62)])
    poly(d, [(0.55 + s, 0.62), (0.55, 0.62 + s * 0.28), (0.55 - s, 0.62), (0.55, 0.62 - s * 0.28)])


def sym_crystal(d):
    def gem(cx, cy, w, h, tilt):
        pts = [(0, h), (w, h * 0.45), (w, -h * 0.45), (0, -h), (-w, -h * 0.45), (-w, h * 0.45)]
        c, s = math.cos(tilt), math.sin(tilt)
        return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    poly(d, gem(0, 0.02, 0.34, 0.98, 0))
    poly(d, gem(-0.56, -0.25, 0.17, 0.5, 0.45))
    poly(d, gem(0.56, -0.25, 0.17, 0.5, -0.45))
    # facet grooves
    w = 6
    d.line([P(0, 0.98), P(0, -0.98)], fill=0, width=w)
    d.line([P(-0.34, 0.44), P(0, 0.2), P(0.34, 0.44)], fill=0, width=w)
    d.line([P(-0.34, -0.42), P(0, -0.2), P(0.34, -0.42)], fill=0, width=w)


def sym_skull(d):
    ellipse(d, 0, 0.18, 0.72, 0.68)
    poly(d, [(-0.42, -0.2), (0.42, -0.2), (0.38, -0.82), (-0.38, -0.82)])
    ellipse(d, 0, -0.80, 0.38, 0.12)
    ellipse(d, -0.28, 0.08, 0.2, 0.22, fill=0)
    ellipse(d, 0.28, 0.08, 0.2, 0.22, fill=0)
    poly(d, [(0, -0.12), (-0.1, -0.32), (0.1, -0.32)], fill=0)
    for x in (-0.2, 0.0, 0.2):
        d.line([P(x, -0.55), P(x, -0.9)], fill=0, width=9)


def sym_coin(d):
    font = None
    for p in ("/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(p):
            font = ImageFont.truetype(p, 360)
            break
    if font is None:
        font = ImageFont.load_default()
    bb = d.textbbox((0, 0), "W", font=font)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    d.text(((M - w) / 2 - bb[0], (M - h) / 2 - bb[1]), "W", fill=255, font=font)


BADGES = {
    # id: (symbol, enamel colour, symbol size on the token)
    "bolt": (sym_bolt, (0.06, 0.30, 1.0), 0.6),
    "star": (sym_star, (0.40, 0.05, 0.95), 0.62),
    "flame": (sym_flame, (1.0, 0.22, 0.03), 0.6),
    "moon": (sym_moon, (0.05, 0.05, 0.42), 0.6),
    "crystal": (sym_crystal, (0.85, 0.06, 0.70), 0.6),
    "skull": (sym_skull, (0.10, 0.70, 0.10), 0.58),
    "coin": (sym_coin, None, 0.56),
}


def loops_for(fn, size):
    img = Image.new("L", (M, M), 0)
    fn(ImageDraw.Draw(img))
    a = np.asarray(img).astype(float) / 255.0
    a = np.pad(a, 2)
    loops = []
    for c in measure.find_contours(a, 0.5):
        c = measure.approximate_polygon(c, tolerance=0.7)
        if len(c) < 4:
            continue
        pts = [((col - 2 - M / 2) / (M / 2) * size, (M / 2 - (row - 2)) / (M / 2) * size) for row, col in c[:-1]]
        loops.append(pts)
    return loops


def build(bid):
    C.reset_scene(RES, SAMPLES)
    C.studio_world(1.0)
    C.studio_lights(0.8)
    fn, enamel_col, size = BADGES[bid]
    gold = C.gold_material("gold", 0.16, (1.0, 0.76, 0.30))
    objs = []
    coin = enamel_col is None
    if coin:
        face = C.gold_material("coinFace", 0.3, (0.95, 0.68, 0.22))
    else:
        face = C.principled("enamel", enamel_col, rough=0.12, coat=0.6, spec=0.5,
                            emission=enamel_col, estrength=0.12)
    # the face: a disc whose axis is Y (towards the camera)
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=72, radius1=0.86, radius2=0.86, depth=0.14)
    disc = C.mesh_object("disc", bm, face)
    disc.rotation_euler = (math.pi / 2, 0, 0)
    objs.append(disc)
    objs.append(C.torus("rim", gold, 0.92, 0.095, (0, 0, 0), (math.pi / 2, 0, 0), 96, 18))
    loops = loops_for(fn, size)
    for side, rz in (("front", 0.0), ("back", math.pi)):
        o = C.outline_object("sym_" + side, gold, loops, 0.03, 0.012)
        o.rotation_euler = (math.pi / 2, 0, rz)
        o.location = (0, -0.1 if side == "front" else 0.1, 0)
        objs.append(o)
    root = C.link(bpy.data.objects.new("token", None))
    C.parent_all(root, objs)
    C.camera((0, -9.0, 1.3), (0, 0, 0), ortho=2.45)
    out = os.path.join(OUT, bid)
    os.makedirs(out, exist_ok=True)
    for f in range(FRAMES):
        t = f / FRAMES
        if coin:
            ang = 180.0 * t  # coins flip evenly
        else:
            ang = 180.0 * (t - 0.75 * math.sin(2 * math.pi * t) / (2 * math.pi))
        root.rotation_euler = (0, 0, math.radians(ang))
        C.render_to(os.path.join(out, "f%02d.png" % f))
    print("done", bid, flush=True)


for bid in BADGES:
    if ONLY and bid not in ONLY:
        continue
    n = FRAMES
    if bid == "coin":
        FRAMES_SAVE = FRAMES
        FRAMES = 8
        build(bid)
        FRAMES = FRAMES_SAVE
    else:
        build(bid)
