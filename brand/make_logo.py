from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import math
SS = 4
FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
VIOLET = (138, 92, 255)
MAGENTA = (214, 76, 255)

def portal(size):
    """A glowing summoning ring with a soft inner swirl, on transparent."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cx = cy = S / 2
    r_out, width = S * 0.40, S * 0.055
    # ring with an angular colour sweep
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = ring.load()
    for y in range(0, S):
        dy = y - cy
        for x in range(0, S):
            dx = x - cx
            d = math.hypot(dx, dy)
            edge = abs(d - r_out)
            if edge < width:
                a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
                t = 0.5 + 0.5 * math.sin(a * 2 * math.pi * 2)
                c = tuple(int(VIOLET[i] * (1 - t) + MAGENTA[i] * t) for i in range(3))
                alpha = int(255 * min(1, (width - edge) / (width * 0.35)))
                px[x, y] = c + (alpha,)
    glow = ring.filter(ImageFilter.GaussianBlur(S * 0.035))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, ring)
    # inner haze
    haze = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    rr = r_out * 0.80
    hd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=VIOLET + (60,))
    haze = haze.filter(ImageFilter.GaussianBlur(S * 0.06))
    img = Image.alpha_composite(img, haze)
    return img

def letter(S, text, size, fill):
    lay = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    f = ImageFont.truetype(FONT, size)
    b = d.textbbox((0, 0), text, font=f)
    w, h = b[2] - b[0], b[3] - b[1]
    d.text(((S - w) / 2 - b[0], (S - h) / 2 - b[1]), text, font=f, fill=fill)
    return lay

def icon(size=1024, bg=True):
    S = size * SS
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    if bg:
        d = ImageDraw.Draw(base)
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=(0, 0, 0, 255))
    p = portal(size).resize((S, S), Image.LANCZOS) if False else portal(size)
    base = Image.alpha_composite(base, p)
    shadow = letter(S, "W", int(S * 0.46), (0, 0, 0, 200)).filter(ImageFilter.GaussianBlur(S * 0.012))
    base = Image.alpha_composite(base, shadow)
    base = Image.alpha_composite(base, letter(S, "W", int(S * 0.46), (255, 255, 255, 255)))
    return base.resize((size, size), Image.LANCZOS)

ic = icon(1024)
ic.save("wuber-icon.png")
icon(1024, bg=False).save("wuber-icon-transparent.png")
ic.resize((256, 256), Image.LANCZOS).save("wuber-icon-256.png")

def wordmark(colour, bgcol, name):
    W_, H_ = 2000, 760
    S = SS
    img = Image.new("RGBA", (W_ * S, H_ * S), bgcol)
    mark = icon(560, bg=(bgcol[3] == 0 and colour == (0, 0, 0, 255)))
    img_small = img.resize((W_, H_))
    img_small.alpha_composite(mark, (110, 100))
    d = ImageDraw.Draw(img_small)
    f = ImageFont.truetype(FONT, 330)
    d.text((730, 175), "Wuber", font=f, fill=colour)
    f2 = ImageFont.truetype("/usr/share/fonts/truetype/google-fonts/Poppins-Medium.ttf", 64)
    d.text((742, 560), "Summons on demand", font=f2, fill=(colour[0], colour[1], colour[2], 170))
    img_small.save(name)

wordmark((255, 255, 255, 255), (0, 0, 0, 255), "wuber-logo.png")
wordmark((0, 0, 0, 255), (0, 0, 0, 0), "wuber-logo-transparent.png")
print("ok")
