#!/usr/bin/env python3
"""Wuber effects: renders every flipbook and sprite in Wuber/Media/fx as 32-bit uncompressed
TGA, plus previews for people (tools/fx_preview.png, tools/fx_portal_open.gif,
tools/fx_crown.gif).

Two kinds of art:
- 3D objects rendered in Blender Cycles (bpy as a Python module): the founder crown, the six
  driver badges and the gold coin (tools/fx/crown_blend.py, tools/fx/badges_blend.py). They
  are drawn in the game with normal ("BLEND") blending, so they get straight alpha, a soft
  bloom halo, specular glints, edge-dilated colour and a 2 px transparent gutter per cell.
- Light (portal, arrival, milestone, the sprite atlas) rendered here with numpy "shaders":
  a spiral vortex with domain-warped noise in log-polar space, glow and bloom by blur
  passes, and particle sparks splatted with motion blur. They are drawn additively ("ADD"),
  so colour and alpha are stored so that colour x alpha is the light added.

    python3 tools/make_fx.py            # everything (runs Blender if its frames are missing)
    python3 tools/make_fx.py --rerender # render the Blender frames again first
    python3 tools/make_fx.py --gold     # the founder gold sheets (*_gold.tga) from the violet ones

Sheets (all power of two, at most 1024 x 1024; cell size includes the gutter):
    crown.tga        512x256   8x4 cells of 64, 32 frames, BLEND (a 72 degree turn: seamless)
    badges.tga       512x512   8x8 cells of 64, 6 badges x 10 frames (row-major), BLEND
    portal_open.tga 1024x512   8x4 cells of 128, 32 frames, ADD (1.6 s at 20 fps)
    portal_loop.tga  512x512   4x4 cells of 128, 16 frames, ADD (seamless loop)
    arrival.tga     1024x512   8x4 cells of 128, 32 frames, ADD
    milestone.tga    512x512   4x4 cells of 128, 16 frames, ADD
    parts.tga        512x256   sprite atlas (see PARTS below), ADD white sprites + BLEND coins
    runes.tga, rays.tga 256x256 each, ADD white (they turn in game)
"""
import math
import os
import struct
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
OUT = os.path.join(ROOT, "Wuber", "Media", "fx")
WORK = "/tmp/fxr"
GUTTER = 2
RNG = np.random.default_rng(20261117)

# the author's colours
NIGHT = (0x0B / 255, 0x0B / 255, 0x16 / 255)
VIOLET = np.array([0x88, 0x3F, 0xDA]) / 255
BRIGHT = np.array([0xCD, 0x7D, 0xF5]) / 255
MAGENTA = np.array([0xE4, 0x67, 0xFC]) / 255
GOLD = np.array([0xF9, 0xC5, 0x3E]) / 255
DEEPGOLD = np.array([0xB1, 0x87, 0x3F]) / 255
DEEP = np.array([0.22, 0.06, 0.48])
HOT = np.array([1.0, 0.86, 1.0])
WHITE = np.array([1.0, 1.0, 1.0])

BADGE_ORDER = ["bolt", "star", "flame", "moon", "crystal", "skull"]

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------


def write_tga(img, path):
    """Uncompressed true-colour TGA, 32 bits, 8 alpha bits, rows stored bottom-up."""
    img = img.convert("RGBA")
    w, h = img.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0 and w <= 1024 and h <= 1024, (path, w, h)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
    px = img.tobytes("raw", "BGRA")
    stride = w * 4
    rows = [px[i * stride:(i + 1) * stride] for i in range(h)]
    rows.reverse()
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


def check_tga(path):
    with open(path, "rb") as f:
        head = f.read(18)
    kind, w, h, bpp = head[2], head[12] + head[13] * 256, head[14] + head[15] * 256, head[16]
    assert kind == 2 and bpp == 32, path
    assert w & (w - 1) == 0 and h & (h - 1) == 0 and w <= 1024 and h <= 1024, path
    assert os.path.getsize(path) == 18 + w * h * 4, path


# ---------------------------------------------------------------------------
# Pixels: premultiplied float RGBA in, game-ready straight RGBA out
# ---------------------------------------------------------------------------


def dilate_rgb(rgb, alpha, steps=6):
    """Spread colour from visible pixels into transparent ones so filtering never pulls a dark
    or white fringe into an edge (the game samples straight alpha)."""
    rgb = rgb.copy()
    known = alpha > 0.004
    for _ in range(steps):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros(alpha.shape)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                k = np.roll(np.roll(known, dy, 0), dx, 1)
                acc += np.roll(np.roll(rgb, dy, 0), dx, 1) * k[..., None]
                cnt += k
        grow = (~known) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][:, None]
        known = known | grow
    if not known.all():
        mean = rgb[known].mean(0) if known.any() else np.array([1.0, 1.0, 1.0])
        rgb[~known] = mean
    return rgb


def emission_to_rgba(E):
    """Additive art: E is light (any brightness). Tone-map it, then store colour normalised
    and the strength in alpha, so colour x alpha = the light the game adds."""
    T = 1.0 - np.exp(-np.maximum(E, 0.0))
    a = T.max(axis=2)
    rgb = np.where(a[..., None] > 1e-4, T / np.maximum(a[..., None], 1e-4), 1.0)
    rgb = dilate_rgb(np.clip(rgb, 0, 1), a)
    return np.dstack([rgb, a])


def straight_from_premult(P):
    a = np.clip(P[..., 3], 0, 1)
    rgb = np.where(a[..., None] > 1e-4, P[..., :3] / np.maximum(a[..., None], 1e-4), 0)
    rgb = dilate_rgb(np.clip(rgb, 0, 1), a)
    return np.dstack([rgb, a])


def to_image(rgba):
    return Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def resize_premult(P, size):
    """Lanczos resize of a premultiplied float RGBA image."""
    out = []
    for c in range(4):
        im = Image.fromarray(P[..., c].astype(np.float32), "F")
        out.append(np.asarray(im.resize((size, size), Image.LANCZOS)))
    return np.clip(np.dstack(out), 0, None)


def pack(frames, cols, rows, cell, gutter=GUTTER):
    """frames: game-ready straight RGBA float arrays of (cell - 2*gutter) px. Returns a sheet
    with transparent gutters whose colour is dilated from each cell's content."""
    W, H = cols * cell, rows * cell
    sheet = np.zeros((H, W, 4))
    for i, fr in enumerate(frames):
        cx, cy = (i % cols) * cell, (i // cols) * cell
        c = fr.shape[0]
        block = np.zeros((cell, cell, 4))
        block[gutter:gutter + c, gutter:gutter + c] = fr
        rgb = dilate_rgb(block[..., :3], block[..., 3], steps=gutter + 2)
        block[..., :3] = rgb
        sheet[cy:cy + cell, cx:cx + cell] = block
    # unused cells: colour from the first frame, fully transparent
    return sheet


# ---------------------------------------------------------------------------
# Noise, blur, splats
# ---------------------------------------------------------------------------


def tile_noise(n, beta, seed):
    """Tileable fractal noise (periodic in both directions), 0..1."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1.0
    amp = k ** (-beta)
    amp[0, 0] = 0.0
    spec = amp * np.exp(2j * np.pi * rng.random((n, n)))
    img = np.real(np.fft.ifft2(spec))
    img -= img.min()
    return img / img.max()


NOISE_A = tile_noise(256, 1.6, 1)
NOISE_B = tile_noise(256, 1.9, 2)
NOISE_C = tile_noise(256, 1.3, 3)


def sample(tex, u, v):
    """Bilinear, wrapping, u and v in texture periods (1.0 = one tile)."""
    n = tex.shape[0]
    return ndimage.map_coordinates(tex, [np.mod(v * n, n), np.mod(u * n, n)], order=1, mode="grid-wrap")


def blur(E, sigma):
    return np.dstack([ndimage.gaussian_filter(E[..., c], sigma, mode="constant") for c in range(E.shape[2])])


def bloom(E, px, weights=((0.012, 0.55), (0.04, 0.35), (0.1, 0.22))):
    out = E.copy()
    for s, w in weights:
        out += w * blur(E, max(0.6, s * px))
    return out


def grid(px):
    c = (np.arange(px) + 0.5) / px * 2 - 1
    x, y = np.meshgrid(c, -c)
    return x, y


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def splat(E, px, x, y, size, color, strength, shape="dot", ang=0.0):
    """Adds a soft spot of light at (x, y) in -1..1 coordinates."""
    cx = (x + 1) / 2 * px
    cy = (1 - y) / 2 * px
    s = max(0.6, size * px / 2)
    rad = int(math.ceil(s * (6 if shape == "star" else 3))) + 1
    x0, x1 = max(0, int(cx) - rad), min(px, int(cx) + rad + 1)
    y0, y1 = max(0, int(cy) - rad), min(px, int(cy) + rad + 1)
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
    if shape == "star":
        c, s_ = math.cos(ang), math.sin(ang)
        u, v = (dx * c + dy * s_) / s, (-dx * s_ + dy * c) / s
        k = np.exp(-(u * u + v * v) * 1.5) + 0.8 * (np.exp(-np.abs(u) * 0.7 - v * v * 6) + np.exp(-np.abs(v) * 0.7 - u * u * 6))
    else:
        k = np.exp(-(dx * dx + dy * dy) / (2 * s * s))
    E[y0:y1, x0:x1] += k[..., None] * (np.asarray(color) * strength)


def streak(E, px, xa, ya, xb, yb, size, color, strength, n=None):
    """Motion blur: a spark moving from a to b during the frame."""
    if n is None:
        dist = math.hypot(xb - xa, yb - ya) * px / 2
        n = int(min(40, max(3, dist / max(0.7, size * px / 2 * 0.8))))
    for i in range(n):
        t = i / max(1, n - 1)
        splat(E, px, xa + (xb - xa) * t, ya + (yb - ya) * t, size, color, strength / n * (0.4 + 1.2 * t))


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None] if np.ndim(t) else min(1.0, max(0.0, t))
    return a * (1 - t) + b * t


def ease_out_back(t, k=1.7):
    t = min(1.0, max(0.0, t)) - 1
    return 1 + (k + 1) * t ** 3 + k * t ** 2


# ---------------------------------------------------------------------------
# The vortex: the author's swirling portal
# ---------------------------------------------------------------------------

LOOP_FRAMES, FPS = 16, 20.0
LOOP_T = LOOP_FRAMES / FPS
ARM_SPEED = (2 * math.pi / 3) / LOOP_T  # three arms: a 120 degree turn per loop = seamless


def vortex_layers(x, y, tau, R, spin_boost=0.0):
    """Returns light E (h, w, 3) of the vortex disc of radius R at time tau (seconds)."""
    r = np.hypot(x, y) + 1e-6
    th = np.arctan2(y, x)
    lr = np.log(r + 0.04)
    # spiral arms: rigid rotation (seamless over the loop), twisted in log-radius
    arm_rot = ARM_SPEED * tau + spin_boost
    alpha = th + arm_rot + 2.4 * lr
    # domain warp: the noise pushes the arms around
    warp = sample(NOISE_C, alpha / (2 * math.pi) * 2, lr * 0.35 - tau * 0.18) - 0.5
    arms = 0.5 + 0.5 * np.cos(3 * alpha + 3.2 * warp)
    arms = arms ** 2.2
    # turbulent filaments flowing inwards (log-polar noise, periodic in angle)
    def flow(t):
        a = (th + 2.4 * lr + ARM_SPEED * 1.35 * t) / (2 * math.pi)
        b = lr * 0.55 + t * 0.55
        n1 = sample(NOISE_A, a * 3, b + 0.3 * warp)
        n2 = sample(NOISE_B, a * 5 + 0.2 * n1, b * 1.7)
        return n1 * 0.65 + n2 * 0.55
    # loop-friendly cross fade of the flowing noise
    ph = (tau % LOOP_T) / LOOP_T
    base = tau - ph * LOOP_T
    fil = flow(base + ph * LOOP_T) * (1 - ph) + flow(base + ph * LOOP_T - LOOP_T) * ph
    fil = np.clip((fil - 0.45) * 1.9, 0, None)
    rn = r / max(R, 1e-3)
    disc = 1 - smoothstep(0.82, 1.0, rn)
    depth = smoothstep(0.0, 0.55, rn)  # the eye is calmer, the outside busier
    I = disc * (0.05 + 0.85 * arms * (0.3 + 0.7 * depth) + 1.1 * fil * arms * depth + 0.12 * fil)
    # colour by radius: hot white-pink eye, magenta, violet, deep violet edge
    c = np.where((rn < 0.3)[..., None], mix(HOT, MAGENTA * 1.1, rn / 0.3),
                 np.where((rn < 0.65)[..., None], mix(MAGENTA * 1.1, VIOLET * 1.2, (rn - 0.3) / 0.35),
                          mix(VIOLET * 1.2, DEEP, (rn - 0.65) / 0.35)))
    E = c * I[..., None] * 0.95
    # the bright rim and the eye
    rim = np.exp(-((r - R * 0.97) / (0.035 + 0.02 * R)) ** 2) * (0.75 + 0.5 * arms)
    E += rim[..., None] * (MAGENTA * 0.7 + VIOLET * 0.3) * 1.0
    eye = np.exp(-(r / (0.08 * max(R, 0.05) / 0.62)) ** 2) * 1.8 * min(1.0, R / 0.3)
    E += eye[..., None] * HOT
    # stars caught in the swirl (fixed in the rotating frame, twinkling)
    return E


SWIRL_STARS = [(RNG.uniform(0.08, 0.95), RNG.uniform(0, 2 * math.pi), RNG.uniform(0, 6.28)) for _ in range(26)]


def swirl_stars(E, px, tau, R, fade=1.0):
    for rr, a0, ph in SWIRL_STARS:
        rad = rr * R
        ang = a0 + ARM_SPEED * tau * (1.0 + 0.25 / max(rr, 0.2)) * 0  # rigid: keep the loop seamless
        ang = a0 + ARM_SPEED * tau
        tw = 0.5 + 0.5 * math.sin(ph + tau * 2 * math.pi / LOOP_T * 2)
        splat(E, px, rad * math.cos(ang), rad * math.sin(ang), 0.012, WHITE, 0.9 * tw * fade)


def render_portal_frame(px, tau, R, extra=None, spin_boost=0.0, glow=1.0):
    x, y = grid(px)
    E = vortex_layers(x, y, tau, R, spin_boost) if R > 0.004 else np.zeros((px, px, 3))
    if R > 0.004:
        swirl_stars(E, px, tau, R)
    if extra:
        extra(E, px, x, y)
    E = bloom(E, px)
    # a soft outer aura
    r = np.hypot(x, y)
    E += (np.exp(-(r / (R * 1.35 + 0.05)) ** 2) * 0.35 * glow * min(1.0, R / 0.62))[..., None] * VIOLET
    return E


def portal_loop(px):
    return [render_portal_frame(px, i / FPS, 0.62) for i in range(LOOP_FRAMES)]


OPEN_FRAMES = 32
OPEN_T = OPEN_FRAMES / FPS  # 1.6 s; 240 degrees of arm turn = two loops, so it flows into the loop


def make_converge_sparks(n=44):
    out = []
    for i in range(n):
        a = RNG.uniform(0, 2 * math.pi)
        out.append(dict(a=a, r0=RNG.uniform(0.75, 0.98), t0=RNG.uniform(0.0, 0.18), dur=RNG.uniform(0.32, 0.5),
                        col=GOLD if i % 4 == 0 else (MAGENTA if i % 3 else BRIGHT), size=RNG.uniform(0.008, 0.016)))
    return out


def make_burst(n, speed=(0.7, 1.7), cols=(GOLD, BRIGHT, MAGENTA), drag=2.2, up=0.0, life=(0.6, 1.1)):
    out = []
    for i in range(n):
        a = RNG.uniform(0, 2 * math.pi)
        out.append(dict(a=a, v=RNG.uniform(*speed), col=cols[i % len(cols)], size=RNG.uniform(0.007, 0.018),
                        life=RNG.uniform(*life), drag=drag, up=up, tw=RNG.uniform(0, 6.28)))
    return out


def burst_pos(p, t):
    """distance travelled with drag: v (1 - e^-kt) / k, plus a drift up"""
    k = p["drag"]
    d = p["v"] * (1 - math.exp(-k * t)) / k
    return d * math.cos(p["a"]), d * math.sin(p["a"]) + p["up"] * t * t


def draw_burst(E, px, parts, t, t0, strength=1.0, dt=1 / FPS):
    for p in parts:
        lt = t - t0
        if lt <= 0 or lt > p["life"]:
            continue
        fade = (1 - lt / p["life"]) ** 1.3
        xa, ya = burst_pos(p, max(0.0, lt - dt))
        xb, yb = burst_pos(p, lt)
        tw = 0.7 + 0.3 * math.sin(p["tw"] + lt * 25)
        streak(E, px, xa, ya, xb, yb, p["size"], p["col"], 1.4 * fade * tw * strength)


CONVERGE = make_converge_sparks()
OPEN_BURST = make_burst(40, speed=(0.9, 1.9), drag=3.0)


def portal_open(px):
    frames = []
    for f in range(OPEN_FRAMES):
        t = f / FPS
        tau = t - OPEN_T  # ends at tau = 0: the loop's first frame
        R = 0.62 * ease_out_back((t - 0.22) / 0.55, 2.2) if t > 0.22 else 0.0
        R = max(0.0, R) * (1 + 0.03 * math.sin(t * 9) * max(0, 1 - t / OPEN_T))

        def extra(E, px, x, y, t=t):
            # the spark of the ritual: a point of light that swells
            r = np.hypot(x, y)
            ign = smoothstep(0.0, 0.25, t) * (1 - smoothstep(0.35, 0.8, t))
            E += (np.exp(-(r / (0.04 + 0.12 * ign)) ** 2) * 2.8 * ign)[..., None] * HOT
            # flash when the portal tears open
            fl = math.exp(-((t - 0.32) / 0.08) ** 2)
            E += (np.exp(-(r / 0.35) ** 2) * 1.6 * fl)[..., None] * (HOT * 0.6 + MAGENTA * 0.4)
            # sparks spiralling in
            for p in CONVERGE:
                u0 = (t - 1 / FPS - p["t0"]) / p["dur"]
                u1 = (t - p["t0"]) / p["dur"]
                if u1 <= 0 or u0 >= 1:
                    continue
                pts = []
                for u in (max(0, u0), min(1, u1)):
                    rr = p["r0"] * (1 - u) ** 1.4
                    aa = p["a"] + 2.6 * u
                    pts.append((rr * math.cos(aa), rr * math.sin(aa)))
                streak(E, px, pts[0][0], pts[0][1], pts[1][0], pts[1][1], p["size"], p["col"], 1.6 * min(1, u1 * 3))
            draw_burst(E, px, OPEN_BURST, t, 0.3)

        frames.append(render_portal_frame(px, tau, R, extra, glow=1.0))
    return frames


ARRIVAL_FRAMES = 32
ARR_BURST = make_burst(70, speed=(0.8, 2.3), cols=(GOLD, GOLD, BRIGHT, MAGENTA, WHITE), drag=2.6, up=0.25, life=(0.7, 1.25))


def arrival(px):
    frames = []
    for f in range(ARRIVAL_FRAMES):
        t = f / FPS
        col_t = min(1.0, t / 0.34)
        R = 0.62 * (1 - col_t ** 2.2)
        spin = 2.5 * col_t ** 2  # spins up as it collapses

        def extra(E, px, x, y, t=t):
            r = np.hypot(x, y)
            fl = math.exp(-((t - 0.34) / 0.07) ** 2) + 0.5 * math.exp(-max(0, t - 0.34) / 0.25) * (t > 0.34)
            E += (np.exp(-(r / (0.06 + 0.16 * fl)) ** 2) * 2.4 * fl)[..., None] * (WHITE * 0.5 + GOLD * 0.5)
            # shock wave: gold at first, violet as it fades
            if t > 0.32:
                u = (t - 0.32) / 0.7
                if u < 1:
                    rad = 0.08 + 0.88 * (1 - (1 - u) ** 2.4)
                    w = 0.05 * (1 - u) + 0.012
                    ring = np.exp(-((r - rad) / w) ** 2) * (1 - u) ** 1.2 * 1.8
                    E += ring[..., None] * mix(GOLD, BRIGHT, u)
                    # a second, thinner violet ring a beat later
                    u2 = (t - 0.42) / 0.7
                    if 0 < u2 < 1:
                        rad2 = 0.05 + 0.8 * (1 - (1 - u2) ** 2.2)
                        ring2 = np.exp(-((r - rad2) / 0.02) ** 2) * (1 - u2) * 1.1
                        E += ring2[..., None] * MAGENTA
            draw_burst(E, px, ARR_BURST, t, 0.33, 1.3)

        tau = t - OPEN_T  # carries on from wherever the loop was: any phase looks right
        frames.append(render_portal_frame(px, tau, R, extra, spin_boost=spin, glow=1 - col_t))
    return frames


MILESTONE_FRAMES = 16
MS_STARS = make_burst(16, speed=(1.0, 1.6), cols=(GOLD, WHITE, GOLD), drag=2.8, up=0.0, life=(0.7, 0.8))
MS_RAYS = [(RNG.uniform(0, 2 * math.pi), RNG.uniform(0.5, 1.0)) for _ in range(14)]


def milestone(px):
    frames = []
    x, y = grid(px)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    for f in range(MILESTONE_FRAMES):
        t = f / FPS
        u = t / (MILESTONE_FRAMES / FPS)
        E = np.zeros((px, px, 3))
        # flash
        fl = math.exp(-((t - 0.05) / 0.09) ** 2)
        E += (np.exp(-(r / 0.3) ** 2) * 2.4 * fl)[..., None] * (WHITE * 0.4 + GOLD * 0.6)
        # gold ring burst, double
        rad = 0.15 + 0.7 * (1 - (1 - u) ** 2.5)
        E += (np.exp(-((r - rad) / (0.06 * (1 - u) + 0.015)) ** 2) * (1 - u) ** 0.8 * 2.0)[..., None] * GOLD
        rad2 = 0.1 + 0.55 * (1 - (1 - u) ** 2)
        E += (np.exp(-((r - rad2) / 0.018) ** 2) * (1 - u) * 1.0)[..., None] * (GOLD * 0.5 + WHITE * 0.5)
        # rays
        rays = np.zeros_like(r)
        for a, w in MS_RAYS:
            d = np.angle(np.exp(1j * (th - a - 0.3 * u)))
            rays += w * np.exp(-(d / 0.05) ** 2)
        E += (rays * np.exp(-r / 0.55) * (r > 0.05) * (1 - u) * 1.1)[..., None] * GOLD
        # star glints flying out
        for p in MS_STARS:
            lt = t - 0.02
            if lt <= 0 or lt > p["life"]:
                continue
            xb, yb = burst_pos(p, lt)
            fade = (1 - lt / p["life"]) ** 0.9
            splat(E, px, xb, yb, 0.02, p["col"], 1.3 * fade, shape="star", ang=0.0)
        frames.append(bloom(E, px))
    return frames


# ---------------------------------------------------------------------------
# Sprite atlas (white light sprites, tinted in game, plus the coin's frames)
# ---------------------------------------------------------------------------

# name: (x, y, w, h) in pixels of parts.tga (512x256). The Lua side mirrors this table.
# The rune ring and the rays turn in game, so they are files of their own (runes.tga,
# rays.tga, 256x256): turning a texture's corners outside 0..1 must find transparent edges.
PARTS = {
    "glow": (0, 0, 128, 128),
    "ring": (128, 0, 128, 128),
    "flare": (256, 0, 128, 128),
    "star": (384, 0, 128, 128),
    "spark": (0, 128, 64, 64),
    "mote": (64, 128, 64, 64),
    "streak": (128, 128, 64, 64),
    "twinkle": (192, 128, 64, 64),
    # coin frames: (64 * i, 192, 64, 64) for i = 0..7
}


def rune_glyph(d, x0, y0, w, h, rng):
    """A made-up rune: a stem and two or three strokes between grid points."""
    pts = [(x0 + w * i / 2, y0 + h * j / 3) for i in range(3) for j in range(4)]
    lw = max(2, int(w * 0.16))
    stem = rng.integers(0, 3)
    d.line([pts[stem * 4], pts[stem * 4 + 3]], fill=255, width=lw)
    for _ in range(rng.integers(2, 4)):
        a, b = rng.choice(len(pts), 2, replace=False)
        d.line([pts[a], pts[b]], fill=255, width=lw)


def make_runes(size=256, ss=4):
    S = size * ss
    rng = np.random.default_rng(7)
    r_out, r_in = 0.97, 0.80
    circ = int(2 * math.pi * (r_out + r_in) / 2 * S / 2)
    band_h = int((r_out - r_in) * S / 2)
    strip = Image.new("L", (circ, band_h), 0)
    d = ImageDraw.Draw(strip)
    gw, gap = int(band_h * 0.42), int(band_h * 0.22)
    xg = gap
    while xg + gw < circ - gap:
        if rng.random() < 0.12:
            d.ellipse((xg + gw * 0.3, band_h * 0.4, xg + gw * 0.7, band_h * 0.6), fill=255)
            xg += gw // 2 + gap
            continue
        rune_glyph(d, xg, band_h * 0.2, gw, band_h * 0.6, rng)
        xg += gw + gap
    a = np.asarray(strip).astype(float) / 255
    c = (np.arange(S) + 0.5) / S * 2 - 1
    X, Y = np.meshgrid(c, -c)
    R = np.hypot(X, Y)
    TH = (np.arctan2(Y, X) % (2 * math.pi)) / (2 * math.pi)
    col = TH * circ
    row = (r_out - R) / (r_out - r_in) * band_h
    glyphs = ndimage.map_coordinates(a, [row, col], order=1, mode="constant", cval=0)
    glyphs *= (R > r_in) & (R < r_out)
    lines = np.exp(-((R - 0.995 * r_out - 0.01) / 0.006) ** 2) + np.exp(-((R - r_in + 0.012) / 0.005) ** 2)
    inner = np.exp(-((R - 0.70) / 0.004) ** 2) * 0.7
    # tick marks on the inner circle
    ticks = (np.abs(np.sin(TH * math.pi * 72)) < 0.12) * ((R > 0.715) & (R < 0.76)) * 0.8
    I = np.clip(glyphs + lines + inner + ticks, 0, 1)
    img = Image.fromarray(I.astype(np.float32), "F").resize((size, size), Image.LANCZOS)
    I = np.clip(np.asarray(img), 0, 1)
    I = np.clip(I + 0.6 * ndimage.gaussian_filter(I, 2.5), 0, 1)  # a little glow
    return I


def make_rays(size=256):
    x, y = grid(size)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    rng = np.random.default_rng(11)
    I = np.zeros_like(r)
    for _ in range(22):
        a = rng.uniform(0, 2 * math.pi)
        w = rng.uniform(0.02, 0.07)
        s = rng.uniform(0.4, 1.0)
        d = np.angle(np.exp(1j * (th - a)))
        I += s * np.exp(-(d / w) ** 2)
    I = I * np.clip(1 - r, 0, 1) ** 1.6 * smoothstep(0.0, 0.12, r) + np.exp(-(r / 0.12) ** 2) * 0.6
    return np.clip(I / I.max() * 1.2, 0, 1)


def sprite(size, fn):
    x, y = grid(size)
    return np.clip(fn(x, y, np.hypot(x, y)), 0, 1)


def white_rgba(I):
    I = np.asarray(I, dtype=float)
    return np.dstack([np.ones_like(I), np.ones_like(I), np.ones_like(I), I])


def star_shape(x, y, r):
    cross = np.exp(-np.abs(x) * 5.5 - (y / 0.035) ** 2) + np.exp(-np.abs(y) * 5.5 - (x / 0.035) ** 2)
    u, v = (x + y) / math.sqrt(2), (x - y) / math.sqrt(2)
    diag = 0.35 * (np.exp(-np.abs(u) * 9 - (v / 0.03) ** 2) + np.exp(-np.abs(v) * 9 - (u / 0.03) ** 2))
    return cross + diag + np.exp(-(r / 0.09) ** 2) + 0.25 * np.exp(-(r / 0.35) ** 2)


def twinkle_shape(x, y, r):
    th = np.arctan2(y, x)
    spikes = np.exp(-r * 3.5) * (0.5 + 0.5 * np.cos(6 * th)) ** 8
    return spikes * 1.3 + np.exp(-(r / 0.12) ** 2) + 0.2 * np.exp(-(r / 0.4) ** 2)


def parts_atlas(coin_frames):
    A = np.zeros((256, 512, 4))
    A[..., :3] = 1.0

    def put(name, I):
        x0, y0, w, h = PARTS[name]
        g = GUTTER
        A[y0 + g:y0 + h - g, x0 + g:x0 + w - g] = white_rgba(I)

    def fit(size, fn):
        return sprite(size - 2 * GUTTER, fn)

    put("glow", fit(128, lambda x, y, r: np.exp(-(r / 0.42) ** 2) * (1 - smoothstep(0.85, 1.0, r))))
    put("ring", fit(128, lambda x, y, r: np.exp(-((r - 0.78) / 0.05) ** 2) + 0.25 * np.exp(-((r - 0.78) / 0.16) ** 2)))
    put("flare", fit(128, lambda x, y, r: (np.exp(-(y / 0.035) ** 2) * np.exp(-np.abs(x) / 0.3) + np.exp(-(r / 0.12) ** 2) * 0.8
                     + 0.25 * np.exp(-(y / 0.12) ** 2) * np.exp(-np.abs(x) / 0.15)) * (1 - smoothstep(0.8, 1.0, np.abs(x)))))
    put("star", fit(128, lambda x, y, r: star_shape(x, y, r) * (1 - smoothstep(0.85, 1.0, np.maximum(np.abs(x), np.abs(y))))))
    put("spark", fit(64, lambda x, y, r: np.exp(-(r / 0.13) ** 2) + 0.45 * np.exp(-(r / 0.4) ** 2)))
    put("mote", fit(64, lambda x, y, r: np.exp(-(r / 0.5) ** 2) * (1 - smoothstep(0.85, 1, r))))
    put("streak", fit(64, lambda x, y, r: np.exp(-(x / 0.09) ** 2) * np.clip((y + 0.9) / 1.6, 0, 1) ** 1.5 * (1 - smoothstep(0.75, 0.95, y))
                      + np.exp(-((x / 0.14) ** 2 + ((y - 0.68) / 0.14) ** 2))))
    put("twinkle", fit(64, lambda x, y, r: twinkle_shape(x, y, r) * (1 - smoothstep(0.85, 1.0, r))))
    for i, fr in enumerate(coin_frames[:8]):
        g = GUTTER
        c = fr.shape[0]
        A[192 + g:192 + g + c, 64 * i + g:64 * i + g + c] = fr
    # gutters and empty cells: colour spread from the art, alpha 0
    A[..., :3] = dilate_rgb(A[..., :3], A[..., 3], steps=4)
    return A


def lone_sprite(I):
    """A 256 sprite of its own with a transparent border (it turns in game)."""
    S = I.shape[0] + 2 * GUTTER
    out = np.zeros((S, S, 4))
    out[..., :3] = 1.0
    out[GUTTER:-GUTTER, GUTTER:-GUTTER, 3] = I
    return out


# ---------------------------------------------------------------------------
# Blender objects: crown, badges, coin
# ---------------------------------------------------------------------------


def blender(script, *args):
    cmd = [sys.executable, os.path.join(HERE, "fx", script)] + [str(a) for a in args]
    print("  blender:", " ".join(cmd[1:]), flush=True)
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)


def load_premult(path):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float) / 255
    a[..., :3] *= a[..., 3:4]
    return a


def object_frame(path, content, glow_col, halo=0.55, glints=2, glint_col=(1.0, 0.97, 0.88)):
    """A Cycles render -> a game frame: downsampled, bloom halo behind, a few specular
    glints on the brightest highlights, straight alpha with dilated colour."""
    P = load_premult(path)
    P = resize_premult(P, content)
    a = P[..., 3]
    lum = (P[..., 0] * 0.3 + P[..., 1] * 0.55 + P[..., 2] * 0.15)
    # bloom from the bright parts, in their own colour, placed behind the object
    bright = np.clip(lum - 0.62, 0, None)[..., None] * (P[..., :3] / np.maximum(a[..., None], 1e-3))
    g = 0.9 * blur(bright, 1.2) + 0.7 * blur(bright, 3.0)
    # an even soft halo in the effect colour round the silhouette
    sil = ndimage.gaussian_filter(a, 2.6)
    g += sil[..., None] * np.asarray(glow_col) * halo * 0.6
    g_a = np.clip(g.max(axis=2), 0, 0.85)
    G = np.dstack([np.clip(g, 0, 1) * 1.0, g_a])
    G[..., :3] = np.where(g_a[..., None] > 0, np.clip(g / np.maximum(g_a[..., None], 1e-3), 0, 1) * g_a[..., None], 0)
    out = P + G * (1 - a[..., None])
    # specular glints: small four-point stars on the brightest highlights
    if glints:
        L = lum * (a > 0.6)
        mx = ndimage.maximum_filter(L, size=9)
        peaks = np.argwhere((L == mx) & (L > 0.86))
        order = np.argsort(-L[peaks[:, 0], peaks[:, 1]]) if len(peaks) else []
        E = np.zeros((content, content, 3))
        for k in list(order)[:glints]:
            py, px_ = peaks[k]
            s = (L[py, px_] - 0.86) / 0.14
            x = (px_ + 0.5) / content * 2 - 1
            y = 1 - (py + 0.5) / content * 2
            splat(E, content, x, y, 0.035, np.asarray(glint_col), 0.9 * (0.4 + 0.6 * s), shape="star", ang=0.0)
        ea = np.clip(E.max(axis=2), 0, 1)
        # screen the glint over: premultiplied add, alpha union
        out[..., :3] = out[..., :3] + np.clip(E, 0, 1) * (1 - out[..., :3])
        out[..., 3] = np.maximum(out[..., 3], ea)
    return straight_from_premult(np.clip(out, 0, 1))


def crown_frames(content):
    d = os.path.join(WORK, "crown")
    return [object_frame(os.path.join(d, "f%02d.png" % i), content, BRIGHT, halo=0.7, glints=2) for i in range(32)]


def badge_frames(bid, content):
    d = os.path.join(WORK, "badges", bid)
    return [object_frame(os.path.join(d, "f%02d.png" % i), content, BRIGHT * 0.6 + GOLD * 0.4, halo=0.45, glints=1)
            for i in range(10)]


def coin_frames(content):
    d = os.path.join(WORK, "badges", "coin")
    return [object_frame(os.path.join(d, "f%02d.png" % i), content, GOLD, halo=0.35, glints=1) for i in range(8)]


# ---------------------------------------------------------------------------
# Previews for people
# ---------------------------------------------------------------------------


def over_night(rgba, mode, bg=None):
    """Composite a game-ready frame the way the game draws it, over the author's night colour."""
    h, w = rgba.shape[:2]
    base = np.zeros((h, w, 3)) + np.asarray(NIGHT) if bg is None else bg.copy()
    rgb, a = rgba[..., :3], rgba[..., 3:4]
    if mode == "ADD":
        return np.clip(base + rgb * a, 0, 1)
    return base * (1 - a) + rgb * a


def cells(sheet_rgba, cols, cell, first, count):
    out = []
    for i in range(first, first + count):
        cx, cy = (i % cols) * cell, (i // cols) * cell
        out.append(sheet_rgba[cy:cy + cell, cx:cx + cell])
    return out


def label(img, text, xy):
    d = ImageDraw.Draw(img)
    d.text(xy, text, fill=(242, 238, 255, 255))


def previews(sheets):
    rows = [
        ("portal_open (ADD, 32 frames, 1.6 s)", "portal_open", "ADD", [0, 4, 7, 10, 14, 20, 26, 31], 128),
        ("portal_loop (ADD, 16-frame seamless loop)", "portal_loop", "ADD", [0, 2, 4, 6, 8, 10, 12, 14], 128),
        ("arrival (ADD, 32 frames)", "arrival", "ADD", [0, 4, 6, 7, 9, 12, 18, 26], 128),
        ("milestone (ADD, 16 frames)", "milestone", "ADD", [0, 1, 2, 4, 6, 8, 11, 15], 128),
        ("crown (BLEND, 32-frame seamless spin; 2x)", "crown", "BLEND", [0, 4, 8, 12, 16, 20, 24, 28], 64),
    ]
    scale_for = {128: 1, 64: 2}
    W = 8 * 132 + 20
    H = 30 + len(rows) * 160 + 2 * 86 + 40 + 400
    img = Image.new("RGB", (W, H), tuple(int(c * 255) for c in NIGHT))
    yy = 10
    for title, name, mode, idx, cell in rows:
        sheet, cols = sheets[name]
        label(img, title, (10, yy))
        for k, i in enumerate(idx):
            c = cells(sheet, cols, cell, i, 1)[0]
            fr = to_image(np.dstack([over_night(c, mode), np.ones(c.shape[:2])])).convert("RGB")
            s = scale_for[cell]
            fr = fr.resize((cell * s, cell * s), Image.LANCZOS)
            img.paste(fr, (10 + k * 132, yy + 16))
        yy += 160
    sheet, cols = sheets["badges"]
    label(img, "driver badges (BLEND, 10 frames each; 1.25x): " + ", ".join(BADGE_ORDER), (10, yy))
    for b in range(6):
        for k, f in enumerate([0, 2, 4, 5, 7]):
            c = cells(sheet, 8, 64, b * 10 + f, 1)[0]
            fr = to_image(np.dstack([over_night(c, "BLEND"), np.ones(c.shape[:2])])).convert("RGB").resize((80, 80), Image.LANCZOS)
            img.paste(fr, (10 + (b % 3) * 360 + k * 70, yy + 16 + (b // 3) * 86))
    yy += 16 + 2 * 86 + 10
    label(img, "sprites: parts.tga (tinted in game; coins BLEND), runes.tga, rays.tga", (10, yy))
    A = sheets["parts"][0]
    show = A.copy()
    tint = np.ones((256, 512, 3))
    tint[:128, :128] = VIOLET
    tint[:128, 128:256] = MAGENTA
    tint[:128, 256:384] = BRIGHT
    tint[:128, 384:] = GOLD
    tint[128:192] = GOLD
    show[..., :3] = show[..., :3] * tint
    rows_ = np.arange(256)[:, None, None]
    pa = np.where(rows_ < 192, over_night(show, "ADD"), over_night(show, "BLEND"))
    img.paste(to_image(np.dstack([pa, np.ones((256, 512))])).convert("RGB").resize((360, 180), Image.LANCZOS), (10, yy + 16))
    for k, (nm, col) in enumerate((("runes", BRIGHT), ("rays", GOLD))):
        R_ = sheets[nm][0].copy()
        R_[..., :3] *= col
        im = to_image(np.dstack([over_night(R_, "ADD"), np.ones(R_.shape[:2])])).convert("RGB").resize((170, 170), Image.LANCZOS)
        img.paste(im, (10 + k * 185, yy + 200))
    # a mock nameplate with the crown composite, as the game builds it
    mock = nameplate_mock(sheets)
    img.paste(mock, (400, yy + 16))
    label(img, "in game: crown over a nameplate (glow + flipbook)", (400, yy + 4 + mock.size[1] + 16))
    path = os.path.join(HERE, "fx_preview.png")
    img.save(path, optimize=True)
    return path


def nameplate_mock(sheets, frame=6, big=3):
    W, H = 220, 180
    base = np.zeros((H, W, 3)) + np.array([0.20, 0.24, 0.28])
    base[:, :] = np.linspace(0.32, 0.12, H)[:, None, None] * np.array([0.7, 0.8, 1.0])
    img = base.copy()
    sheet, cols = sheets["crown"]
    c = cells(sheet, cols, 64, frame, 1)[0]
    c = np.asarray(to_image(c).resize((64 * 2, 64 * 2), Image.LANCZOS)).astype(float) / 255
    A = sheets["parts"][0]
    glow = A[0:128, 0:128]
    gl = np.asarray(to_image(glow).resize((150, 150), Image.LANCZOS)).astype(float) / 255
    x0, y0 = (W - 150) // 2, 5
    sub = img[y0:y0 + 150, x0:x0 + 150]
    img[y0:y0 + 150, x0:x0 + 150] = np.clip(sub + gl[..., :3] * BRIGHT * gl[..., 3:4] * 0.5, 0, 1)
    x0, y0 = (W - 128) // 2, 16
    sub = img[y0:y0 + 128, x0:x0 + 128]
    img[y0:y0 + 128, x0:x0 + 128] = sub * (1 - c[..., 3:4]) + c[..., :3] * c[..., 3:4]
    out = Image.fromarray((img * 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(out)
    d.rectangle((50, 150, 170, 160), fill=(40, 160, 40), outline=(0, 0, 0))
    d.text((70, 136), "Anita Lift", fill=(120, 255, 120))
    return out


def gifs(sheets):
    out = []
    # portal_open into three passes of the loop, on the night colour, 2x
    so, co = sheets["portal_open"]
    sl, cl = sheets["portal_loop"]
    frames = [c for c in cells(so, co, 128, 0, 32)] + [c for c in cells(sl, cl, 128, 0, 16)] * 3
    ims = [to_image(np.dstack([over_night(c, "ADD"), np.ones(c.shape[:2])])).convert("RGB").resize((256, 256), Image.LANCZOS)
           for c in frames]
    p = os.path.join(HERE, "fx_portal_open.gif")
    ims[0].save(p, save_all=True, append_images=ims[1:], duration=50, loop=0, optimize=True)
    out.append(p)
    # the crown, 3x, two full turns' worth of loops
    sc, cc = sheets["crown"]
    frames = cells(sc, cc, 64, 0, 32) * 3
    ims = [to_image(np.dstack([over_night(c, "BLEND"), np.ones(c.shape[:2])])).convert("RGB").resize((192, 192), Image.LANCZOS)
           for c in frames]
    p = os.path.join(HERE, "fx_crown.gif")
    ims[0].save(p, save_all=True, append_images=ims[1:], duration=50, loop=0, optimize=True)
    out.append(p)
    # arrival
    sa, ca = sheets["arrival"]
    ims = [to_image(np.dstack([over_night(c, "ADD"), np.ones(c.shape[:2])])).convert("RGB").resize((256, 256), Image.LANCZOS)
           for c in cells(sa, ca, 128, 0, 32)]
    p = os.path.join(HERE, "fx_arrival.gif")
    ims[0].save(p, save_all=True, append_images=ims[1:] + [ims[-1]] * 6, duration=50, loop=0, optimize=True)
    out.append(p)
    return out


# ---------------------------------------------------------------------------


def edge_fade(E):
    """Everything fades out before the cell's edge: no square corners on screen."""
    x, y = grid(E.shape[0])
    return E * (1 - smoothstep(0.84, 0.99, np.hypot(x, y)))[..., None]


def light_sheet(frames_E, cols, rows, cell, ss):
    content = cell - 2 * GUTTER
    out = []
    for E in frames_E:
        E = edge_fade(E)
        rgba = emission_to_rgba(E)
        # downsample in premultiplied form, then back to straight
        P = rgba.copy()
        P[..., :3] *= P[..., 3:4]
        P = resize_premult(P, content)
        out.append(straight_from_premult(P))
    return pack(out, cols, rows, cell)


# ---------------------------------------------------------------------------
# Founder gold (SPEC7 5.13): the violet portal sheets, recoloured offline
# ---------------------------------------------------------------------------

GOLD_RAMP = [(0.0, DEEPGOLD), (0.55, GOLD), (1.0, np.array([0xFF, 0xD8, 0x66]) / 255)]
GOLD_SHEETS = [("portal_open", "portal_open_gold"), ("portal_loop", "portal_loop_gold"),
               ("arrival", "arrival_gold"), ("runes", "runes_gold")]


def read_tga_rgba(path):
    im = Image.open(path)
    im.load()
    return np.asarray(im.convert("RGBA"), dtype=np.float64) / 255.0


def gold_recolour(rgba):
    """Desaturate (luminance), then map luminance onto the gold ramp. Alpha is untouched, so the
    sheet keeps its frames, gutters and soft edges; near-black stays dark so the ADD blend adds
    nothing where the violet one added nothing."""
    rgb, a = rgba[..., :3], rgba[..., 3]
    lum = np.clip(rgb @ np.array([0.2126, 0.7152, 0.0722]), 0, 1)
    # the violet art is dim in its body and white-hot in its eye: stretch so the body reads gold
    t = np.clip(lum / 0.85, 0, 1) ** 0.8
    out = np.zeros_like(rgb)
    for (t0, c0), (t1, c1) in zip(GOLD_RAMP, GOLD_RAMP[1:]):
        m = (t >= t0) & (t <= t1)
        f = ((t - t0) / (t1 - t0))[..., None]
        out = np.where(m[..., None], c0 + (c1 - c0) * f, out)
    out = out * np.clip(lum / 0.1, 0, 1)[..., None]
    return np.dstack([out, a])


def make_gold():
    """python3 tools/make_fx.py --gold: writes Media/fx/*_gold.tga from the violet sheets
    (same size, same grid). Needs no Blender."""
    total = 0
    for src, dst in GOLD_SHEETS:
        sp, dp = os.path.join(OUT, src + ".tga"), os.path.join(OUT, dst + ".tga")
        img = to_image(gold_recolour(read_tga_rgba(sp)))
        assert img.size == Image.open(sp).size, dst
        write_tga(img, dp)
        check_tga(dp)
        total += os.path.getsize(dp)
        print("  %-18s %4dx%-4d %7.1f KB" % (dst, img.size[0], img.size[1], os.path.getsize(dp) / 1024))
    print("gold media: %.2f MB" % (total / 1024 / 1024))
    return gold_preview()


def gold_preview():
    """tools/fx_gold_before_after.png: violet above, gold below, same frames on the night colour."""
    cols = [("portal_open", "portal_open_gold", 8, [0, 7, 14, 20, 26, 31]),
            ("portal_loop", "portal_loop_gold", 4, [0, 3, 6, 9, 12, 15]),
            ("arrival", "arrival_gold", 8, [4, 7, 9, 12, 18, 26])]
    night = np.array(NIGHT)
    rows = []
    for v, g, ncols, idx in cols:
        for name in (v, g):
            sheet = read_tga_rgba(os.path.join(OUT, name + ".tga"))
            fr = []
            for i in idx:
                c = sheet[(i // ncols) * 128:(i // ncols + 1) * 128, (i % ncols) * 128:(i % ncols + 1) * 128]
                lit = np.clip(night + c[..., :3] * c[..., 3:4], 0, 1)  # ADD: colour x alpha
                fr.append(lit)
            rows.append((name, np.hstack(fr)))
    W_, H_ = 6 * 128, len(rows) * (128 + 18) + 10
    img = Image.new("RGB", (W_ + 20, H_ + 30), tuple(int(c * 255) for c in NIGHT))
    d = ImageDraw.Draw(img)
    d.text((10, 6), "Founder gold portal: violet (genuine founders' summons use the gold row below each)", fill=(230, 230, 240))
    y = 26
    for name, strip in rows:
        d.text((10, y), name, fill=(200, 200, 215))
        img.paste(Image.fromarray((strip * 255 + 0.5).astype(np.uint8)), (10, y + 14))
        y += 146
    path = os.path.join(HERE, "fx_gold_before_after.png")
    img.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--gold" in sys.argv:
        print("preview:", make_gold())
        return
    rerender = "--rerender" in sys.argv
    if rerender or not os.path.exists(os.path.join(WORK, "crown", "f31.png")):
        blender("crown_blend.py", os.path.join(WORK, "crown"), 32, 240, 40)
    if rerender or not os.path.exists(os.path.join(WORK, "badges", "coin", "f07.png")):
        blender("badges_blend.py", os.path.join(WORK, "badges"), 10, 240, 32)

    sheets = {}
    SS = 2  # light effects render at twice the cell size, then Lanczos down
    cell = 128
    px = (cell - 2 * GUTTER) * SS

    print("crown", flush=True)
    sheets["crown"] = (pack(crown_frames(60), 8, 4, 64), 8)
    print("badges", flush=True)
    bf = []
    for b in BADGE_ORDER:
        bf += badge_frames(b, 60)
    sheets["badges"] = (pack(bf, 8, 8, 64), 8)
    print("portal_loop", flush=True)
    sheets["portal_loop"] = (light_sheet(portal_loop(px), 4, 4, cell, SS), 4)
    print("portal_open", flush=True)
    sheets["portal_open"] = (light_sheet(portal_open(px), 8, 4, cell, SS), 8)
    print("arrival", flush=True)
    sheets["arrival"] = (light_sheet(arrival(px), 8, 4, cell, SS), 8)
    print("milestone", flush=True)
    sheets["milestone"] = (light_sheet(milestone(px), 4, 4, cell, SS), 4)
    print("parts", flush=True)
    sheets["parts"] = (parts_atlas(coin_frames(60)), 8)
    sheets["runes"] = (lone_sprite(make_runes(256 - 2 * GUTTER)), 1)
    sheets["rays"] = (lone_sprite(make_rays(256 - 2 * GUTTER)), 1)

    total = 0
    for name, (sheet, _) in sheets.items():
        path = os.path.join(OUT, name + ".tga")
        write_tga(to_image(sheet), path)
        check_tga(path)
        total += os.path.getsize(path)
        print("  %-12s %4dx%-4d %7.1f KB" % (name, sheet.shape[1], sheet.shape[0], os.path.getsize(path) / 1024))
    print("total media: %.2f MB" % (total / 1024 / 1024))
    print("preview:", previews(sheets))
    for g in gifs(sheets):
        print("gif:", g)


if __name__ == "__main__":
    main()
