#!/usr/bin/env python3
"""Wuber: builds every texture in Wuber/Media as a 32-bit uncompressed TGA.

All art is original and drawn here from simple shapes. Shapes are white on transparent so
the addon tints them with SetVertexColor; a few (the icons, the map backdrops) carry their
own colours. Everything is drawn 8x larger and scaled down, so the edges are smooth.

    python3 tools/make_media.py          # writes Wuber/Media/*.tga and checks each one
"""
import math
import os
import random
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Wuber", "Media")
SS = 8  # supersampling factor

FONT_DIRS = ["/usr/share/fonts/truetype/google-fonts", "/usr/share/fonts/opentype/inter", "/usr/share/fonts/truetype/dejavu"]
BOLD_FONTS = ["Poppins-Bold.ttf", "Inter-ExtraBold.otf", "Inter-Bold.otf", "DejaVuSans-Bold.ttf"]
BRAND = os.path.join(HERE, "..", "brand")
POPPINS_DIR = "/usr/share/fonts/truetype/google-fonts"
POPPINS = ["Poppins-Regular.ttf", "Poppins-Medium.ttf", "Poppins-Bold.ttf"]
OFL_SOURCES = [
    "/root/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/share/doc/rust/licenses/OFL-1.1.txt",
    "/usr/share/common-licenses/OFL-1.1",
]


def bold_font(px):
    for d in FONT_DIRS:
        for name in BOLD_FONTS:
            p = os.path.join(d, name)
            if os.path.exists(p):
                return ImageFont.truetype(p, px)
    return ImageFont.load_default()


# ---------------------------------------------------------------------------
# Writing and checking
# ---------------------------------------------------------------------------

def write_tga(img, path):
    """Uncompressed true-colour TGA, 32 bits, 8 alpha bits, rows stored bottom-up."""
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


def pow2(n):
    return n > 0 and (n & (n - 1)) == 0


def check(name, img):
    path = os.path.join(OUT, name + ".tga")
    back = Image.open(path)
    back.load()
    assert back.format == "TGA", name
    assert back.mode == "RGBA", (name, back.mode)
    assert back.size == img.size, (name, back.size)
    assert pow2(back.size[0]) and pow2(back.size[1]), (name, back.size)
    with open(path, "rb") as f:
        head = f.read(18)
    assert head[2] == 2 and head[16] == 32, (name, "not uncompressed 32-bit")
    diff = ImageChops.difference(back.convert("RGBA"), img.convert("RGBA")).getbbox()
    assert diff is None, (name, "pixels differ after reload", diff)
    alpha = back.getchannel("A")
    lo, hi = alpha.getextrema()
    return "%-14s %4dx%-4d alpha %3d..%3d  %6d bytes" % (name, back.size[0], back.size[1], lo, hi, os.path.getsize(path))


# ---------------------------------------------------------------------------
# Drawing helpers (work at SS x size, then scale down)
# ---------------------------------------------------------------------------

def canvas(w, h):
    """A big alpha mask to draw on."""
    return Image.new("L", (w * SS, h * SS), 0)


def finish(mask, w, h, blur=0.0):
    """Scale the mask down; return white with that alpha."""
    small = mask.resize((w, h), Image.LANCZOS) if SS > 1 else mask
    if blur:
        small = small.filter(ImageFilter.GaussianBlur(blur))
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(small)
    return img


def S(v):
    return v * SS


def disc(d, cx, cy, r, fill=255):
    d.ellipse([S(cx - r), S(cy - r), S(cx + r), S(cy + r)], fill=fill)


def thick_line(d, pts, width, fill=255):
    """A polyline with round joins and caps."""
    sp = [(S(x), S(y)) for x, y in pts]
    d.line(sp, fill=fill, width=int(S(width)), joint="curve")
    for x, y in pts:
        disc(d, x, y, width / 2.0, fill)


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------------------
# The textures
# ---------------------------------------------------------------------------

def rounded():
    """64x64, corner radius 16: a 9-slice source (corners 0..0.25 and 0.75..1)."""
    m = canvas(64, 64)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S(64) - 1, S(64) - 1], radius=S(16), fill=255)
    return finish(m, 64, 64)


def pill():
    """64x32 with fully round ends: a 3-slice source (caps 0..0.25 and 0.75..1)."""
    m = canvas(64, 32)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S(64) - 1, S(32) - 1], radius=S(16), fill=255)
    return finish(m, 64, 32)


def shadow():
    """64x64 soft shadow of a rounded rect: 9-slice, corners are the four quarters."""
    m = canvas(64, 64)
    ImageDraw.Draw(m).rounded_rectangle([S(18), S(18), S(46), S(46)], radius=S(10), fill=255)
    img = finish(m, 64, 64)
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(6))
    # the blur leaves the middle a little weak; lift it so the shadow reads under a card
    a = a.point(lambda v: min(255, int(v * 1.25)))
    img.putalpha(a)
    return img


def circle():
    m = canvas(64, 64)
    disc(ImageDraw.Draw(m), 32, 32, 31.5)
    return finish(m, 64, 64)


def ring(size=64, stroke=5.0, blur=0.0):
    m = canvas(size, size)
    d = ImageDraw.Draw(m)
    c = size / 2.0
    disc(d, c, c, c - 0.5)
    disc(d, c, c, c - 0.5 - stroke, 0)
    return finish(m, size, size, blur)


def glow():
    """64x64 soft round glow (for dots and halos)."""
    img = Image.new("RGBA", (64, 64), (255, 255, 255, 0))
    a = Image.new("L", (64, 64), 0)
    px = a.load()
    for y in range(64):
        for x in range(64):
            r = math.hypot(x + 0.5 - 32, y + 0.5 - 32) / 32.0
            v = max(0.0, 1.0 - r)
            px[x, y] = int(255 * v * v)
    img.putalpha(a)
    return img


def pin():
    """64x64 teardrop map pin with a round hole (the addon puts a white dot in it)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    cx, cy, r = 32, 24, 19
    disc(d, cx, cy, r)
    # the point: tangent lines from the tip to the circle
    tip = (32, 62)
    dist = tip[1] - cy
    ang = math.asin(r / dist)
    left = (cx - r * math.cos(ang), cy + r * math.sin(ang))
    right = (cx + r * math.cos(ang), cy + r * math.sin(ang))
    d.polygon([(S(left[0]), S(left[1])), (S(right[0]), S(right[1])), (S(tip[0]), S(tip[1]))], fill=255)
    disc(d, cx, cy, 7.5, 0)
    return finish(m, 64, 64)


def summon():
    """64x64 portal glyph: a ring with a four-point spark inside and two orbiting motes."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    disc(d, 32, 32, 27)
    disc(d, 32, 32, 22, 0)
    # four-point spark, concave sides
    pts = []
    for i in range(8):
        r = 15 if i % 2 == 0 else 4.2
        a = math.radians(-90 + i * 45)
        pts.append((S(32 + r * math.cos(a)), S(32 + r * math.sin(a))))
    d.polygon(pts, fill=255)
    disc(d, 44.5, 19.5, 2.6)
    disc(d, 19.5, 44.5, 2.0)
    return finish(m, 64, 64)


def ride():
    """64x64 minimal car from simple shapes (body, cabin, two wheels)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    # cabin (a trapezoid with soft corners)
    d.rounded_rectangle([S(17), S(17), S(47), S(34)], radius=S(6), fill=255)
    # body
    d.rounded_rectangle([S(6), S(28), S(58), S(46)], radius=S(7), fill=255)
    # windows cut out of the cabin
    d.rounded_rectangle([S(21), S(21), S(30.5), S(29)], radius=S(2.5), fill=0)
    d.rounded_rectangle([S(33.5), S(21), S(43), S(29)], radius=S(2.5), fill=0)
    # wheel arches cut, then wheels
    for wx in (19, 45):
        disc(d, wx, 46, 8.5, 0)
        disc(d, wx, 46, 6.2)
        disc(d, wx, 46, 2.2, 0)
    return finish(m, 64, 64)


def check_mark():
    m = canvas(64, 64)
    thick_line(ImageDraw.Draw(m), [(17, 33.5), (28, 44.5), (48, 22)], 7.0)
    return finish(m, 64, 64)


def star(filled=True):
    m = canvas(32, 32)
    d = ImageDraw.Draw(m)
    pts = star_points(16, 17, 14.5, 6.2)
    if filled:
        d.polygon([(S(x), S(y)) for x, y in pts], fill=255)
    else:
        thick_line(d, pts + [pts[0]], 2.2)
    return finish(m, 32, 32)


def radar():
    """256x256 conic sweep: bright leading edge at 12 o'clock fading out behind (clockwise)."""
    n = 256
    a = Image.new("L", (n, n), 0)
    px = a.load()
    trail = 110.0  # degrees of fading tail
    c = n / 2.0
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            r = math.hypot(dx, dy)
            if r > c - 1:
                edge = max(0.0, 1.0 - (r - (c - 1)))  # soft rim
            else:
                edge = 1.0
            if edge <= 0:
                continue
            # angle measured clockwise from straight up (screen coords: y grows downwards)
            ang = (math.degrees(math.atan2(dx, -dy)) + 360.0) % 360.0
            behind = (360.0 - ang) % 360.0  # how far behind the leading edge (at 0) we are
            if behind > trail:
                continue
            t = 1.0 - behind / trail
            v = t ** 2.2
            # a little brighter towards the rim, quieter at the centre
            v *= 0.55 + 0.45 * min(1.0, r / c)
            px[x, y] = int(255 * v * edge)
    img = Image.new("RGBA", (n, n), (255, 255, 255, 0))
    img.putalpha(a)
    return img


def fade():
    """32x256 vertical: clear at the top, solid at the bottom (smoothstep)."""
    a = Image.new("L", (32, 256), 0)
    px = a.load()
    for y in range(256):
        t = (y + 0.5) / 256.0
        v = t * t * (3 - 2 * t)
        for x in range(32):
            px[x, y] = int(255 * v)
    img = Image.new("RGBA", (32, 256), (255, 255, 255, 0))
    img.putalpha(a)
    return img


def gradient():
    """256x256 opaque dark backdrop: #1C1C1E at the top easing to black, faint centre glow."""
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 255))
    px = img.load()
    top = (0x1C, 0x1C, 0x1E)
    for y in range(256):
        t = (y + 0.5) / 256.0
        k = (1 - t) ** 1.6
        for x in range(256):
            r = math.hypot(x + 0.5 - 128, y + 0.5 - 90) / 181.0
            g = max(0.0, 1.0 - r) * 0.08
            px[x, y] = tuple(min(255, int(top[i] * k + 255 * g * 0.35)) for i in range(3)) + (255,)
    return img


def map_fallback():
    """256x256 opaque 'night map': dark ground with faint roads and a river. Drawn from a
    fixed seed, so every build is the same."""
    rnd = random.Random(1458)
    big = Image.new("RGBA", (S(256), S(256)), (0x15, 0x15, 0x17, 255))
    d = ImageDraw.Draw(big)
    # blocks of slightly lighter ground
    for _ in range(18):
        x, y = rnd.uniform(-20, 236), rnd.uniform(-20, 236)
        w, h = rnd.uniform(30, 80), rnd.uniform(30, 80)
        d.rounded_rectangle([S(x), S(y), S(x + w), S(y + h)], radius=S(10), fill=(0x19, 0x19, 0x1B, 255))
    # a river
    pts = []
    for i in range(0, 13):
        t = i / 12.0
        pts.append((S(-10 + 276 * t), S(170 + 30 * math.sin(t * 5.2) - 60 * t)))
    d.line(pts, fill=(0x16, 0x1B, 0x22, 255), width=S(14), joint="curve")
    # roads: gentle curves across, and a few short streets
    for _ in range(7):
        y0, y1 = rnd.uniform(0, 256), rnd.uniform(0, 256)
        bend = rnd.uniform(-40, 40)
        pts = [(S(-10 + 27.6 * i), S(y0 + (y1 - y0) * i / 10.0 + bend * math.sin(i / 10.0 * math.pi))) for i in range(11)]
        d.line(pts, fill=(0x24, 0x24, 0x27, 255), width=S(rnd.choice([2, 2, 3])), joint="curve")
    for _ in range(6):
        x0, x1 = rnd.uniform(0, 256), rnd.uniform(0, 256)
        pts = [(S(x0 + (x1 - x0) * i / 10.0), S(-10 + 27.6 * i)) for i in range(11)]
        d.line(pts, fill=(0x22, 0x22, 0x25, 255), width=S(2), joint="curve")
    return big.resize((256, 256), Image.LANCZOS)


def letter_w(size, box, fill=(255, 255, 255, 255), img=None, scale=0.78):
    """Draws a bold white W centred in box on img (RGBA, size x size at SS)."""
    font = bold_font(int(S(size) * scale))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = d.textbbox((0, 0), "W", font=font)
    tw, th = x1 - x0, y1 - y0
    bx0, by0, bx1, by1 = box
    d.text(((bx0 + bx1 - tw) / 2.0 - x0, (by0 + by1 - th) / 2.0 - y0), "W", font=font, fill=fill)


def w_icon(disc_shape):
    """Fallback icon when the brand art is missing: black tile or disc with a bold white W."""
    big = Image.new("RGBA", (S(64), S(64)), (255, 255, 255, 0))
    d = ImageDraw.Draw(big)
    if disc_shape:
        d.ellipse([0, 0, S(64) - 1, S(64) - 1], fill=(0, 0, 0, 255))
    else:
        d.rounded_rectangle([0, 0, S(64) - 1, S(64) - 1], radius=S(12), fill=(0, 0, 0, 255))
    letter_w(64, (0, 0, S(64), S(64)), img=big, scale=0.56 if disc_shape else 0.62)
    return big.resize((64, 64), Image.LANCZOS)


def brand(name):
    p = os.path.join(BRAND, name)
    if not os.path.exists(p):
        print("note: %s not found, using the plain W instead" % p)
        return None
    return Image.open(p).convert("RGBA")


def bleed(img):
    """Colour art: every fully clear pixel takes the colour of the nearest visible pixels
    (a pull-push fill: coarser and coarser averages fill the holes), so filtering at the
    edge never pulls in a fringe. Alpha is unchanged. (White RGB in clear pixels is only
    for the tintable white shapes.)"""
    import numpy as np
    arr = np.asarray(img.convert("RGBA")).astype(np.float64)
    alpha = arr[..., 3]
    known = (alpha > 0).astype(np.float64)
    rgb = arr[..., :3] * known[..., None]
    levels = [(rgb, known)]
    while min(levels[-1][1].shape) > 1:
        c, m = levels[-1]
        h, w = m.shape
        h2, w2 = (h + 1) // 2, (w + 1) // 2
        cp = np.zeros((h2 * 2, w2 * 2, 3)); cp[:h, :w] = c
        mp = np.zeros((h2 * 2, w2 * 2)); mp[:h, :w] = m
        c2 = cp.reshape(h2, 2, w2, 2, 3).sum(axis=(1, 3))
        m2 = mp.reshape(h2, 2, w2, 2).sum(axis=(1, 3))
        levels.append((c2, m2))
    # push: from the coarsest level down, fill each level's holes from the one above
    c, m = levels[-1]
    col = np.where(m[..., None] > 0, c / np.maximum(m, 1e-9)[..., None], 0)
    for c, m in reversed(levels[:-1]):
        h, w = m.shape
        up = np.repeat(np.repeat(col, 2, axis=0), 2, axis=1)[:h, :w]
        own = np.where(m[..., None] > 0, c / np.maximum(m, 1e-9)[..., None], 0)
        col = np.where(m[..., None] > 0, own, up)
    keep = alpha > 0
    out = arr.copy()
    out[..., :3] = np.where(keep[..., None], arr[..., :3], col)
    out = np.clip(np.round(out), 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def portal_disc(size, ring_px, ring_rgb=(28, 28, 30)):
    """the author's round portal art at `size`, inside a thin dark ring, clear outside."""
    src = brand("author-portal-256.png")
    if src is None:
        return None
    big = size * SS
    art = src.resize((big, big), Image.LANCZOS)
    # a clean circular mask (the source's own edge is soft)
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, big - 1, big - 1], fill=255)
    inner = Image.new("L", (big, big), 0)
    r = ring_px * SS
    ImageDraw.Draw(inner).ellipse([r, r, big - 1 - r, big - 1 - r], fill=255)
    out = Image.new("RGBA", (big, big), ring_rgb + (255,))
    filled = Image.new("RGBA", (big, big), ring_rgb + (255,))
    filled.paste(art.convert("RGB"), (0, 0), inner)
    out = filled
    out.putalpha(mask)
    out = out.resize((size, size), Image.LANCZOS)
    return bleed(out)


def icon():
    """64x64 addon icon (the TOC's): the author's portal in a thin dark ring."""
    return portal_disc(64, 3) or w_icon(False)


def minimap():
    """64x64 minimap button face: the portal in a thin dark ring."""
    return portal_disc(64, 4) or w_icon(True)


def portal():
    """256x256 the author's portal, clear outside the circle."""
    src = brand("author-portal-256.png")
    if src is None:
        return w_icon(True).resize((256, 256), Image.LANCZOS)
    return bleed(src.resize((256, 256), Image.LANCZOS))


def badge():
    """512x512 the author's badge for the splash, with softly rounded corners."""
    src = brand("author-badge-512.png")
    if src is None:
        return w_icon(False).resize((512, 512), Image.LANCZOS)
    src = src.resize((512, 512), Image.LANCZOS).convert("RGB")
    mask = Image.new("L", (S(512), S(512)), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S(512) - 1, S(512) - 1], radius=S(56), fill=255)
    mask = mask.resize((512, 512), Image.LANCZOS)
    out = src.convert("RGBA")
    out.putalpha(mask)
    return bleed(out)


def header():
    """1024x512 from the author's wide scene (the middle 512 rows), opaque."""
    src = brand("author-wide-1024.png")
    if src is None:
        return gradient().resize((1024, 512), Image.LANCZOS)
    src = src.convert("RGB")
    w, h = src.size
    if w != 1024:
        src = src.resize((1024, int(h * 1024 / w)), Image.LANCZOS)
        w, h = src.size
    top = max(0, (h - 512) // 2)
    crop = src.crop((0, top, 1024, top + 512))
    if crop.size != (1024, 512):
        crop = crop.resize((1024, 512), Image.LANCZOS)
    out = crop.convert("RGBA")
    out.putalpha(255)
    return out


def pill_outline():
    """64x32 pill outline (1.5 px), a 3-slice like pill: the premium badge's gold edge."""
    m = canvas(64, 32)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, S(64) - 1, S(32) - 1], radius=S(16), fill=255)
    d.rounded_rectangle([S(1.6), S(1.6), S(64 - 1.6) - 1, S(32 - 1.6) - 1], radius=S(16 - 1.6), fill=0)
    return finish(m, 64, 32)


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


VIOLET, MAGENTA, NIGHT, NIGHT_TOP, LINE = (hexrgb("883FDA"), hexrgb("E467FC"), hexrgb("0B0B16"),
                                           hexrgb("141228"), hexrgb("333154"))


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t + 0.5) for i in range(3))


def radar_vm():
    """256x256 radar sweep in colour: magenta leading edge fading to violet behind."""
    base = radar()
    a = base.getchannel("A")
    out = Image.new("RGBA", base.size)
    px, pa = out.load(), a.load()
    n = base.size[0]
    c = n / 2.0
    for y in range(n):
        for x in range(n):
            al = pa[x, y]
            dx, dy = x + 0.5 - c, y + 0.5 - c
            ang = (math.degrees(math.atan2(dx, -dy)) + 360.0) % 360.0
            behind = (360.0 - ang) % 360.0
            t = min(1.0, behind / 110.0)
            px[x, y] = mix(MAGENTA, VIOLET, t) + (al,)
    return bleed(out)


def hgrad():
    """256x8 opaque bar: violet on the left to magenta on the right (progress line)."""
    img = Image.new("RGBA", (256, 8))
    px = img.load()
    for x in range(256):
        col = mix(VIOLET, MAGENTA, x / 255.0)
        for y in range(8):
            px[x, y] = col + (255,)
    return img


def winbg():
    """512x1024: the whole window's background at 1.4x (504x840 used = 360x600 on screen):
    night gradient #141228 at the top to #0B0B16, radius 18, a 1 px #333154 edge.
    The addon shows it with SetTexCoord(0, 504/512, 0, 840/1024)."""
    W_, H_, k = 504, 840, 1.4
    shape = Image.new("L", (W_ * 4, H_ * 4), 0)
    ImageDraw.Draw(shape).rounded_rectangle([0, 0, W_ * 4 - 1, H_ * 4 - 1], radius=int(18 * k * 4), fill=255)
    inner = Image.new("L", (W_ * 4, H_ * 4), 0)
    e = int(1.0 * k * 4)
    ImageDraw.Draw(inner).rounded_rectangle([e, e, W_ * 4 - 1 - e, H_ * 4 - 1 - e], radius=int((18 - 1) * k * 4), fill=255)
    shape = shape.resize((W_, H_), Image.LANCZOS)
    inner = inner.resize((W_, H_), Image.LANCZOS)
    body = Image.new("RGB", (W_, H_))
    bp = body.load()
    for y in range(H_):
        t = min(1.0, y / (H_ * 0.55))
        t = t * t * (3 - 2 * t)
        col = mix(NIGHT_TOP, NIGHT, t)
        for x in range(W_):
            bp[x, y] = col
    edge = Image.new("RGB", (W_, H_), LINE)
    rgb = Image.composite(body, edge, inner)
    canvas_ = Image.new("RGBA", (512, 1024), NIGHT + (0,))
    piece = rgb.convert("RGBA")
    piece.putalpha(shape)
    canvas_.paste(piece, (0, 0))
    return bleed(canvas_)


def wordmark():
    """256x64 'Wuber' in a heavy sans, white, left-aligned, vertically centred.
    Shown at 96x24 (keep the 4:1 shape)."""
    big = Image.new("L", (S(256), S(64)), 0)
    d = ImageDraw.Draw(big)
    font = bold_font(int(S(64) * 0.80))
    x0, y0, x1, y1 = d.textbbox((0, 0), "Wuber", font=font)
    tw, th = x1 - x0, y1 - y0
    if tw > S(250):  # never clip
        font = bold_font(int(S(64) * 0.80 * S(250) / tw))
        x0, y0, x1, y1 = d.textbbox((0, 0), "Wuber", font=font)
        tw, th = x1 - x0, y1 - y0
    d.text((S(2) - x0, (S(64) - th) / 2.0 - y0), "Wuber", font=font, fill=255)
    return finish(big, 256, 64)


def close_glyph():
    m = canvas(32, 32)
    d = ImageDraw.Draw(m)
    thick_line(d, [(10, 10), (22, 22)], 2.6)
    thick_line(d, [(22, 10), (10, 22)], 2.6)
    return finish(m, 32, 32)


def back_glyph():
    m = canvas(32, 32)
    thick_line(ImageDraw.Draw(m), [(19, 8.5), (11.5, 16), (19, 23.5)], 2.8)
    return finish(m, 32, 32)


def search_glyph():
    m = canvas(32, 32)
    d = ImageDraw.Draw(m)
    disc(d, 14, 14, 8.5)
    disc(d, 14, 14, 6.0, 0)
    thick_line(d, [(20.5, 20.5), (26, 26)], 3.0)
    return finish(m, 32, 32)


def arc():
    """64x64 spinner arc: 270 degrees of a ring with round ends."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    stroke = 5.0
    r = 32 - 0.5 - stroke / 2.0
    d.arc([S(32 - r - stroke / 2), S(32 - r - stroke / 2), S(32 + r + stroke / 2), S(32 + r + stroke / 2)],
          start=-90, end=180, fill=255, width=int(S(stroke)))
    for ang in (-90, 180):
        a = math.radians(ang)
        disc(d, 32 + r * math.cos(a), 32 + r * math.sin(a), stroke / 2.0)
    return finish(m, 64, 64)


def gear_glyph():
    """64x64 settings cog: eight teeth, a hole in the middle."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    disc(d, 32, 32, 20)
    for i in range(8):
        a = math.radians(i * 45)
        ca, sa = math.cos(a), math.sin(a)
        # a tooth: a short rounded bar pointing out
        thick_line(d, [(32 + 18 * ca, 32 + 18 * sa), (32 + 25 * ca, 32 + 25 * sa)], 9.5)
    disc(d, 32, 32, 8.5, 0)
    return finish(m, 64, 64)


def heart_points(cx, cy, s, n=120):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s, cy - y * s))
    return pts


def heart(filled=True):
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    pts = heart_points(32, 30, 1.65)
    if filled:
        d.polygon([(S(x), S(y)) for x, y in pts], fill=255)
    else:
        thick_line(d, pts + [pts[0]], 4.6)
    return finish(m, 64, 64)


def bell_glyph():
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    # the dome and skirt
    d.pieslice([S(16), S(10), S(48), S(42)], 180, 360, fill=255)
    d.polygon([(S(16), S(26)), (S(48), S(26)), (S(53), S(46)), (S(11), S(46))], fill=255)
    d.rounded_rectangle([S(9), S(43), S(55), S(49)], radius=S(3), fill=255)
    disc(d, 32, 54, 5.5)  # the clapper
    disc(d, 32, 9, 3.5)   # the top knob
    return finish(m, 64, 64)


def chat_glyph():
    """64x64 speech bubble (round 9: the Drive footer's Messages): a rounded body, a tail at the
    lower left, three dots cut out."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(6), S(10), S(58), S(46)], radius=S(12), fill=255)
    d.polygon([(S(14), S(40)), (S(30), S(44)), (S(12), S(58))], fill=255)
    for x in (20, 32, 44):
        disc(d, x, 28, 4.2, 0)
    return finish(m, 64, 64)


def crown_glyph():
    """64x64 crown: three points with balls, a band."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.polygon([(S(8), S(20)), (S(20), S(36)), (S(32), S(14)), (S(44), S(36)), (S(56), S(20)),
               (S(52), S(46)), (S(12), S(46))], fill=255)
    d.rounded_rectangle([S(11), S(48), S(53), S(55)], radius=S(2.5), fill=255)
    for x, y in ((8, 18), (32, 11), (56, 18)):
        disc(d, x, y, 4.5)
    disc(d, 32, 37, 4, 0)  # a gem hole
    return finish(m, 64, 64)


def lock_glyph():
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(14), S(28), S(50), S(56)], radius=S(6), fill=255)
    d.arc([S(20), S(8), S(44), S(40)], 180, 360, fill=255, width=int(S(5.5)))
    d.rectangle([S(20), S(23), S(25.5), S(30)], fill=255)
    d.rectangle([S(38.5), S(23), S(44), S(30)], fill=255)
    disc(d, 32, 40, 4.5, 0)
    d.rectangle([S(30.5), S(41), S(33.5), S(49)], fill=0)
    return finish(m, 64, 64)


def clock_glyph():
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    disc(d, 32, 32, 27)
    disc(d, 32, 32, 21.5, 0)
    thick_line(d, [(32, 18), (32, 32), (42, 38)], 5.0)
    return finish(m, 64, 64)


def coin_glyph():
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    disc(d, 32, 32, 27)
    disc(d, 32, 32, 21.5, 0)
    disc(d, 32, 32, 17)
    # a star stamped in the middle
    d.polygon([(S(x), S(y)) for x, y in star_points(32, 33, 11, 4.6)], fill=0)
    return finish(m, 64, 64)


def trophy_glyph():
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.pieslice([S(16), S(-8), S(48), S(40)], 0, 180, fill=255)
    d.rectangle([S(16), S(8), S(48), S(17)], fill=255)
    for cx in (14, 50):  # handles
        d.arc([S(cx - 8), S(10), S(cx + 8), S(28)], 0, 360, fill=255, width=int(S(4)))
    d.rectangle([S(29), S(38), S(35), S(48)], fill=255)
    d.rounded_rectangle([S(19), S(47), S(45), S(55)], radius=S(2.5), fill=255)
    return finish(m, 64, 64)


def note_glyph():
    """(round 9) a page with three lines: a customer note."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(11), S(5), S(53), S(59)], radius=S(7), fill=255)
    d.rounded_rectangle([S(17), S(11), S(47), S(53)], radius=S(3), fill=0)
    for y, x1 in ((21, 42), (31, 42), (41, 35)):
        d.rounded_rectangle([S(22), S(y - 2.2), S(x1), S(y + 2.2)], radius=S(2), fill=255)
    return finish(m, 64, 64)


def gift_glyph():
    """(round 9) a present: lid, box, the ribbon as a gap, a bow."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(7), S(20), S(57), S(30)], radius=S(3), fill=255)
    d.rounded_rectangle([S(11), S(33), S(53), S(59)], radius=S(3), fill=255)
    d.rectangle([S(28.5), S(20), S(35.5), S(59)], fill=0)
    for cx in (23, 41):
        d.ellipse([S(cx - 8), S(8), S(cx + 8), S(20)], fill=255)
        d.ellipse([S(cx - 4), S(11.5), S(cx + 4), S(16.5)], fill=0)
    d.rectangle([S(29), S(11), S(35), S(20)], fill=255)
    return finish(m, 64, 64)


def shimmer():
    """128x64 soft diagonal band of light (white; the card sweeps it across)."""
    img = Image.new("RGBA", (128, 64), (255, 255, 255, 0))
    a = Image.new("L", (128, 64), 0)
    px = a.load()
    for y in range(64):
        for x in range(128):
            # distance from a slanted centre line
            u = (x - 64) - (y - 32) * 0.6
            v = max(0.0, 1.0 - abs(u) / 30.0)
            px[x, y] = int(255 * v ** 2.2 * 0.9)
    img.putalpha(a)
    return img


def border_glow():
    """64x64 rounded-rectangle outline glow for 9-slicing (soft inside and out)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(10), S(10), S(54), S(54)], radius=S(12), outline=255, width=int(S(3)))
    return finish(m, 64, 64, blur=2.2)


# ---------------------------------------------------------------------------
# The phone: the handset round the window (bezel, side keys, status bar glyphs)
# ---------------------------------------------------------------------------

def _rrect_sdf(xs, ys, cx, cy, hw, hh, r):
    """Signed distance (px) to a rounded rectangle (negative inside) and its outward normal."""
    import numpy as np
    px, py = xs - cx, ys - cy
    qx, qy = np.abs(px) - (hw - r), np.abs(py) - (hh - r)
    mx, my = np.maximum(qx, 0), np.maximum(qy, 0)
    outside = np.hypot(mx, my)
    d = outside + np.minimum(np.maximum(qx, qy), 0) - r
    # normal: from the nearest point of the inner (r-shrunk) rectangle
    nx = np.where(outside > 1e-6, mx / np.maximum(outside, 1e-6), np.where(qx > qy, 1.0, 0.0))
    ny = np.where(outside > 1e-6, my / np.maximum(outside, 1e-6), np.where(qx > qy, 0.0, 1.0))
    return d, nx * np.sign(px + 1e-9), ny * np.sign(py + 1e-9)


def phone():
    """256x256 handset bezel for 9-slicing (2 px per unit on screen; corners 0..0.4375 = 56
    units): outer radius 50, an 8-unit ring (a violet-titanium band lit from the top left, a
    dark groove, the black glass border) round a clear screen with radius 42. Colour art."""
    import numpy as np
    n = 256
    k = 2.0
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    c = n / 2.0
    d_out, nx, ny = _rrect_sdf(xs, ys, c, c, c, c, 50 * k)
    ring = 8 * k
    d_in, _, _ = _rrect_sdf(xs, ys, c, c, c - ring, c - ring, 42 * k)
    a_out = np.clip(0.5 - d_out, 0, 1)
    a_in = np.clip(0.5 - d_in, 0, 1)
    alpha = a_out * (1 - a_in)
    # light from the top left (image y points down)
    lx, ly = -0.32, -0.95
    ln = math.hypot(lx, ly)
    lit = np.clip(0.5 + 0.5 * (nx * lx / ln + ny * ly / ln), 0, 1)
    t = -d_out  # px in from the outer edge
    dark = np.array(hexrgb("15121f"), dtype=np.float64)
    mid = np.array(hexrgb("4a4272"), dtype=np.float64)
    light = np.array(hexrgb("c9c0ee"), dtype=np.float64)
    glass = np.array(hexrgb("07060c"), dtype=np.float64)
    groove = np.array(hexrgb("020204"), dtype=np.float64)
    edge = np.array(hexrgb("2a2644"), dtype=np.float64)

    def lerp(a, b, f):
        return a + (b - a) * f[..., None]

    # the metal band: 0..5 px, a rounded cylinder (bright in its middle), lit by the normal
    band = np.clip(t / 5.0, 0, 1)
    bulge = np.sin(np.pi * band) ** 0.7
    shade = lit ** 1.6
    metal = lerp(dark, mid, np.clip(0.25 + 0.75 * shade, 0, 1))
    metal = lerp(metal, light, np.clip(bulge * shade * 0.85, 0, 1))
    # a crisp specular line right on the outer edge (top brightest)
    spec = np.clip(1.0 - np.abs(t - 0.9) / 0.9, 0, 1) * (0.35 + 0.65 * shade)
    metal = lerp(metal, light, spec * 0.8)
    col = np.where((t < 5.0)[..., None], metal, glass)
    # the groove between metal and glass
    g = np.clip(1.0 - np.abs(t - 5.6) / 0.9, 0, 1)
    col = lerp(col, groove, g)
    # a faint lit line where the glass meets the screen
    e = np.clip(1.0 - np.abs(d_in - 1.0) / 1.2, 0, 1) * (0.55 + 0.45 * lit)
    col = lerp(col, edge, e)
    rgba = np.dstack([np.clip(np.round(col), 0, 255), np.round(alpha * 255)]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    return bleed(img)


def screen_bg():
    """512x1024: the phone's screen at 1.4x (504x898 used = 360x641 on screen: status bar,
    window and home strip): night gradient #141228 to #0B0B16, corner radius 43 (a touch
    more than the bezel's 42, so nothing shows outside the handset's rounded corners).
    The addon shows it with SetTexCoord(0, 504/512, 0, 898/1024)."""
    W_, H_, k = 504, 898, 1.4
    shape = Image.new("L", (W_ * 4, H_ * 4), 0)
    ImageDraw.Draw(shape).rounded_rectangle([0, 0, W_ * 4 - 1, H_ * 4 - 1], radius=int(43 * k * 4), fill=255)
    shape = shape.resize((W_, H_), Image.LANCZOS)
    body = Image.new("RGB", (W_, H_))
    bp = body.load()
    for y in range(H_):
        t = min(1.0, y / (H_ * 0.55))
        t = t * t * (3 - 2 * t)
        col = mix(NIGHT_TOP, NIGHT, t)
        for x in range(W_):
            bp[x, y] = col
    canvas_ = Image.new("RGBA", (512, 1024), NIGHT + (0,))
    piece = body.convert("RGBA")
    piece.putalpha(shape)
    canvas_.paste(piece, (0, 0))
    return bleed(canvas_)


def phone_key():
    """16x64 side key (volume, power): a small rounded bar shaded like a cylinder. Colour art."""
    W_, H_ = 16, 64
    m = canvas(W_, H_)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S(W_) - 1, S(H_) - 1], radius=S(6), fill=255)
    shape = m.resize((W_, H_), Image.LANCZOS)
    img = Image.new("RGBA", (W_, H_))
    px = img.load()
    dark, mid, light = hexrgb("17141f"), hexrgb("4a4272"), hexrgb("bdb4e4")
    for x in range(W_):
        u = (x + 0.5) / W_
        hl = max(0.0, 1.0 - abs(u - 0.38) / 0.3)
        col = mix(mix(dark, mid, math.sin(math.pi * u) ** 0.6), light, hl * 0.7)
        for y in range(H_):
            v = (y + 0.5) / H_
            fade = 1.0 - 0.25 * v
            px[x, y] = tuple(int(ch * fade) for ch in col) + (255,)
    img.putalpha(shape)
    return bleed(img)


def signal_bars():
    """64x32: four signal bars, one per 16 px column (the addon crops to the lit ones)."""
    m = canvas(64, 32)
    d = ImageDraw.Draw(m)
    for i, h in enumerate((11, 16, 22, 28)):
        x0 = i * 16 + 2.5
        d.rounded_rectangle([S(x0), S(30 - h), S(x0 + 11) - 1, S(30) - 1], radius=S(3), fill=255)
    return finish(m, 64, 32)


def battery_glyph():
    """64x32 battery outline with its nub; battery_fill is the charge (crop it to a level)."""
    m = canvas(64, 32)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(1), S(3), S(56) - 1, S(29) - 1], radius=S(8), fill=255)
    d.rounded_rectangle([S(3.6), S(5.6), S(53.4) - 1, S(26.4) - 1], radius=S(5.6), fill=0)
    d.rounded_rectangle([S(57.5), S(11), S(62.5) - 1, S(21) - 1], radius=S(2.5), fill=255)
    return finish(m, 64, 32)


def battery_fill():
    m = canvas(64, 32)
    ImageDraw.Draw(m).rounded_rectangle([S(6), S(8.2), S(51) - 1, S(23.8) - 1], radius=S(3.6), fill=255)
    return finish(m, 64, 32)


def fold_glyph():
    """64x32: two 32x32 cells. Left: "unfold" (one tall rounded rect + an arrow). Right: "fold"
    (two rects side by side). Outlines, white on clear, tinted in game."""
    m = canvas(64, 32)
    d = ImageDraw.Draw(m)
    w = 2.6
    # cell 1: the tall rect (x 5..19) and an arrow pointing right
    d.rounded_rectangle([S(5), S(4), S(19), S(28)], radius=S(3.5), fill=255)
    d.rounded_rectangle([S(5 + w), S(4 + w), S(19 - w), S(28 - w)], radius=S(1.4), fill=0)
    thick_line(d, [(22, 16), (29, 16)], 2.4)
    thick_line(d, [(26, 12.5), (29.5, 16), (26, 19.5)], 2.4)
    # cell 2: two rects (x 35..47 and 49..61)
    for x0, x1 in ((35, 47), (49, 61)):
        d.rounded_rectangle([S(x0), S(6), S(x1), S(26)], radius=S(3), fill=255)
        d.rounded_rectangle([S(x0 + w), S(6 + w), S(x1 - w), S(26 - w)], radius=S(1.2), fill=0)
    return finish(m, 64, 32)


def dash_line():
    """32x8 white: a 16 px dash and a 16 px gap, for REPEAT-tiled Lines (the flight map)."""
    m = canvas(32, 8)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, S(16) - 1, S(8) - 1], radius=S(3), fill=255)
    return finish(m, 32, 8)


def shield_glyph():
    """64x64 shield with an exclamation mark cut out (the PvP warning chip)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    # right side curves down to the point, left mirrors it
    right = [(54, 11), (54, 30), (51, 38), (45, 46), (38, 53), (32, 59)]
    left = [(64 - x, y) for x, y in reversed(right)]
    body = [(32, 4)] + right + left
    d.polygon([(S(x), S(y)) for x, y in body], fill=255)
    d.rounded_rectangle([S(29.2), S(17), S(34.8), S(37)], radius=S(2.8), fill=0)
    disc(d, 32, 44, 3.3, 0)
    return finish(m, 64, 64)


K = 64 / 24.0  # the 24 grid, drawn at 64 px: a 2 px stroke is 5.33 px


def g24(pts):
    return [(x * K, y * K) for x, y in pts]


def line24(d, pts, w=2.0):
    thick_line(d, g24(pts), w * K)


def circle24(d, cx, cy, r, w=2.0):
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(0, 361, 6)]
    line24(d, pts, w)


def arc24(cx, cy, r, a0, a1, step=5):
    out, a = [], a0
    while a < a1:
        out.append((cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))))
        a += step
    out.append((cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))))
    return out


def wheel_glyph():
    """64x64 steering wheel (design round 1): a rim, a hub, three spokes (left, right, down)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    circle24(d, 12, 12, 9.5)
    disc(d, 12 * K, 12 * K, 2.6 * K)
    line24(d, [(2.8, 10.5), (9.6, 12)])
    line24(d, [(21.2, 10.5), (14.4, 12)])
    line24(d, [(12, 14.5), (12, 21.4)])
    return finish(m, 64, 64)


def question_glyph():
    """64x64 question mark in a ring (design round 1)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    circle24(d, 12, 12, 9.5)
    hook = arc24(12, 9.6, 3.3, 180, 360 + 40)
    hook += [(13.4, 13.0), (12, 14.4)]
    line24(d, hook)
    disc(d, 12 * K, 17.2 * K, 1.35 * K)
    return finish(m, 64, 64)


def bug_glyph():
    """64x64 bug (design round 1): a body, a head, three legs a side, two feelers."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.ellipse([S(7.4 * K), S(8.6 * K), S(16.6 * K), S(21.4 * K)], fill=255)
    disc(d, 12 * K, 6.4 * K, 2.7 * K)
    d.line([(S(12 * K), S(9 * K)), (S(12 * K), S(21 * K))], fill=0, width=int(S(1.0 * K)))
    for sx in (-1, 1):
        line24(d, [(12 + sx * 6, 11.5), (12 + sx * 9.6, 9.5)])
        line24(d, [(12 + sx * 6.6, 14.5), (12 + sx * 10.4, 14.5)])
        line24(d, [(12 + sx * 6, 17.6), (12 + sx * 9.6, 20.0)])
        line24(d, [(12 + sx * 1.2, 4.2), (12 + sx * 3.6, 1.8)], 1.6)
    return finish(m, 64, 64)


def speaker_glyph():
    """64x64 speaker with two sound waves (design round 1)."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.polygon([(S(x * K), S(y * K)) for x, y in [(2.5, 9), (7, 9), (12.5, 4.5), (12.5, 19.5), (7, 15), (2.5, 15)]], fill=255)
    line24(d, arc24(12.5, 12, 5, -48, 48))
    line24(d, arc24(12.5, 12, 9, -48, 48))
    return finish(m, 64, 64)


def phone_glyph():
    """64x64 phone, seen from the front (design round 1): an outline, a speaker slit, a home bar."""
    m = canvas(64, 64)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([S(5.5 * K), S(1.2 * K), S(18.5 * K), S(22.8 * K)], radius=S(3.2 * K), fill=255)
    d.rounded_rectangle([S(7.5 * K), S(3.2 * K), S(16.5 * K), S(20.8 * K)], radius=S(1.6 * K), fill=0)
    line24(d, [(10.2, 19.4), (13.8, 19.4)], 1.6)
    return finish(m, 64, 64)


def chevron_glyph():
    """64x64 chevron pointing right (design round 1)."""
    m = canvas(64, 64)
    line24(ImageDraw.Draw(m), [(8.5, 4.5), (16, 12), (8.5, 19.5)], 2.4)
    return finish(m, 64, 64)


TEXTURES = [
    ("rounded", rounded),
    ("pill", pill),
    ("shadow", shadow),
    ("circle", circle),
    ("ring", lambda: ring(64, 5.0)),
    ("pulse", lambda: ring(128, 3.0, blur=0.4)),
    ("glow", glow),
    ("pin", pin),
    ("summon", summon),
    ("ride", ride),
    ("check", check_mark),
    ("star", lambda: star(True)),
    ("star_outline", lambda: star(False)),
    ("radar", radar),
    ("fade", fade),
    ("gradient", gradient),
    ("mapbg", map_fallback),
    ("icon", icon),
    ("minimap", minimap),
    ("portal", portal),
    ("badge", badge),
    ("header", header),
    ("wordmark", wordmark),
    ("pill_outline", pill_outline),
    ("radar_vm", radar_vm),
    ("hgrad", hgrad),
    ("winbg", winbg),
    ("close", close_glyph),
    ("back", back_glyph),
    ("search", search_glyph),
    ("arc", arc),
    ("gear", gear_glyph),
    ("heart", lambda: heart(True)),
    ("heart_outline", lambda: heart(False)),
    ("bell", bell_glyph),
    ("chat", chat_glyph),
    ("crown", crown_glyph),
    ("lock", lock_glyph),
    ("clock", clock_glyph),
    ("coin", coin_glyph),
    ("trophy", trophy_glyph),
    ("shimmer", shimmer),
    ("edge", border_glow),
    ("phone", phone),
    ("screen", screen_bg),
    ("phonekey", phone_key),
    ("signal", signal_bars),
    ("battery", battery_glyph),
    ("battery_fill", battery_fill),
    ("fold", fold_glyph),
    ("dash", dash_line),
    ("shield", shield_glyph),
    ("note", note_glyph),  # round 9: customer notes
    ("gift", gift_glyph),  # round 9: the Gifted stamp
    ("wheel", wheel_glyph),  # design round 1: the pictures
    ("question", question_glyph),
    ("bug", bug_glyph),
    ("speaker", speaker_glyph),
    ("phone_glyph", phone_glyph),
    ("chevron", chevron_glyph),
]


def fonts():
    """Copies Poppins (SIL Open Font License 1.1) into Media/fonts with its licence."""
    dest = os.path.join(OUT, "fonts")
    os.makedirs(dest, exist_ok=True)
    have = [n for n in POPPINS if os.path.exists(os.path.join(POPPINS_DIR, n))]
    licence = next((p for p in OFL_SOURCES if os.path.exists(p)), None)
    if len(have) != len(POPPINS) or not licence:
        print("note: Poppins or the OFL text not found; the addon falls back to Arial Narrow")
        return []
    import shutil
    for n in have:
        shutil.copyfile(os.path.join(POPPINS_DIR, n), os.path.join(dest, n))
    with open(licence, encoding="utf-8") as f:
        text = f.read()
    with open(os.path.join(dest, "OFL.txt"), "w", encoding="utf-8") as f:
        f.write("Poppins fonts (Poppins-Regular.ttf, Poppins-Medium.ttf, Poppins-Bold.ttf)\n")
        f.write("Copyright 2020 The Poppins Project Authors (https://github.com/itfoundry/Poppins)\n\n")
        f.write("This Font Software is licensed under the SIL Open Font License, Version 1.1.\n")
        f.write("This license is copied below, and is also available with a FAQ at:\n")
        f.write("https://openfontlicense.org\n\n\n")
        f.write(text)
    for n in have:
        ImageFont.truetype(os.path.join(dest, n), 12)  # loads: not damaged
    return have


def main():
    """python3 tools/make_media.py [name ...]: every texture (and the fonts), or only those named."""
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    if not only:
        print("fonts:", ", ".join(fonts()) or "none")
    report = []
    for name, fn in TEXTURES:
        if only and name not in only:
            continue
        img = fn().convert("RGBA")
        write_tga(img, os.path.join(OUT, name + ".tga"))
        report.append(check(name, img))
    print("\n".join(report))
    print("%d textures written to %s" % (len(report), os.path.normpath(OUT)))


if __name__ == "__main__":
    sys.exit(main())
