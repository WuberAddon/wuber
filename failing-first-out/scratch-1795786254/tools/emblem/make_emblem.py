"""Wuber's Pioneer emblem atlases (BRIEF16, portal art): renders the portal in Blender
(tools/emblem/portal_blend.py), then packs each colour into a game atlas the way the founder's crown
is packed (tools/make_fx.py: the same downsample, bloom halo, dilated straight alpha and 32-bit TGA
writer), with gold star glints laid over the flung sparks and twinkles flashing round the ring
(tools/emblem/portal_sparks.py: the same positions the Blender render uses).

    python tools/emblem/make_emblem.py [--no-render] [--blender PATH]

Writes:
    Wuber/Media/fx/emblem.tga        1024x512  8x4 cells of 128, 32 frames, BLEND (violet: Pioneer riders)
    Wuber/Media/fx/emblem_teal.tga   1024x512  8x4 cells of 128, 32 frames, BLEND (teal: Pioneer Drivers)
    tools/emblem/contact_portal.png  every frame of both colours, plus each at the in-game size (64 px)
                                     over dark and light grounds and a mock nameplate
    tools/emblem/emblem_portal.gif   both colours looping, 2x, on dark and on light

The loop is seamless (see portal_blend.py): frame 32 would be frame 0. FX.Emblem steps the frames.
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, HERE)
import make_fx as F  # noqa: E402
import portal_sparks as S  # noqa: E402

BLENDER = __import__("os").environ.get("BLENDER", "blender")
WORK = os.path.join(os.environ.get("TEMP", "/tmp"), "wuber_emblem_portal")
OUT = os.path.join(ROOT, "Wuber", "Media", "fx")
FRAMES, RES, SAMPLES = 32, 384, 96
CELL, COLS, ROWS = 128, 8, 4
CONTENT = CELL - 2 * F.GUTTER
GOLD_GLINT = np.array([1.0, 0.86, 0.52])
COLOURS = {
    # name, halo colour (the portal's glow), twinkle colour inside the swirl
    "violet": ("emblem", np.array([0xA5, 0x5C, 0xF0]) / 255, np.array([1.0, 0.92, 1.0])),
    "teal": ("emblem_teal", np.array([0x2C, 0xCF, 0xBC]) / 255, np.array([0.9, 1.0, 0.98])),
}


def render(blender):
    procs = []
    for colour in COLOURS:
        d = os.path.join(WORK, colour)
        os.makedirs(d, exist_ok=True)
        cmd = [blender, "-b", "--factory-startup", "-P", os.path.join(HERE, "portal_blend.py"), "--",
               d, colour, str(FRAMES), str(RES), str(SAMPLES)]
        print("  blender:", colour, flush=True)
        procs.append(subprocess.Popen(cmd, stdout=subprocess.DEVNULL))
    for p in procs:
        if p.wait() != 0:
            raise SystemExit("blender failed")


def portal_frame(path, t, glow, star_col):
    """A Cycles render -> a game frame: downsampled, bloom from the bright parts and a soft halo in
    the portal's colour behind it, then star glints (gold on the flung sparks and round the ring,
    pale in the swirl) screened over, straight alpha with dilated colour."""
    n = CONTENT
    P = F.resize_premult(F.load_premult(path), n)
    a = P[..., 3]
    lum = P[..., 0] * 0.3 + P[..., 1] * 0.55 + P[..., 2] * 0.15
    bright = np.clip(lum - 0.55, 0, None)[..., None] * (P[..., :3] / np.maximum(a[..., None], 1e-3))
    g = 0.8 * F.blur(bright, 1.0) + 0.6 * F.blur(bright, 2.6)
    sil = ndimage.gaussian_filter(a, 3.0)
    g += sil[..., None] * glow * 0.42
    g_a = np.clip(g.max(axis=2), 0, 0.8)
    G = np.zeros((n, n, 4))
    G[..., :3] = np.where(g_a[..., None] > 0, np.clip(g / np.maximum(g_a[..., None], 1e-3), 0, 1) * g_a[..., None], 0)
    G[..., 3] = g_a
    out = P + G * (1 - a[..., None])
    # the glints: four-point stars, screened over (premultiplied add, alpha union)
    E = np.zeros((n, n, 3))
    for x, y, b, size, dx, dy in S.flung(t):
        if b > 0.12:
            F.splat(E, n, x, y, 0.042 * size * (0.5 + 0.5 * b), GOLD_GLINT, 1.2 * b, shape="star", ang=0.0)
    tw = S.twinkles(t)
    for k, (x, y, b, size) in enumerate(tw):
        if b < 0.05:
            continue
        inner = k >= len(S.TWINKLES)
        F.splat(E, n, x, y, (0.028 if inner else 0.052) * size, star_col if inner else GOLD_GLINT,
                (0.8 if inner else 1.25) * b, shape="star", ang=0.0 if inner else math.pi / 4 * (k % 2))
    ea = np.clip(E.max(axis=2), 0, 1)
    out[..., :3] = out[..., :3] + np.clip(E, 0, 1) * (1 - out[..., :3])
    out[..., 3] = np.maximum(out[..., 3], ea)
    return F.straight_from_premult(np.clip(out, 0, 1))


def frames(colour, glow, star_col):
    d = os.path.join(WORK, colour)
    return [portal_frame(os.path.join(d, "f%02d.png" % i), i / FRAMES, glow, star_col) for i in range(FRAMES)]


def cell_image(sheet_img, i):
    x, y = (i % COLS) * CELL, (i // COLS) * CELL
    return sheet_img.crop((x, y, x + CELL, y + CELL))


GROUNDS = [("dark", (24, 24, 30, 255)), ("light", (170, 176, 166, 255)), ("plate", (60, 70, 60, 255)),
           ("snow", (225, 228, 235, 255))]


def ground_tile(small, kind):
    tile = Image.new("RGBA", (96, 96), dict(GROUNDS)[kind])
    if kind == "plate":
        td = ImageDraw.Draw(tile)
        td.rectangle((8, 80, 88, 88), fill=(20, 140, 30, 255), outline=(0, 0, 0, 255))
        td.text((30, 68), "Name", fill=(255, 255, 255, 255))
        tile.alpha_composite(small, (16, 0))
    else:
        tile.alpha_composite(small, (16, 16))
    return tile


def contact(sheets):
    """Every frame of both colours on night blue; then two frames at 64 px (the in-game size) over a
    dark, a light, a nameplate and a snow ground, as the game draws it (straight alpha, BLEND)."""
    pad, lab = 8, 16
    w = COLS * (CELL // 2) + pad * 2
    rows_h = ROWS * (CELL // 2)
    h = pad + 2 * (lab + rows_h + pad) + lab + 2 * (96 + pad) + pad
    img = Image.new("RGBA", (max(w, 2 * 4 * 100 + pad * 3), h), (11, 11, 22, 255))
    d = ImageDraw.Draw(img)
    y = pad
    for colour, (name, _, _) in COLOURS.items():
        sheet = sheets[colour]
        d.text((pad, y), "%s.tga: 32 frames (half size), a seamless loop" % name, fill=(220, 220, 230, 255))
        y += lab
        for i in range(FRAMES):
            c = cell_image(sheet, i).resize((CELL // 2, CELL // 2), Image.LANCZOS)
            img.alpha_composite(c, (pad + (i % COLS) * (CELL // 2), y + (i // COLS) * (CELL // 2)))
        y += rows_h + pad
    d.text((pad, y), "in game size (64 px): dark, light, over a nameplate, snow (frames 5 and 21)",
           fill=(220, 220, 230, 255))
    y += lab
    for row, fi in enumerate((5, 21)):
        x = pad
        for colour in COLOURS:
            small = cell_image(sheets[colour], fi).resize((64, 64), Image.LANCZOS)
            for kind, _ in GROUNDS:
                img.alpha_composite(ground_tile(small, kind), (x, y))
                x += 100
            x += pad
        y += 96 + pad
    path = os.path.join(HERE, "contact_portal.png")
    img.save(path)
    return path


def gif(sheets):
    """Both colours at 2x on night blue, and each at 64 px on a dark and a light ground, looping at
    the game's speed (look 2: 32 frames * 0.6 / (pi/3) = about 18 frames a second)."""
    out = []
    for i in range(FRAMES):
        f = Image.new("RGBA", (2 * 2 * CELL, 2 * CELL + 96), (11, 11, 22, 255))
        x = 0
        for k, colour in enumerate(COLOURS):
            im = cell_image(sheets[colour], i)
            f.alpha_composite(im.resize((2 * CELL, 2 * CELL), Image.LANCZOS), (k * 2 * CELL, 0))
            small = im.resize((64, 64), Image.LANCZOS)
            for kind in ("dark", "light"):
                t = Image.new("RGBA", (128, 96), dict(GROUNDS)[kind])
                t.alpha_composite(small, (32, 16))
                f.alpha_composite(t, (x, 2 * CELL))
                x += 128
        out.append(f.convert("RGB"))
    path = os.path.join(HERE, "emblem_portal.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=55, loop=0)
    return path


def main():
    args = sys.argv[1:]
    blender = BLENDER
    if "--blender" in args:
        blender = args[args.index("--blender") + 1]
    if "--no-render" not in args:
        render(blender)
    sheets = {}
    for colour, (name, glow, star_col) in COLOURS.items():
        sheet = F.pack(frames(colour, glow, star_col), COLS, ROWS, CELL)
        path = os.path.join(OUT, name + ".tga")
        im = F.to_image(sheet)
        F.write_tga(im, path)
        F.check_tga(path)
        sheets[colour] = im
        print("  %-12s %dx%d %7.1f KB" % (name, im.size[0], im.size[1], os.path.getsize(path) / 1024), flush=True)
    print("contact:", contact(sheets))
    print("gif:", gif(sheets))


if __name__ == "__main__":
    main()
