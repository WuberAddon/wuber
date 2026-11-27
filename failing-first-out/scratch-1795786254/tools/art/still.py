#!/usr/bin/env python3
"""Turns one still picture (a png) into a game texture: a 32-bit TGA the game can draw with the normal blend.

    python tools/art/still.py <in.png> <size> <out.tga>
    python tools/art/still.py in/portal-still.png 512 Wuber/Media/portal_still.tga

The picture is only resized (never repainted). The black around it becomes transparent so no square shows:
alpha = max(r, g, b) of each pixel, and the colour is divided by that alpha, so the picture drawn over black
looks exactly like the original. Prints the file size and the memory the texture takes in the game
(size x size x 4 bytes). The TGA is written like tools/make_media.py writes them (uncompressed, 32 bits,
8 alpha bits, rows bottom-up).
"""
import os
import struct
import sys

from PIL import Image


def black_to_alpha(img):
    """RGB picture over black -> RGBA with alpha = max(r, g, b), colour un-multiplied."""
    img = img.convert("RGB")
    out = []
    for r, g, b in img.getdata():
        a = max(r, g, b)
        if a == 0:
            out.append((0, 0, 0, 0))
        else:
            out.append((min(255, (r * 255 + a // 2) // a), min(255, (g * 255 + a // 2) // a),
                        min(255, (b * 255 + a // 2) // a), a))
    res = Image.new("RGBA", img.size)
    res.putdata(out)
    return res


def write_tga(img, path):
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


def convert(src, size, dst):
    img = Image.open(src).convert("RGB")
    if img.size != (size, size):
        img = img.resize((size, size), Image.LANCZOS)
    write_tga(black_to_alpha(img), dst)
    return os.path.getsize(dst), size * size * 4


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    size = int(argv[2])
    if size < 1 or size & (size - 1):
        print("size must be a power of two")
        return 2
    file_bytes, mem = convert(argv[1], size, argv[3])
    print("%s: %d x %d, file %d bytes, texture memory %d bytes (%d x %d x 4)" % (argv[3], size, size, file_bytes, mem, size, size))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
