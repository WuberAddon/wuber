"""Makes Wuber's three font files from Inter's official release.

  python tools/fonts/make_inter.py <release folder> [--out <folder>] [--no-kern]

<release folder> is the unpacked release zip of https://github.com/rsms/inter (the shipped files were made
from Inter-4.1.zip, release v4.1, font version 4.001); its static hinted TrueType files are in extras/ttf/.
Needs fonttools only (pip install fonttools). Writes Inter-Regular.ttf (400), Inter-Medium.ttf (500) and
Inter-Bold.ttf (700) into Wuber/Media/fonts/ (or --out), and prints each file's size, glyph count and digit width.

What it does to each file, and nothing else:
  1. Digits all one width: the release's 'tnum' feature is baked in. The game has no switch for font features,
     so the character map itself is changed: 0..9 point at the tabular glyphs (zero.tf .. nine.tf). Only the
     ten digits; punctuation keeps its normal width.
  2. Latin only: the characters in KEEP below (Basic Latin, Latin-1, Latin Extended-A, the Romanian comma
     letters, capital sharp s, general punctuation, euro, trade mark, arrows, minus). No Cyrillic, no Greek,
     nothing else. Every non-ASCII character in a string of Wuber/**/*.lua must be in KEEP (22 Nov 2026: the
     middle dot U+00B7, the en dash U+2013 and the right single quote U+2019; tests/d3/d3_a_font_test.lua checks).
  3. Layout features dropped except pair kerning (GPOS 'kern'); --no-kern drops that too.
  4. Outlines and hinting (fpgm, prep, cvt, gasp, glyph instructions) are kept as the release has them. The
     family name stays "Inter": its licence (SIL OFL 1.1, Wuber/Media/fonts/OFL.txt) declares no Reserved
     Font Name.
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

WEIGHTS = ["Regular", "Medium", "Bold"]


def ranges(*pairs):
    out = []
    for lo, hi in pairs:
        out.extend(range(lo, hi + 1))
    return out


KEEP = sorted(set(ranges(
    (0x0020, 0x007E),  # Basic Latin
    (0x00A0, 0x00FF),  # Latin-1 Supplement (non-breaking space, guillemets, middle dot, multiply, ...)
    (0x0100, 0x017F),  # Latin Extended-A
    (0x0218, 0x021B),  # Romanian S and T with comma below
    (0x1E9E, 0x1E9E),  # capital sharp s
    (0x2009, 0x200A),  # thin and hair space
    (0x2010, 0x2015),  # hyphen, non-breaking hyphen, figure dash, en dash, em dash, horizontal bar
    (0x2018, 0x201F),  # curly quotes, single and double
    (0x2020, 0x2022),  # dagger, double dagger, bullet
    (0x2026, 0x2026),  # ellipsis
    (0x202F, 0x202F),  # narrow non-breaking space
    (0x2030, 0x2030),  # per mille
    (0x2032, 0x2033),  # prime, double prime
    (0x2039, 0x203A),  # single guillemets
    (0x2044, 0x2044),  # fraction slash
    (0x20AC, 0x20AC),  # euro
    (0x2122, 0x2122),  # trade mark
    (0x2190, 0x2199),  # arrows
    (0x2212, 0x2212),  # minus
)))


def tnum_map(font):
    """glyph name -> its tabular glyph, from the font's own 'tnum' feature."""
    gsub = font["GSUB"].table
    out = {}
    for rec in gsub.FeatureList.FeatureRecord:
        if rec.FeatureTag != "tnum":
            continue
        for index in rec.Feature.LookupListIndex:
            for st in gsub.LookupList.Lookup[index].SubTable:
                st = getattr(st, "ExtSubTable", st)
                out.update(getattr(st, "mapping", {}))
    return out


def bake_digits(font):
    tab = tnum_map(font)
    done = set(tab.values())  # fonttools may share one map between sub-tables: a digit can be baked already
    for table in font["cmap"].tables:
        if not table.isUnicode():
            continue
        for cp in range(0x30, 0x3A):
            name = table.cmap.get(cp)
            if name is None or name in done:
                continue
            if name not in tab:
                raise SystemExit("no tabular glyph for U+%04X (%s): is this Inter's release?" % (cp, name))
            table.cmap[cp] = tab[name]


def make(src, dst, kern=True):
    font = TTFont(src)
    bake_digits(font)
    missing = [cp for cp in KEEP if cp not in font.getBestCmap()]
    opts = subset.Options()
    opts.layout_features = ["kern"] if kern else []
    opts.hinting = True
    opts.glyph_names = False
    opts.notdef_outline = True
    opts.name_IDs = [0, 1, 2, 3, 4, 5, 6, 7, 13, 14, 16, 17]
    opts.name_languages = [0x409]
    opts.legacy_kern = False
    opts.prune_unicode_ranges = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[cp for cp in KEEP if cp not in missing])
    sub.subset(font)
    font.save(dst)
    font = TTFont(dst)
    cmap, hmtx = font.getBestCmap(), font["hmtx"]
    widths = sorted(set(hmtx[cmap[cp]][0] for cp in range(0x30, 0x3A)))
    family = font["name"].getDebugName(1)
    print("%s: %d bytes, %d glyphs, %d characters, digit width %s of %d, family %r%s" % (
        os.path.basename(dst), os.path.getsize(dst), len(font.getGlyphOrder()), len(cmap), widths,
        font["head"].unitsPerEm, family, missing and (", NOT IN INTER: " + " ".join("U+%04X" % c for c in missing)) or ""))
    if len(widths) != 1:
        raise SystemExit("the digits are not one width")


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    release = args[0]
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "..", "Wuber", "Media", "fonts")
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
        args = [a for a in args if a != out]
        release = args[0]
    for weight in WEIGHTS:
        src = os.path.join(release, "extras", "ttf", "Inter-%s.ttf" % weight)
        if not os.path.exists(src):
            raise SystemExit("not found: " + src)
        make(src, os.path.join(out, "Inter-%s.ttf" % weight), kern="--no-kern" not in argv)


if __name__ == "__main__":
    main(sys.argv[1:])
