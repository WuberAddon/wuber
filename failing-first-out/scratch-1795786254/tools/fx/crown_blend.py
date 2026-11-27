"""Wuber founder crown: a real 3D gold crown with violet gems, a velvet cap, five arches and a
glowing violet orb, rendered in Cycles as a seamless spinning loop.

The crown has five-fold symmetry, so turning it 72 degrees brings it back to the start:
FRAMES renders cover exactly one 72-degree turn and the loop has no seam.

    python3 tools/fx/crown_blend.py OUTDIR [frames] [res] [samples]
"""
import math
import os
import sys

import bpy  # noqa: I001 (bpy first: it provides bmesh and mathutils)
import bmesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common_blend as C  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fxr/crown"
FRAMES = int(sys.argv[2]) if len(sys.argv) > 2 else 32
RES = int(sys.argv[3]) if len(sys.argv) > 3 else 240
SAMPLES = int(sys.argv[4]) if len(sys.argv) > 4 else 40
os.makedirs(OUT, exist_ok=True)

C.reset_scene(RES, SAMPLES)
C.studio_world(1.0)
C.studio_lights(1.0)

gold = C.gold_material("gold", 0.18, (1.0, 0.76, 0.30))
gold_dark = C.gold_material("goldDark", 0.32, (0.85, 0.55, 0.20))
violet = C.gem_material("violetGem", (0.30, 0.04, 1.0), 0.9)
magenta = C.gem_material("magentaGem", (0.90, 0.15, 0.95), 0.8)
orb_mat = C.gem_material("orb", (0.45, 0.10, 1.0), 1.3)
velvet = C.principled("velvet", (0.06, 0.008, 0.16), rough=0.95, sheen=0.5, sheen_tint=(0.55, 0.25, 1.0),
                      emission=(0.22, 0.03, 0.45), estrength=0.08)
pearl = C.principled("pearl", (0.98, 0.94, 1.0), rough=0.15, coat=1.0, spec=0.8)

N = 5                     # points (five-fold symmetry)
SEG = 72 * 5              # wall segments around
BAND_TOP = 0.42


def radius_at(z):
    return 1.0 + 0.11 * z            # the crown widens towards the top


def spike(d, w, h):
    if d >= w:
        return 0.0
    return h * (1.0 - d / w) ** 1.5


def top_height(theta):
    s = (theta * N / (2 * math.pi)) % 1.0
    dt = min(s, 1.0 - s)
    ds = abs(s - 0.5)
    return 0.50 + max(spike(dt, 0.30, 0.60), spike(ds, 0.19, 0.27))


# The wall: one continuous shell, band and points together, with an inner face and a rim.
bm = bmesh.new()
ROWS = 18
THICK = 0.055
outer, inner = [], []
for i in range(SEG):
    th = 2 * math.pi * i / SEG
    h = top_height(th)
    o_col, i_col = [], []
    for j in range(ROWS + 1):
        t = j / ROWS
        z = h * t
        r = radius_at(z)
        o_col.append(bm.verts.new((r * math.cos(th), r * math.sin(th), z)))
        i_col.append(bm.verts.new(((r - THICK) * math.cos(th), (r - THICK) * math.sin(th), z)))
    outer.append(o_col)
    inner.append(i_col)
for i in range(SEG):
    k = (i + 1) % SEG
    for j in range(ROWS):
        bm.faces.new((outer[i][j], outer[k][j], outer[k][j + 1], outer[i][j + 1]))
        bm.faces.new((inner[i][j + 1], inner[k][j + 1], inner[k][j], inner[i][j]))
    bm.faces.new((outer[i][ROWS], outer[k][ROWS], inner[k][ROWS], inner[i][ROWS]))
    bm.faces.new((inner[i][0], inner[k][0], outer[k][0], outer[i][0]))
objs = [C.mesh_object("wall", bm, gold)]

# Rolled rims round the band
objs.append(C.torus("rimLow", gold, radius_at(0.0) + 0.005, 0.045, (0, 0, 0.02)))
objs.append(C.torus("rimHigh", gold, radius_at(BAND_TOP) + 0.005, 0.04, (0, 0, BAND_TOP)))
# A row of little studs between the rims
for i in range(N * 6):
    th = 2 * math.pi * (i + 0.5) / (N * 6)
    if i % 6 in (2, 3):
        continue  # room for the gems
    r = radius_at(0.21) + 0.015
    objs.append(C.sphere("stud%d" % i, gold_dark, 0.028, (r * math.cos(th), r * math.sin(th), 0.21), 10))

for k in range(N):
    th = 2 * math.pi * k / N
    c, s = math.cos(th), math.sin(th)
    # big violet gem on the band under each tall point, in a gold bezel
    r = radius_at(0.21) + 0.03
    objs.append(C.faceted_gem("bandGem%d" % k, violet, 0.13, (r * c, r * s, 0.21), (c, s, 0.05), 0.5, 8))
    bez = C.torus("bezel%d" % k, gold, 0.135, 0.022, (0, 0, 0))
    bez.location = ((r - 0.01) * c, (r - 0.01) * s, 0.21)
    bez.rotation_euler = (0, math.pi / 2, th)
    objs.append(bez)
    # small magenta gem under each small point
    th2 = th + math.pi / N
    c2, s2 = math.cos(th2), math.sin(th2)
    objs.append(C.faceted_gem("smallGem%d" % k, magenta, 0.075, (r * c2, r * s2, 0.21), (c2, s2, 0.05), 0.5, 6))
    # violet teardrop on each tall point, pearl on the tip
    zg = 0.74
    rg = radius_at(zg) + 0.02
    objs.append(C.faceted_gem("pointGem%d" % k, violet, 0.075, (rg * c, rg * s, zg), (c, s, 0.1), 0.55, 6))
    ztip = top_height(th)
    rt = radius_at(ztip) - THICK / 2
    objs.append(C.sphere("pearl%d" % k, pearl, 0.065, (rt * c, rt * s, ztip + 0.05), 16))
    zs = top_height(th2)
    rs = radius_at(zs) - THICK / 2
    objs.append(C.sphere("tipS%d" % k, gold, 0.045, (rs * c2, rs * s2, zs + 0.035), 12))
    # an arch from each tall point to the orb on top, beaded with gold
    pts = []
    z_top = 1.42
    for m in range(25):
        phi = (math.pi / 2) * m / 24
        rr = rt * math.cos(phi) * 0.96
        zz = ztip + 0.08 + (z_top - ztip - 0.08) * math.sin(phi) ** 0.8
        pts.append((rr * c, rr * s, zz))
    objs.append(C.tube_along("arch%d" % k, gold, pts, 0.042))
    for m in (6, 12, 18):
        p = pts[m]
        objs.append(C.sphere("archBead%d_%d" % (k, m), gold_dark, 0.038, p, 10))

# velvet cap inside
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=1.0)
cap = C.mesh_object("cap", bm, velvet)
cap.scale = (0.93, 0.93, 0.78)
cap.location = (0, 0, 0.42)
objs.append(cap)
# the orb on top: a glowing violet sphere on a gold collar
objs.append(C.torus("collar", gold, 0.1, 0.03, (0, 0, 1.43)))
objs.append(C.sphere("orb", orb_mat, 0.13, (0, 0, 1.55), 32))
objs.append(C.sphere("finial", gold, 0.04, (0, 0, 1.71), 12))

root = C.link(bpy.data.objects.new("crown", None))
C.parent_all(root, objs)

# camera: a little above, the crown filling the frame with room for the glow
C.camera((0, -7.6, 3.0), (0, 0, 0.80), lens=92)

for f in range(FRAMES):
    root.rotation_euler = (0, 0, math.radians(72.0 * f / FRAMES))
    C.render_to(os.path.join(OUT, "f%02d.png" % f))
    print("crown frame", f, flush=True)
