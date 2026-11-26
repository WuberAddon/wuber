"""Shared Blender (bpy 5.x) helpers for Wuber's effect renders: a clean scene, Cycles on the
CPU, a studio light rig in the author's violet-and-gold look, materials, and mesh builders.

Imported by crown_blend.py, badges_blend.py and coin_blend.py (run as plain Python with the
`bpy` module installed: pip install bpy --break-system-packages)."""
import math

import bpy  # noqa: I001 (bpy first: it provides bmesh and mathutils)
import bmesh
from mathutils import Matrix, Vector


def reset_scene(res=240, samples=40):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.max_bounces = 8
    sc.cycles.transmission_bounces = 6
    sc.cycles.glossy_bounces = 4
    try:
        sc.cycles.use_denoising = True
        sc.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except Exception:
        pass
    sc.view_settings.exposure = 0.0
    return sc


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def studio_world(strength=1.0):
    """An environment the metal can reflect: dark violet floor, a violet horizon, two bright
    warm studio strips and a cool top. Invisible in the render (transparent film)."""
    world = bpy.data.worlds.new("studio")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    mr = nt.nodes.new("ShaderNodeMapRange")   # direction z: -1..1 -> 0..1
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    cr = ramp.color_ramp
    cr.interpolation = "LINEAR"
    stops = [
        (0.00, (0.05, 0.02, 0.09, 1)),
        (0.30, (0.25, 0.10, 0.45, 1)),
        (0.38, (2.6, 2.0, 1.2, 1)),      # warm floor bounce strip
        (0.42, (0.20, 0.08, 0.32, 1)),
        (0.50, (0.70, 0.35, 1.10, 1)),   # violet horizon
        (0.56, (0.15, 0.07, 0.24, 1)),
        (0.64, (4.0, 3.2, 2.0, 1)),      # warm studio strip
        (0.70, (0.15, 0.09, 0.22, 1)),
        (0.84, (0.25, 0.18, 0.40, 1)),
        (0.90, (3.0, 2.8, 3.2, 1)),      # top strip
        (1.00, (0.9, 0.85, 1.1, 1)),
    ]
    cr.elements[0].position, cr.elements[0].color = stops[0]
    cr.elements[1].position, cr.elements[1].color = stops[-1]
    for pos, col in stops[1:-1]:
        e = cr.elements.new(pos)
        e.color = col
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    return world


def area_light(name, loc, target, energy, color, size):
    l = bpy.data.lights.new(name, "AREA")
    l.energy = energy
    l.color = color
    l.size = size
    o = link(bpy.data.objects.new(name, l))
    o.location = loc
    look_at(o, target)
    return o


def point_light(name, loc, energy, color, radius=0.05):
    l = bpy.data.lights.new(name, "POINT")
    l.energy = energy
    l.color = color
    l.shadow_soft_size = radius
    o = link(bpy.data.objects.new(name, l))
    o.location = loc
    return o


def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def studio_lights(scale=1.0):
    s = scale
    area_light("key", (-3 * s, -4.5 * s, 4 * s), (0, 0, 0.5 * s), 900 * s * s, (1.0, 0.92, 0.8), 2.5 * s)
    area_light("fill", (4 * s, -3 * s, 1.5 * s), (0, 0, 0.5 * s), 260 * s * s, (0.75, 0.55, 1.0), 3.0 * s)
    area_light("rimL", (-3.5 * s, 3.5 * s, 2.5 * s), (0, 0, 0.6 * s), 700 * s * s, (0.85, 0.35, 1.0), 1.2 * s)
    area_light("rimR", (3.5 * s, 3.0 * s, 3.0 * s), (0, 0, 0.6 * s), 600 * s * s, (0.55, 0.3, 1.0), 1.2 * s)
    area_light("top", (0, -0.5 * s, 6 * s), (0, 0, 0), 300 * s * s, (1.0, 0.95, 0.9), 2.0 * s)
    # small hard lights: the sparkling glints on edges and gems
    point_light("glintA", (-1.6 * s, -3.2 * s, 2.6 * s), 120 * s * s, (1.0, 0.97, 0.9), 0.02)
    point_light("glintB", (2.0 * s, -2.6 * s, 2.2 * s), 70 * s * s, (1.0, 0.85, 1.0), 0.02)


def camera(loc, target, lens=50, ortho=None):
    cam = bpy.data.cameras.new("cam")
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    else:
        cam.lens = lens
    o = link(bpy.data.objects.new("cam", cam))
    o.location = loc
    look_at(o, target)
    bpy.context.scene.camera = o
    return o


def _set(bsdf, name, value):
    if name in bsdf.inputs:
        bsdf.inputs[name].default_value = value


def principled(name, base, metallic=0.0, rough=0.4, emission=None, estrength=0.0, transmission=0.0,
               ior=1.45, coat=0.0, sheen=0.0, sheen_tint=None, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    _set(b, "Base Color", (*base, 1))
    _set(b, "Metallic", metallic)
    _set(b, "Roughness", rough)
    _set(b, "IOR", ior)
    _set(b, "Specular IOR Level", spec)
    _set(b, "Transmission Weight", transmission)
    _set(b, "Coat Weight", coat)
    _set(b, "Coat Roughness", 0.05)
    _set(b, "Sheen Weight", sheen)
    if sheen_tint:
        _set(b, "Sheen Tint", (*sheen_tint, 1))
    if emission:
        _set(b, "Emission Color", (*emission, 1))
        _set(b, "Emission Strength", estrength)
    return m


def gold_material(name="gold", rough=0.2, tint=(1.0, 0.70, 0.26)):
    return principled(name, tint, metallic=1.0, rough=rough, spec=0.6)


def gem_material(name, color, glow=0.9):
    return principled(name, color, rough=0.02, transmission=0.85, ior=2.1, emission=color,
                      estrength=glow, coat=1.0, spec=1.0)


def mesh_object(name, bm, mat=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o = link(bpy.data.objects.new(name, me))
    if mat:
        o.data.materials.append(mat)
    return o


def faceted_gem(name, mat, size, loc, normal, flat=0.45, segs=8):
    """A cut gem: a low-poly flattened sphere with flat facets, facing `normal`."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=5, radius=1.0)
    for v in bm.verts:
        v.co.z *= flat
    o = mesh_object(name, bm, mat, smooth=False)
    o.scale = (size, size, size)
    n = Vector(normal).normalized()
    o.rotation_euler = n.to_track_quat("Z", "Y").to_euler()
    o.location = loc
    return o


def sphere(name, mat, radius, loc, segs=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=segs // 2, radius=radius)
    o = mesh_object(name, bm, mat)
    o.location = loc
    return o


def torus(name, mat, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), seg=96, rseg=16):
    bm = bmesh.new()
    verts = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            r = major + minor * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), minor * math.sin(b))))
        verts.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = verts[i][j], verts[i][(j + 1) % rseg]
            c, d = verts[(i + 1) % seg][(j + 1) % rseg], verts[(i + 1) % seg][j]
            bm.faces.new((a, b, c, d))
    o = mesh_object(name, bm, mat)
    o.location = loc
    o.rotation_euler = rot
    return o


def tube_along(name, mat, points, radius, seg=12):
    """A round tube through a list of 3D points (bevelled poly curve)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    o = link(bpy.data.objects.new(name, cu))
    o.data.materials.append(mat)
    return o


def outline_object(name, mat, loops, extrude, bevel):
    """A flat shape from closed 2D loops (holes by even-odd), extruded, in its XY plane."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 3
    for loop in loops:
        sp = cu.splines.new("POLY")
        sp.points.add(len(loop) - 1)
        for i, (x, y) in enumerate(loop):
            sp.points[i].co = (x, y, 0, 1)
        sp.use_cyclic_u = True
    o = link(bpy.data.objects.new(name, cu))
    o.data.materials.append(mat)
    return o


def render_to(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def parent_all(root, objs):
    for o in objs:
        if o is root:
            continue
        o.parent = root
