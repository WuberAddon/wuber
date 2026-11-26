"""Wuber's Pioneer emblem: a little summoning portal, face on. An open swirling vortex (Wuber's
violet, or the Pioneer Drivers' teal) with three spiral arms pulling into a bright core, a thin
glowing gold rune ring round it turning the other way, gold sparks flung off the rim, and a soft
outer glow. Lit like the founder's crown (tools/fx/common_blend.py's studio rig), on a
transparent background. Matches Wuber's own portal art (tools/make_fx.py's vortex_layers).

The loop is seamless over FRAMES: the three-armed swirl turns 120 degrees one way, the ring (12
glyphs, two designs alternating: six-fold) 60 degrees the other, and every spark is periodic
(tools/emblem/portal_sparks.py, shared with the packer, which lays the star glints over them).

No text or letters: the glyphs are plain geometric sigils.

Run headless with Blender 5.1 (tools/emblem/make_emblem.py does this for you):
    blender -b --factory-startup -P tools/emblem/portal_blend.py -- OUTDIR violet|teal [frames] [res] [samples]
"""
import math
import os
import sys

import bpy  # noqa: I001 (bpy first: it provides bmesh and mathutils)
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "fx"))
sys.path.insert(0, HERE)
import common_blend as C  # noqa: E402
import portal_sparks as S  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
OUT = argv[0] if len(argv) > 0 else "/tmp/emblem/violet"
COLOUR = argv[1] if len(argv) > 1 else "violet"
FRAMES = int(argv[2]) if len(argv) > 2 else 32
RES = int(argv[3]) if len(argv) > 3 else 256
SAMPLES = int(argv[4]) if len(argv) > 4 else 48
ONLY = [int(a) for a in argv[5].split(",")] if len(argv) > 5 and argv[5] else None
os.makedirs(OUT, exist_ok=True)


def lin(hexstr):
    """sRGB hex -> linear RGB (Blender colours are linear; the Standard view transform gives sRGB back)."""
    out = []
    for i in (0, 2, 4):
        c = int(hexstr[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# Wuber's palette (Theme.Tokens / make_fx.py): portal violet 883FDA, bright violet CD7DF5, magenta
# E467FC; Pioneer Drivers' teal 33E0CC. The gold is the same for both (F9C53E, deep gold B1873F).
PALETTES = {
    "violet": {
        # radius ramp of the swirl: hot core, magenta, violet, deep violet at the rim
        "ramp": [(0.0, (1.0, 0.80, 1.0)), (0.22, lin("E467FC")), (0.55, lin("9A4FEA")), (1.0, lin("3A0E7A"))],
        "gap": lin("1A0638"),     # between the arms: a dark violet, so the hole reads on light ground
        "core": (1.0, 0.86, 1.0),
        "glow": lin("A55CF0"),
        "light": (0.85, 0.35, 1.0), "fill": (0.75, 0.55, 1.0),
    },
    "teal": {
        "ramp": [(0.0, (0.85, 1.0, 0.97)), (0.22, lin("5AF5E2")), (0.55, lin("1FB5A6")), (1.0, lin("0A4E4A"))],
        "gap": lin("03221F"),
        "core": (0.88, 1.0, 0.97),
        "glow": lin("2CCFBC"),
        "light": (0.35, 0.95, 0.88), "fill": (0.55, 0.9, 0.85),
    },
}
PAL = PALETTES[COLOUR]
GOLD = lin("F9C53E")
GOLD_HOT = (1.0, 0.62, 0.17)   # an emission colour: at strength ~1.5 it shows as hot gold

C.reset_scene(RES, SAMPLES)
sc = bpy.context.scene
sc.cycles.transparent_max_bounces = 16
C.studio_world(1.0)
C.studio_lights(1.0)
for name, col in (("rimL", PAL["light"]), ("rimR", PAL["light"]), ("fill", PAL["fill"])):
    bpy.data.objects[name].data.color = col

# face on, orthographic: the emblem's plane spans -1..1 in the frame (portal_sparks' coordinates)
C.camera((0.0, -10.0, 0.0), (0.0, 0.0, 0.0), ortho=2.0)


# ---------------------------------------------------------------------------
# Node helpers
# ---------------------------------------------------------------------------

class Nodes:
    def __init__(self, mat):
        mat.use_nodes = True
        self.nt = mat.node_tree
        for n in list(self.nt.nodes):
            self.nt.nodes.remove(n)

    def new(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def _in(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            self.link(v, sock)

    def math(self, op, a, b=None, clamp=False):
        n = self.new("ShaderNodeMath", operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is not None:
                self._in(n.inputs[i], v)
        return n.outputs[0]

    def smooth(self, v, lo, hi):
        """smoothstep from lo to hi (lo > hi gives the falling edge)."""
        n = self.new("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP")
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        self.link(v, n.inputs["Value"])
        return n.outputs["Result"]

    def noise(self, x, y, z, scale, detail):
        comb = self.new("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)):
            self._in(comb.inputs[i], v)
        n = self.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = 0.55
        self.link(comb.outputs[0], n.inputs["Vector"])
        return n.outputs["Fac"]

    def ramp(self, fac, stops):
        r = self.new("ShaderNodeValToRGB")
        cr = r.color_ramp
        cr.interpolation = "EASE"
        cr.elements[0].position, cr.elements[0].color = stops[0][0], (*stops[0][1], 1)
        cr.elements[1].position, cr.elements[1].color = stops[-1][0], (*stops[-1][1], 1)
        for pos, col in stops[1:-1]:
            el = cr.elements.new(pos)
            el.color = (*col, 1)
        self.link(fac, r.inputs["Fac"])
        return r.outputs["Color"]

    def scale(self, colour, s):
        n = self.new("ShaderNodeVectorMath", operation="SCALE")
        self._in(n.inputs[0], colour)
        self._in(n.inputs["Scale"], s)
        return n.outputs[0]

    def add(self, a, b):
        n = self.new("ShaderNodeVectorMath", operation="ADD")
        self._in(n.inputs[0], a)
        self._in(n.inputs[1], b)
        return n.outputs[0]

    def glow_over_clear(self, colour, alpha):
        """Emission of colour, mixed over transparent by alpha (so it reads as glowing mist)."""
        out = self.new("ShaderNodeOutputMaterial")
        em = self.new("ShaderNodeEmission")
        self._in(em.inputs["Color"], colour)
        em.inputs["Strength"].default_value = 1.0
        tr = self.new("ShaderNodeBsdfTransparent")
        mix = self.new("ShaderNodeMixShader")
        self._in(mix.inputs["Fac"], alpha)
        self.link(tr.outputs[0], mix.inputs[1])
        self.link(em.outputs[0], mix.inputs[2])
        self.link(mix.outputs[0], out.inputs["Surface"])


def vortex_material(rot_holder):
    """The swirl on a disc of radius 1 (object space), Wuber's portal_loop look: three log-spiral
    arms bent by noise, flowing filaments, a calm hot eye, deep colour at the rim. Every pattern is
    three-fold, so a 120 degree turn (rot) brings it back exactly."""
    m = bpy.data.materials.new("vortex")
    N = Nodes(m)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    N.link(tc.outputs["Object"], sep.inputs[0])
    x, y = sep.outputs["X"], sep.outputs["Y"]
    r = N.math("SQRT", N.math("ADD", N.math("MULTIPLY", x, x), N.math("MULTIPLY", y, y)))
    th = N.math("ARCTAN2", y, x)
    lr = N.math("LOGARITHM", N.math("ADD", r, 0.04), math.e)
    rot = N.new("ShaderNodeValue")
    rot.outputs[0].default_value = 0.0
    rot_holder.append(rot)
    # phi: the angle in the turning, twisted frame (arms wind tighter towards the eye)
    phi = N.math("ADD", N.math("ADD", th, rot.outputs[0]), N.math("MULTIPLY", lr, 2.5))
    p3 = N.math("MULTIPLY", phi, 3.0)
    c3, s3 = N.math("COSINE", p3), N.math("SINE", p3)
    warp = N.math("SUBTRACT", N.noise(N.math("MULTIPLY", c3, 0.9), N.math("MULTIPLY", s3, 0.9),
                                      N.math("MULTIPLY", lr, 0.8), 1.6, 3.0), 0.5)
    arms = N.math("POWER", N.math("ADD", 0.5, N.math("MULTIPLY", 0.5,
                  N.math("COSINE", N.math("ADD", p3, N.math("MULTIPLY", warp, 3.2))))), 2.8)
    # filaments: finer noise flowing along the arms
    fil = N.noise(N.math("MULTIPLY", c3, 2.2), N.math("MULTIPLY", s3, 2.2), N.math("MULTIPLY", lr, 2.4), 2.2, 6.0)
    fil = N.math("MULTIPLY", N.math("SUBTRACT", fil, 0.42), 2.2, clamp=True)
    depth = N.smooth(r, 0.0, 0.55)
    # light: a floor, the arms (brighter outside), the filaments riding them
    i_arm = N.math("MULTIPLY", arms, N.math("ADD", 0.35, N.math("MULTIPLY", depth, 0.65)))
    i_fil = N.math("MULTIPLY", N.math("MULTIPLY", fil, arms), depth)
    inten = N.math("ADD", N.math("ADD", 0.03, N.math("MULTIPLY", i_arm, 1.25)),
                   N.math("ADD", N.math("MULTIPLY", i_fil, 1.3), N.math("MULTIPLY", fil, 0.10)))
    edge = N.smooth(r, 1.0, 0.86)
    inten = N.math("MULTIPLY", inten, edge)
    col = N.scale(N.ramp(r, PAL["ramp"]), inten)
    # the gaps: a dark body colour where the light is weak, so the hole has depth
    gapw = N.math("SUBTRACT", 1.0, N.math("MULTIPLY", inten, 2.5), clamp=True)
    col = N.add(col, N.scale(PAL["gap"], gapw))
    # the eye: a hot white core
    eye = N.math("EXPONENT", N.math("MULTIPLY", N.math("POWER", N.math("DIVIDE", r, 0.15), 2.0), -1.0))
    col = N.add(col, N.scale(PAL["core"], N.math("MULTIPLY", eye, 2.2)))
    alpha = N.math("MULTIPLY", N.smooth(r, 1.0, 0.9), N.math("ADD", 0.86, N.math("MULTIPLY", inten, 0.4)), clamp=True)
    N.glow_over_clear(col, alpha)
    return m


def outer_glow_material():
    """A soft aura round the ring, fading out to the frame's edge."""
    m = bpy.data.materials.new("aura")
    N = Nodes(m)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    N.link(tc.outputs["Object"], sep.inputs[0])
    x, y = sep.outputs["X"], sep.outputs["Y"]
    r = N.math("SQRT", N.math("ADD", N.math("MULTIPLY", x, x), N.math("MULTIPLY", y, y)))
    a = N.math("MULTIPLY", N.math("POWER", N.smooth(r, 1.0, 0.70), 1.6), 0.42)
    N.glow_over_clear(N.scale(PAL["glow"], 1.6), a)
    return m


def emissive(name, colour, strength):
    m = bpy.data.materials.new(name)
    N = Nodes(m)
    out = N.new("ShaderNodeOutputMaterial")
    em = N.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    em.inputs["Strength"].default_value = strength
    N.link(em.outputs[0], out.inputs["Surface"])
    return m


# ---------------------------------------------------------------------------
# The portal (built in its own XY plane, then stood up to face the camera)
# ---------------------------------------------------------------------------

root = C.link(bpy.data.objects.new("root", None))
root.rotation_euler = (math.pi / 2, 0, 0)  # local XY faces the camera: x right, y up

rot_nodes = []
vortex = vortex_material(rot_nodes)
aura = outer_glow_material()
gold = C.principled("gold", (1.0, 0.70, 0.26), metallic=1.0, rough=0.24, emission=GOLD, estrength=0.45, spec=0.6)
gold_dark = C.principled("goldDark", (0.80, 0.52, 0.20), metallic=1.0, rough=0.3, emission=GOLD, estrength=0.12)
band_mat = C.principled("band", PAL["gap"], rough=0.55, spec=0.25, emission=PAL["gap"], estrength=0.3)
rune = emissive("rune", GOLD_HOT, 1.5)
spark = emissive("spark", GOLD_HOT, 1.9)

bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, radius=1.0, segments=128)
disc = C.mesh_object("vortex", bm, vortex, smooth=False)
disc.scale = (S.VORTEX_R, S.VORTEX_R, 1)
disc.parent = root

bm = bmesh.new()
bmesh.ops.create_circle(bm, cap_ends=True, radius=1.0, segments=128)
glow = C.mesh_object("aura", bm, aura, smooth=False)
glow.location = (0, 0, -0.08)
glow.parent = root

# the rune ring: a dark band between two gold rims, gold glyphs glowing in it
ring = C.link(bpy.data.objects.new("ring", None))
ring.parent = root
objs = []
mid = (S.RING_IN + S.RING_OUT) / 2
bm = bmesh.new()
SEG = 192
outer, inner = [], []
for i in range(SEG):
    a = 2 * math.pi * i / SEG
    outer.append(bm.verts.new((S.RING_OUT * math.cos(a), S.RING_OUT * math.sin(a), -0.01)))
    inner.append(bm.verts.new((S.RING_IN * math.cos(a), S.RING_IN * math.sin(a), -0.01)))
for i in range(SEG):
    k = (i + 1) % SEG
    bm.faces.new((inner[i], outer[i], outer[k], inner[k]))
objs.append(C.mesh_object("band", bm, band_mat, smooth=False))
objs.append(C.torus("rimOut", gold, S.RING_OUT, 0.026, seg=192, rseg=16))
objs.append(C.torus("rimIn", gold, S.RING_IN, 0.019, seg=192, rseg=16))
# a thin dark keyline just outside the gold, so the ring still reads over light ground (snow, sky)
keyline = C.principled("keyline", PAL["gap"], rough=0.6, spec=0.2)
objs.append(C.torus("keyline", keyline, S.RING_OUT + 0.030, 0.013, (0, 0, -0.03), seg=192, rseg=8))

GLYPHS = [
    # a diamond with a stem
    [[(0.0, 0.036), (0.022, 0.0), (0.0, -0.036), (-0.022, 0.0), (0.0, 0.036)], [(0.0, -0.036), (0.0, -0.05)]],
    # a stem with two chevrons
    [[(0.0, -0.04), (0.0, 0.04)], [(-0.022, 0.006), (0.0, 0.026), (0.022, 0.006)],
     [(-0.022, -0.026), (0.0, -0.006), (0.022, -0.026)]],
]
for i in range(12):
    a0 = 2 * math.pi * i / 12
    ca, sa = math.cos(a0), math.sin(a0)
    for stroke in GLYPHS[i % 2]:
        pts = []
        for (u, v) in stroke:  # u along the band, v across it (outwards)
            rr = mid + v * 0.85
            a = a0 + u / mid
            pts.append((rr * math.cos(a), rr * math.sin(a), 0.012))
        objs.append(C.tube_along("glyph%d" % i, rune, pts, 0.0105))
    # a small gold stud on the outer rim between glyph pairs (six of them: six-fold)
    if i % 2 == 1:
        a = a0 + math.pi / 12
        objs.append(C.faceted_gem("stud%d" % i, gold, 0.03, (S.RING_OUT * math.cos(a), S.RING_OUT * math.sin(a), 0.02),
                                  (0, 0, 1), 0.5, 4))
C.parent_all(ring, objs)

# the flung sparks: little hot gold beads, stretched along their flight
sparks = []
for i in range(len(S.FLUNG)):
    o = C.sphere("spark%d" % i, spark, 1.0, (0, 0, 0.05), 12)
    o.parent = root
    sparks.append(o)


def place_sparks(t):
    for o, (x, y, b, size, dx, dy) in zip(sparks, S.flung(t)):
        if b < 0.04:
            o.hide_render = True
            continue
        o.hide_render = False
        o.location = (x, y, 0.05)
        w = 0.030 * size * (0.45 + 0.55 * b)
        stretch = 1.0 + 9.0 * math.hypot(dx, dy)
        o.rotation_euler = (0, 0, math.atan2(dy, dx))
        o.scale = (w * stretch, w, w)


for f in range(FRAMES):
    if ONLY and f not in ONLY:
        continue
    t = f / FRAMES
    for n in rot_nodes:
        # the shader's phi grows with rot, so the arms turn clockwise: rot = -SWIRL_TURN * t
        n.outputs[0].default_value = -S.SWIRL_TURN * t
    ring.rotation_euler = (0, 0, S.RING_TURN * t)  # anticlockwise, against the swirl
    place_sparks(t)
    C.render_to(os.path.join(OUT, "f%02d.png" % f))
    print("emblem frame", COLOUR, f, flush=True)
