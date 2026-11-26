# Slime Rebirth — Goblin de nivel 1 (modelo de Blender)
#
# Crea el Goblin entero con código (formas orgánicas, materiales y colores de piel),
# lo guarda como .blend editable y saca imágenes de vista previa.
#
# Uso (sin abrir Blender):
#   blender -b --factory-startup --python art/goblin/build_goblin.py -- art/goblin
#
# Unidades: 1 metro de Blender = 1 stud de Roblox. Mira hacia -Y (como "Front" en Blender).
# El lado derecho del goblin es -X (lleva el garrote en la mano derecha).
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
PREVIEW = os.path.join(OUT, "previews")
os.makedirs(PREVIEW, exist_ok=True)
random.seed(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COLL = scene.collection


# --------------------------------------------------------------------------------------
# Utilidades
# --------------------------------------------------------------------------------------


def lin(r, g, b):
    """Color sRGB 0-255 -> lineal (lo que usa Blender internamente)."""

    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (f(r), f(g), f(b))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def link(name, data):
    ob = bpy.data.objects.new(name, data)
    COLL.objects.link(ob)
    return ob


def bm_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(name, me)


def smooth(ob):
    me = ob.data
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()


def bake(ob):
    """Aplica todos los modificadores (deja una malla normal)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    me.name = ob.name
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return ob


def remove(ob):
    data = ob.data
    bpy.data.objects.remove(ob)
    if data and data.users == 0 and isinstance(data, bpy.types.Mesh):
        bpy.data.meshes.remove(data)


def join(name, obs):
    verts, faces = [], []
    for o in obs:
        mw = o.matrix_world
        off = len(verts)
        verts += [mw @ v.co for v in o.data.vertices]
        faces += [[off + i for i in p.vertices] for p in o.data.polygons]
        remove(o)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    return link(name, me)


def uv_sphere(seg=32, rings=16, r=1.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    return bm


def ellipsoid(name, center, radii, rot=(0, 0, 0), seg=24, rings=12):
    bm = uv_sphere(seg, rings)
    m = Matrix.Translation(center) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*radii, 1))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm_object(name, bm)


def cone(name, base, axis, length, r1, r2=0.004, seg=10):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length)
    axis = Vector(axis).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(base) + axis * length / 2) @ rot, verts=bm.verts)
    return bm_object(name, bm)


def tube(name, pts, radius):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, pt in zip(sp.points, pts):
        p.co = (pt[0], pt[1], pt[2], 1)
    sp.use_endpoint_u = True
    sp.order_u = 3
    tmp = link(name + "_curve", cu)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    ob = link(name, me)
    smooth(ob)
    return ob


def ring(name, center, axis, radius, height, seg=48, rows=3):
    bm = bmesh.new()
    grid = []
    for r in range(rows):
        z = -height / 2 + height * r / (rows - 1)
        grid.append(
            [
                bm.verts.new((radius * math.cos(2 * math.pi * i / seg), radius * math.sin(2 * math.pi * i / seg), z))
                for i in range(seg)
            ]
        )
    for r in range(rows - 1):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]))
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rot, verts=bm.verts)
    return bm_object(name, bm)


def wrap_on(ob, target, offset, thickness, subdiv=1):
    """Pega una pieza de ropa sobre el cuerpo y le da grosor."""
    sw = ob.modifiers.new("Wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "ABOVE_SURFACE"
    sw.offset = offset
    so = ob.modifiers.new("Thick", "SOLIDIFY")
    so.thickness = thickness
    so.offset = 1
    if subdiv:
        sub = ob.modifiers.new("Sub", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    bake(ob)
    smooth(ob)
    return ob


def thicken(ob, thickness, subdiv=1):
    so = ob.modifiers.new("Thick", "SOLIDIFY")
    so.thickness = thickness
    if subdiv:
        sub = ob.modifiers.new("Sub", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    bake(ob)
    smooth(ob)
    return ob


def subdivide(ob, levels=1):
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    bake(ob)
    smooth(ob)
    return ob


def remesh(ob, voxel, target_faces):
    """Funde todas las piezas solapadas en una sola superficie suave."""
    m = ob.modifiers.new("Remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.adaptivity = 0
    s = ob.modifiers.new("Smooth", "SMOOTH")
    s.factor = 0.5
    s.iterations = 6
    bake(ob)
    count = len(ob.data.polygons)
    if count > target_faces:
        d = ob.modifiers.new("Decimate", "DECIMATE")
        d.ratio = target_faces / count
        bake(ob)
    smooth(ob)
    return ob


def ray(ob, origin, direction):
    bpy.context.view_layer.update()
    ok, loc, _nor, _i = ob.ray_cast(Vector(origin), Vector(direction).normalized())
    return loc if ok else None


def paint(ob, color_fn):
    me = ob.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        c = color_fn(v.co)
        attr.data[i].color = (c[0], c[1], c[2], 1.0)


def skin_object(name, nodes, edges, subdiv=2):
    """Cuerpo de una pieza a partir de un "esqueleto" de puntos con grosor (modificador Skin)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([n[0] for n in nodes], edges, [])
    ob = link(name, me)
    mod = ob.modifiers.new("Skin", "SKIN")
    if len(me.skin_vertices) == 0:
        ob.modifiers.remove(mod)
        bpy.context.view_layer.objects.active = ob
        with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
            bpy.ops.object.modifier_add(type="SKIN")
        mod = ob.modifiers[-1]
    mod.use_smooth_shade = True
    mod.branch_smoothing = 0.3
    data = me.skin_vertices[0].data
    for i, n in enumerate(nodes):
        r = n[1]
        data[i].radius = (r, r) if isinstance(r, (int, float)) else r
        data[i].use_root = i == 0
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = subdiv
    sub.render_levels = subdiv
    return ob


# --------------------------------------------------------------------------------------
# Materiales
# --------------------------------------------------------------------------------------


def material(name, color=None, rough=0.6, vertex_color=False, sss=0.0, emission=0.0, bump=None, metallic=0.0):
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    if vertex_color:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = "Col"
        nt.links.new(a.outputs["Color"], p.inputs["Base Color"])
    else:
        p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    if sss:
        p.inputs["Subsurface Weight"].default_value = sss
        p.inputs["Subsurface Scale"].default_value = 0.04
    if emission and color:
        p.inputs["Emission Color"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emission
    if bump:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = bump[0]
        tex.inputs["Detail"].default_value = 6
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump[1]
        nt.links.new(tex.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


def outline_material():
    """Contorno de estilo anime (casco invertido): solo se ve el borde de la silueta."""
    m = bpy.data.materials.new("Outline")
    if m.node_tree is None:
        m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin(28, 34, 18), 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mx.inputs["Fac"])
    nt.links.new(em.outputs["Emission"], mx.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mx.inputs[2])
    nt.links.new(mx.outputs["Shader"], out.inputs["Surface"])
    return m


SKIN = material("Skin", vertex_color=True, rough=0.55, sss=0.12, bump=(70, 0.05))
INNER_EAR = material("InnerEar", lin(176, 118, 96), rough=0.6, sss=0.2)
CLOTH = material("Cloth", lin(150, 118, 78), rough=0.95, bump=(160, 0.25))
CLOTH_DARK = material("ClothDark", lin(112, 84, 58), rough=0.95, bump=(160, 0.25))
LEATHER = material("Leather", lin(78, 48, 28), rough=0.45, bump=(45, 0.12))
METAL = material("Metal", lin(120, 112, 98), rough=0.4, metallic=0.8)
BANDAGE = material("Bandage", lin(222, 212, 188), rough=0.9, bump=(200, 0.2))
WOOD = material("Wood", lin(112, 74, 44), rough=0.8, bump=(18, 0.35))
WOOD_DARK = material("WoodDark", lin(80, 52, 30), rough=0.8, bump=(18, 0.35))
HAIR = material("Hair", lin(98, 82, 66), rough=0.7, bump=(40, 0.15))
IVORY = material("Ivory", lin(236, 228, 204), rough=0.35)
CLAW = material("Claw", lin(70, 58, 44), rough=0.4)
SCLERA = material("Sclera", lin(240, 238, 226), rough=0.15)
IRIS = material("Iris", lin(236, 180, 40), rough=0.2, emission=0.25)
IRIS_RIM = material("IrisRim", lin(150, 82, 18), rough=0.2)
PUPIL = material("Pupil", lin(14, 10, 6), rough=0.1)
SHINE = material("Shine", (1, 1, 1), rough=0.1, emission=4)
LINE = material("Line", lin(30, 20, 14), rough=0.6)
OUTLINE = outline_material()


def eyeball_material():
    """Ojo de anime: blanco, borde del iris oscuro, iris ámbar con degradado, pupila y brillo."""
    m = bpy.data.materials.new("EyeBall")
    if m.node_tree is None:
        m.use_nodes = True
    nt = m.node_tree
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Roughness"].default_value = 0.12
    coord = nt.nodes.new("ShaderNodeTexCoord")
    norm = nt.nodes.new("ShaderNodeVectorMath")
    norm.operation = "NORMALIZE"
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = (0, -1, 0)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    stops = (
        (0.0, lin(240, 238, 226)),
        (0.735, lin(240, 238, 226)),
        (0.742, lin(120, 64, 14)),
        (0.775, lin(176, 100, 20)),
        (0.86, lin(236, 172, 40)),
        (0.935, lin(250, 214, 96)),
        (0.94, lin(12, 8, 4)),
        (1.0, lin(12, 8, 4)),
    )
    els = ramp.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, col) in zip(els, stops):
        el.position = pos
        el.color = (*col, 1)
    nt.links.new(coord.outputs["Object"], norm.inputs[0])
    nt.links.new(norm.outputs["Vector"], dot.inputs[0])
    nt.links.new(dot.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    return m


EYEBALL = eyeball_material()


def give(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


OUTLINED = []


def outline(ob, thickness=0.011):
    OUTLINED.append((ob, thickness))
    return ob


def build_outlines():
    for ob, t in OUTLINED:
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * t
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        for f in bm.faces:
            f.material_index = 0
        o = bm_object(ob.name + "_Outline", bm)
        give(o, OUTLINE)
        smooth(o)
        o.parent = ob.parent


# --------------------------------------------------------------------------------------
# Paleta de piel (variación de tono)
# --------------------------------------------------------------------------------------

SKIN_BASE = lin(118, 154, 66)
SKIN_DARK = lin(74, 104, 42)
SKIN_LIGHT = lin(156, 176, 92)
SKIN_WARM = lin(150, 150, 70)


def mottle(p, amount=0.14):
    n = noise.noise(Vector(p) * 5.0)
    return mix(SKIN_BASE, SKIN_DARK, 0.18 + amount * n)


# --------------------------------------------------------------------------------------
# Cuerpo (una sola pieza)
# --------------------------------------------------------------------------------------

nodes, edges, N = [], [], {}


def node(name, pos, r):
    N[name] = len(nodes)
    nodes.append((Vector(pos), r))


def bone(a, b):
    edges.append((N[a], N[b]))


def chain(*names):
    for a, b in zip(names, names[1:]):
        bone(a, b)


# Columna encorvada hacia delante
node("pelvis", (0, 0.02, 1.36), (0.25, 0.21))
node("belly", (0, -0.02, 1.64), (0.25, 0.22))
node("chest", (0, -0.1, 1.95), (0.26, 0.19))
node("upper", (0, -0.2, 2.12), (0.24, 0.17))
node("neck", (0, -0.32, 2.34), 0.11)
chain("pelvis", "belly", "chest", "upper", "neck")

HAND = {}
for side, s in ((1, "L"), (-1, "R")):
    # Brazos cortos colgando hacia delante
    node("sh" + s, (side * 0.32, -0.16, 2.1), 0.12)
    node("el" + s, (side * 0.42, -0.21, 1.74), 0.082)
    node("wr" + s, (side * 0.47, -0.33, 1.38), 0.06)
    node("ha" + s, (side * 0.49, -0.38, 1.24), (0.09, 0.075))
    chain("upper", "sh" + s, "el" + s, "wr" + s, "ha" + s)
    HAND[side] = nodes[N["ha" + s]][0]
    hand = HAND[side]
    if side > 0:
        # Mano izquierda abierta con dedos algo doblados (garras)
        for k, dx in enumerate((-0.045, 0.0, 0.045)):
            node(f"f{k}a{s}", hand + Vector((dx, -0.05, -0.1)), 0.03)
            node(f"f{k}b{s}", hand + Vector((dx * 1.1, -0.11, -0.15)), 0.024)
            chain("ha" + s, f"f{k}a{s}", f"f{k}b{s}")
        node("th" + s, hand + Vector((-side * 0.07, -0.08, -0.03)), 0.028)
        bone("ha" + s, "th" + s)
    else:
        # Mano derecha cerrada alrededor del garrote
        for k, dx in enumerate((-0.04, 0.0, 0.04)):
            node(f"f{k}a{s}", hand + Vector((dx, -0.07, -0.06)), 0.034)
            chain("ha" + s, f"f{k}a{s}")
        node("th" + s, hand + Vector((-side * 0.07, -0.06, 0.0)), 0.03)
        bone("ha" + s, "th" + s)

    # Piernas cortas con las rodillas dobladas y pies grandes
    node("hip" + s, (side * 0.16, 0.02, 1.24), 0.14)
    node("thi" + s, (side * 0.21, -0.09, 1.01), 0.135)
    node("kn" + s, (side * 0.24, -0.2, 0.78), 0.095)
    node("ca" + s, (side * 0.235, -0.08, 0.5), 0.1)
    node("an" + s, (side * 0.225, 0.04, 0.21), 0.065)
    node("he" + s, (side * 0.225, 0.1, 0.08), 0.07)
    node("ba" + s, (side * 0.23, -0.14, 0.07), (0.1, 0.055))
    chain("pelvis", "hip" + s, "thi" + s, "kn" + s, "ca" + s, "an" + s, "he" + s)
    bone("an" + s, "ba" + s)
    for k, dx in enumerate((-0.07, 0.0, 0.07)):
        node(f"t{k}a{s}", (side * 0.23 + dx, -0.25, 0.055), 0.045)
        node(f"t{k}b{s}", (side * 0.23 + dx * 1.15, -0.34, 0.045), 0.035)
        chain("ba" + s, f"t{k}a{s}", f"t{k}b{s}")

body = skin_object("Body", nodes, edges, subdiv=2)
bake(body)
smooth(body)


def body_color(p):
    c = mottle(p)
    # Barriga y pecho más claros, manos y pies más oscuros
    if p.y < -0.05:
        c = mix(c, SKIN_LIGHT, 0.45 * math.exp(-(((p.z - 1.7) / 0.35) ** 2)) * min(1, (-p.y - 0.05) / 0.15))
    extremity = max(math.exp(-((p.z / 0.25) ** 2)), *[math.exp(-(((p - HAND[s]).length / 0.2) ** 2)) for s in (1, -1)])
    return mix(c, SKIN_DARK, 0.55 * extremity)


paint(body, body_color)
give(body, SKIN)
outline(body)

# Garras de los pies y de la mano izquierda
claws = []
for side in (1, -1):
    for dx in (-0.07, 0.0, 0.07):
        tip = Vector((side * 0.23 + dx * 1.15, -0.355, 0.04))
        claws.append(cone("Claw", tip, (0, -1, -0.35), 0.065, 0.028))
for dx in (-0.045, 0.0, 0.045):
    tip = HAND[1] + Vector((dx * 1.1, -0.13, -0.17))
    claws.append(cone("Claw", tip, (0, -0.5, -1), 0.05, 0.02))
give(join("Claws", claws), CLAW)

# --------------------------------------------------------------------------------------
# Cabeza (orejas, nariz, cejas y mejillas fundidas en una sola pieza)
# --------------------------------------------------------------------------------------

C = Vector((0, -0.44, 2.8))  # centro de la cabeza

bm = uv_sphere(64, 32)
for v in bm.verts:
    x, y, z = v.co
    X = x * 0.57
    Y = y * 0.5
    Z = z * 0.56
    if z < -0.1:  # mandíbula ancha
        X *= 1 + 0.12 * min(1, (-z - 0.1) / 0.4)
    if y < 0:  # boca y mandíbula salidas hacia delante
        Y -= 0.17 * (-y) * math.exp(-(((z + 0.4) / 0.4) ** 2))
    if y < 0 and z > 0.25:  # frente inclinada hacia atrás
        Y += 0.1 * (z - 0.25) * (-y)
    if z > 0:
        Z *= 0.92
    if y > 0 and z > -0.2:  # cráneo más grande por detrás
        Y += 0.1 * y * (z + 0.2)
    if z < -0.65:  # barbilla más estrecha
        X *= 1 - 0.6 * (-z - 0.65)
    v.co = C + Vector((X, Y, Z))
head_base = bm_object("HeadBase", bm)


def face_point(x, z, ob=None):
    p = ray(ob or head_base, (x, C.y - 3, z), (0, 1, 0))
    return p if p is not None else Vector((x, C.y - 0.55, z))


parts = [head_base]
# Nariz grande, ancha y redondeada
nose_tip = face_point(0, C.z - 0.04)
nose_center = nose_tip + Vector((0, -0.11, -0.06))
parts.append(ellipsoid("Nose", nose_center, (0.14, 0.15, 0.12), rot=(math.radians(25), 0, 0)))
for side in (1, -1):
    parts.append(ellipsoid("Nostril", nose_center + Vector((side * 0.1, 0.04, -0.04)), (0.08, 0.07, 0.065)))
bridge = face_point(0, C.z + 0.12)
parts.append(ellipsoid("Bridge", bridge + Vector((0, 0.0, -0.02)), (0.07, 0.06, 0.17), rot=(math.radians(-30), 0, 0)))
for side in (1, -1):
    # Cejas inclinadas (más altas por dentro): cara de goblin nervioso
    brow = face_point(side * 0.2, C.z + 0.27)
    parts.append(
        ellipsoid("Brow", brow + Vector((0, 0.02, 0)), (0.16, 0.06, 0.05), rot=(0, math.radians(side * 20), 0))
    )
chin = face_point(0, C.z - 0.42)
parts.append(ellipsoid("Chin", chin + Vector((0, 0.03, 0)), (0.1, 0.07, 0.07)))

EAR_ROOT_X, EAR_L = 0.45, 0.85


def ear_point(side, a, y, z, inner=False):
    """Forma de la oreja: a = 0 en la raíz y 1 en la punta."""
    h = 0.23 * (1 - a**1.5) + 0.006
    t = 0.055 * (1 - 0.5 * a)
    X = a * EAR_L
    Z = z * h + 0.3 * a * a
    if inner:
        Y = -t + 0.032 * math.sin(math.pi * a) - 0.004 + y * 0.006
    else:
        Y = y * t
        if y < 0:  # hueco de la oreja
            Y += 0.032 * (1 - abs(z)) * math.sin(math.pi * a)
    Y += 0.16 * a * a  # la punta va un poco hacia atrás
    return Vector((side * (EAR_ROOT_X + X), C.y + 0.08 + Y, C.z + 0.06 + Z))


for side in (1, -1):
    bm = uv_sphere(32, 16)
    for v in bm.verts:
        x, y, z = v.co
        v.co = ear_point(side, (x + 1) / 2, y, z)
    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    parts.append(bm_object("Ear", bm))

head = join("Head", parts)
remesh(head, 0.012, 9000)
EAR_TIP_X = EAR_ROOT_X + EAR_L


def head_color(p):
    c = mottle(p)
    c = mix(c, SKIN_DARK, 0.6 * math.exp(-(((p - nose_center).length / 0.17) ** 2)))  # nariz más oscura
    c = mix(c, SKIN_DARK, 0.6 * max(0, (abs(p.x) - 0.75) / (EAR_TIP_X - 0.75)))  # puntas de las orejas
    c = mix(c, SKIN_DARK, 0.35 * max(0, min(1, (p.z - (C.z + 0.25)) / 0.3)))  # coronilla
    for side in (1, -1):
        cheek = Vector((side * 0.3, C.y - 0.45, C.z - 0.12))
        c = mix(c, SKIN_WARM, 0.35 * math.exp(-(((p - cheek).length / 0.13) ** 2)))
    return c


paint(head, head_color)
give(head, SKIN)
outline(head)

# Interior de las orejas
inner = []
for side in (1, -1):
    bm = uv_sphere(24, 12)
    for v in bm.verts:
        x, y, z = v.co
        a = 0.1 + 0.75 * (x + 1) / 2
        p = ear_point(side, a, y, z * 0.6, inner=True)
        v.co = p
    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    inner.append(bm_object("InnerEar", bm))
inner_ears = give(join("InnerEars", inner), INNER_EAR)
smooth(inner_ears)

# --------------------------------------------------------------------------------------
# Ojos grandes de estilo anime, párpados, boca y colmillos
# --------------------------------------------------------------------------------------

EYE_R = 0.125
eye_parts = {"Shine": [], "Lid": [], "Lash": []}
for side in (1, -1):
    hit = face_point(side * 0.21, C.z + 0.1, head)
    center = hit + Vector((0, 0.055, 0))
    m_eye = Matrix.Translation(center) @ Matrix.Diagonal((1, 1, 1.15, 1))

    # Globo ocular: el iris y la pupila los dibuja el material (bordes limpios).
    # El objeto mira hacia donde mira el ojo (su -Y local), un poco hacia dentro.
    look = Vector((side * -0.08, -1, -0.05)).normalized()
    bm = uv_sphere(48, 24, EYE_R)
    bmesh.ops.transform(bm, matrix=Matrix.Diagonal((1, 1, 1.15, 1)), verts=bm.verts)
    eyeball = bm_object("Eye" + ("L" if side > 0 else "R"), bm)
    eyeball.location = center
    eyeball.rotation_mode = "QUATERNION"
    eyeball.rotation_quaternion = Vector((0, -1, 0)).rotation_difference(look)
    give(eyeball, EYEBALL)
    smooth(eyeball)
    shine = (look + Vector((side * 0.25, 0, 0.35))).normalized() * EYE_R * 1.03
    eye_parts["Shine"].append(ellipsoid("Shine", m_eye @ shine, (0.022, 0.012, 0.022)))

    # Párpado superior (inclinado: más alto por dentro) y línea de pestañas
    lid_r, cut = EYE_R * 1.08, 0.58
    m_lid = (
        Matrix.Translation(center)
        @ Euler((math.radians(-4), math.radians(side * 20), 0)).to_matrix().to_4x4()
        @ Matrix.Diagonal((1, 1, 1.15, 1))
    )
    bm = uv_sphere(40, 20, lid_r)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < cut * lid_r], context="VERTS")
    bmesh.ops.transform(bm, matrix=m_lid, verts=bm.verts)
    lid = bm_object("Lid", bm)
    thicken(lid, 0.012, subdiv=0)
    eye_parts["Lid"].append(lid)
    rr = math.sqrt(1 - cut * cut) * lid_r * 1.02
    pts = [
        m_lid @ Vector((rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), cut * lid_r))
        for a in range(200, 345, 8)
    ]
    eye_parts["Lash"].append(tube("Lash", pts, 0.013))

for key, mat in (("Shine", SHINE), ("Lash", LINE)):
    ob = give(join("Eye" + key, eye_parts[key]), mat)
    smooth(ob)
lids = join("Lids", eye_parts["Lid"])
smooth(lids)
paint(lids, lambda p: mix(SKIN_BASE, SKIN_DARK, 0.3))
give(lids, SKIN)

# Boca ancha (algo caída en las comisuras) y dos colmillos pequeños hacia arriba
mouth_pts = []
for i in range(9):
    x = -0.25 + 0.5 * i / 8
    z = C.z - 0.29 + 0.035 * (x / 0.25) ** 2 + 0.02 * (x / 0.25)
    mouth_pts.append(face_point(x, z, head) + Vector((0, 0.006, 0)))
give(tube("Mouth", mouth_pts, 0.016), LINE)
fangs = []
for side in (1, -1):
    fx = side * 0.13
    base = face_point(fx, C.z - 0.33 + 0.035 * (fx / 0.25) ** 2 + 0.02 * (fx / 0.25), head) + Vector((0, -0.025, 0))
    fangs.append(cone("Fang", base, (side * 0.15, -0.35, 1), 0.12, 0.038, seg=12))
fangs_ob = give(join("Fangs", fangs), IVORY)
subdivide(fangs_ob, 1)

# Pelo despeinado: mechones curvados que se afinan, de la coronilla hacia atrás,
# con algunos cayendo sobre la frente
def lock(name, start, direction, length, radius, bend):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    count = 6
    sp.points.add(count - 1)
    p, d = Vector(start), Vector(direction).normalized()
    for i, point in enumerate(sp.points):
        point.co = (p.x, p.y, p.z, 1)
        point.radius = max(0.06, (1 - i / (count - 1)) ** 0.8)
        d = (d + bend).normalized()
        p = p + d * length / (count - 1)
    sp.use_endpoint_u = True
    sp.order_u = 4
    tmp = link(name + "_curve", cu)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    return link(name, me)


locks = []
gravity = Vector((0, 0.12, -0.16))
for el, az, length, radius in (
    (85, 0, 0.62, 0.13),
    (72, 35, 0.58, 0.12),
    (72, -35, 0.6, 0.12),
    (70, 0, 0.6, 0.13),
    (60, 70, 0.5, 0.11),
    (60, -70, 0.52, 0.11),
    (55, 20, 0.62, 0.12),
    (55, -20, 0.6, 0.12),
    (45, 45, 0.5, 0.11),
    (45, -45, 0.5, 0.11),
    (38, 5, 0.52, 0.12),
    (30, 30, 0.42, 0.1),
    (30, -30, 0.42, 0.1),
    (75, 120, 0.45, 0.1),
    (75, -120, 0.42, 0.1),
    (68, 150, 0.4, 0.09),
    (66, -155, 0.42, 0.09),
    (78, 170, 0.36, 0.09),
):
    e, a = math.radians(el), math.radians(az)
    d = Vector((math.cos(e) * math.sin(a), math.cos(e) * math.cos(a), math.sin(e)))
    p = ray(head, C + d * 2.5, -d) or (C + d * 0.5)
    front = abs(az) > 100  # mechones de delante: caen sobre la frente
    up = d + Vector((0, 0.35, 0.5)) if not front else d + Vector((0, -0.1, 0.6))
    up += Vector([random.uniform(-0.25, 0.25) for _ in range(3)])
    bend = gravity if not front else Vector((random.uniform(-0.1, 0.1), -0.08, -0.22))
    locks.append(lock("Lock", p - d * 0.1, up, length, radius, bend))
hair = give(join("Hair", locks), HAIR)
smooth(hair)
outline(hair, 0.008)

# --------------------------------------------------------------------------------------
# Ropa: cinturón, bolsa, taparrabos, tira de tela en el pecho y vendas
# --------------------------------------------------------------------------------------

belt = ring("Belt", (0, -0.01, 1.5), (0, -0.12, 1), 0.45, 0.11)
wrap_on(belt, body, 0.012, 0.035)
give(belt, LEATHER)
outline(belt)
buckle_hit = ray(belt, (0, -2, 1.48), (0, 1, 0)) or Vector((0, -0.25, 1.48))
give(ellipsoid("Buckle", buckle_hit + Vector((0, 0.005, 0)), (0.07, 0.025, 0.055)), METAL)
pouch = give(ellipsoid("Pouch", (0.29, -0.05, 1.36), (0.08, 0.065, 0.1), rot=(0, 0, math.radians(20))), LEATHER)
smooth(pouch)
outline(pouch)


def flap(name, front):
    s = -1 if front else 1
    cols, rows = 9, 10
    W, H = 0.44 if front else 0.48, 0.6 if front else 0.52
    verts, faces = [], []
    for r in range(rows):
        t = r / (rows - 1)
        for c in range(cols):
            u = c / (cols - 1) * 2 - 1
            x = u * W / 2 * (1 + 0.15 * t)
            z = 1.47 - t * H
            if r == rows - 1:  # borde roto e irregular
                z += 0.05 * abs(math.sin(u * 7.3)) + random.uniform(-0.03, 0.02)
            y = s * ((0.21 + 0.08 * t) if front else (0.215 + 0.025 * t)) * (1 - 0.3 * u * u)
            y += 0.012 * math.sin(u * 6 + t * 4)
            verts.append((x, y, z))
    for r in range(rows - 1):
        for c in range(cols - 1):
            i = r * cols + c
            faces.append((i, i + 1, i + cols + 1, i + cols))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    ob = link(name, me)
    thicken(ob, 0.022, subdiv=1)
    return ob


loin_front = give(flap("LoinFront", True), CLOTH)
loin_back = give(flap("LoinBack", False), CLOTH_DARK)
outline(loin_front)
outline(loin_back)

tilt = math.radians(40)
sash = ring("Sash", (0, -0.12, 1.95), (math.tan(tilt), 0, 1), 0.55, 0.17, rows=4)
wrap_on(sash, body, 0.015, 0.025)
give(sash, CLOTH_DARK)
outline(sash)

wraps = []
for side, s in ((1, "L"), (-1, "R")):
    el, wr = nodes[N["el" + s]][0], nodes[N["wr" + s]][0]
    for t in (0.5, 0.62, 0.74, 0.88):
        axis = (wr - el) + Vector([random.uniform(-0.08, 0.08) for _ in range(3)])
        wraps.append(ring("Wrap", el.lerp(wr, t), axis, 0.15, 0.055, seg=32, rows=2))
kn, an = nodes[N["knR"]][0], nodes[N["anR"]][0]
for t in (0.45, 0.6):
    wraps.append(ring("Wrap", kn.lerp(an, t), (an - kn) + Vector((0.05, 0, 0)), 0.16, 0.06, seg=32, rows=2))
bandages = join("Bandages", wraps)
wrap_on(bandages, body, 0.008, 0.018)
give(bandages, BANDAGE)
outline(bandages, 0.008)

# --------------------------------------------------------------------------------------
# Garrote de madera tosco en la mano derecha
# --------------------------------------------------------------------------------------

grip = HAND[-1]
d = Vector((-0.05, -0.55, -0.83)).normalized()
side_vec = d.cross(Vector((1, 0, 0))).normalized()
up_vec = d.cross(side_vec).normalized()
club_nodes, club_edges = [], []
for i, (t, r) in enumerate(
    ((-0.14, 0.05), (-0.08, 0.055), (0.0, 0.045), (0.2, 0.05), (0.45, 0.056), (0.7, 0.075), (0.9, 0.12), (1.08, 0.15), (1.24, 0.145), (1.33, 0.1))
):
    club_nodes.append((grip + d * t, r))
    if i:
        club_edges.append((i - 1, i))
for t, offset in ((0.98, side_vec * 0.14), (1.15, up_vec * 0.15), (1.2, -side_vec * 0.13)):
    club_nodes.append((grip + d * t + offset, 0.05))
    club_edges.append((7, len(club_nodes) - 1))
club = skin_object("Club", club_nodes, club_edges, subdiv=2)
tex = bpy.data.textures.new("ClubNoise", "CLOUDS")
tex.noise_scale = 0.12
disp = club.modifiers.new("Rough", "DISPLACE")
disp.texture = tex
disp.strength = 0.035
bake(club)
smooth(club)
give(club, WOOD)
outline(club)
# Tiras de cuero en el mango
grip_wrap = join(
    "ClubGrip",
    [ring("Grip", grip + d * t, d, 0.08, 0.04, seg=24, rows=2) for t in (-0.11, -0.06)],
)
wrap_on(grip_wrap, club, 0.006, 0.016, subdiv=1)
give(grip_wrap, LEATHER)

build_outlines()

# --------------------------------------------------------------------------------------
# Escena de vista previa
# --------------------------------------------------------------------------------------

world = bpy.data.worlds.new("World")
scene.world = world
if world.node_tree is None:
    world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (*lin(190, 205, 215), 1)
bg.inputs["Strength"].default_value = 0.6

ground_bm = bmesh.new()
bmesh.ops.create_grid(ground_bm, x_segments=1, y_segments=1, size=12)
ground = give(bm_object("Ground", ground_bm), material("Ground", lin(150, 160, 135), rough=0.95))


def aim(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()


for name, loc, energy, size in (
    ("Key", (-4, -6, 6.5), 900, 4),
    ("Fill", (5, -4, 3), 300, 5),
    ("Rim", (2, 6, 5), 700, 3),
):
    light = bpy.data.lights.new(name, "AREA")
    light.energy = energy
    light.size = size
    ob = link(name, light)
    ob.location = loc
    aim(ob, (0, -0.2, 1.8))

scene.render.resolution_x = 900
scene.render.resolution_y = 1100
scene.render.film_transparent = False
engine = None
for candidate in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = candidate
        engine = candidate
        break
    except TypeError:
        pass
try:
    scene.eevee.taa_render_samples = 64
except AttributeError:
    pass

# Guardar el proyecto editable antes de renderizar
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "goblin_v1.blend"))

total = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.name != "Ground")
outline_faces = sum(
    len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_Outline")
)
print(f"[goblin] caras totales: {total} (contornos: {outline_faces})")


def render(name, loc, target, scale):
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = scale
    cam_data.clip_end = 100
    cam = link(name, cam_data)
    cam.location = loc
    aim(cam, target)
    scene.camera = cam
    scene.render.filepath = os.path.join(PREVIEW, name + ".png")
    try:
        bpy.ops.render.render(write_still=True)
    except RuntimeError as err:
        print("[goblin] EEVEE falló, uso Cycles:", err)
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 48
        bpy.ops.render.render(write_still=True)


render("front", (0, -12, 1.9), (0, 0, 1.9), 4.3)
render("three_quarter", (-7.5, -9.5, 3.4), (0, -0.2, 1.85), 4.3)
render("side", (12, 0, 1.9), (0, -0.2, 1.9), 4.3)
render("head", (-3.5, -8, 3.6), C, 1.9)
print("[goblin] listo")
