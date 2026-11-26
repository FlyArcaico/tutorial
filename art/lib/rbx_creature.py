# Slime Rebirth — biblioteca común para crear monstruos en Blender y llevarlos a Roblox.
#
# La usan los scripts de cada monstruo (por ejemplo art/goblin_warrior/build_goblin_warrior.py).
# (El Goblin de nivel 1 tiene su propio script, aprobado, y no usa esta biblioteca.)
#
# Convenios: 1 unidad de Blender = 1 stud. El monstruo mira hacia -Y, arriba es +Z y su lado
# derecho es -X. El suelo es z = 0.
import math
import os

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

R15_PARTS = [
    "LowerTorso",
    "UpperTorso",
    "Head",
    "LeftUpperArm",
    "LeftLowerArm",
    "LeftHand",
    "RightUpperArm",
    "RightLowerArm",
    "RightHand",
    "LeftUpperLeg",
    "LeftLowerLeg",
    "LeftFoot",
    "RightUpperLeg",
    "RightLowerLeg",
    "RightFoot",
]


def scene():
    return bpy.context.scene


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# --------------------------------------------------------------------------------------
# Colores y objetos
# --------------------------------------------------------------------------------------


def lin(r, g, b):
    """Color sRGB 0-255 -> lineal."""

    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (f(r), f(g), f(b))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def link(name, data):
    ob = bpy.data.objects.new(name, data)
    scene().collection.objects.link(ob)
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
    return ob


def bake(ob):
    """Aplica todos los modificadores."""
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
    """Une mallas en una (sin materiales; se asignan después)."""
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


def box(name, center, size, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    m = Matrix.Translation(center) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return bm_object(name, bm)


def cone(name, base, axis, length, r1, r2=0.004, seg=10):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length)
    axis = Vector(axis).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(base) + axis * length / 2) @ rot, verts=bm.verts)
    return bm_object(name, bm)


def cylinder(name, a, b, radius, seg=16):
    a, b = Vector(a), Vector(b)
    return cone(name, a, b - a, (b - a).length, radius, radius, seg)


def tube(name, pts, radius, radii=None, resolution=3):
    """Tubo por una curva suave (radii: grosor relativo en cada punto)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    cu.resolution_u = resolution
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, (p, pt) in enumerate(zip(sp.points, pts)):
        p.co = (pt[0], pt[1], pt[2], 1)
        if radii:
            p.radius = radii[i]
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(pts))
    tmp = link(name + "_curve", cu)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    return smooth(link(name, me))


def ring(name, center, axis, radius, height, seg=32, rows=3):
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
    return smooth(ob)


def thicken(ob, thickness, subdiv=1):
    so = ob.modifiers.new("Thick", "SOLIDIFY")
    so.thickness = thickness
    if subdiv:
        sub = ob.modifiers.new("Sub", "SUBSURF")
        sub.levels = subdiv
        sub.render_levels = subdiv
    bake(ob)
    return smooth(ob)


def subdivide(ob, levels=1):
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    bake(ob)
    return smooth(ob)


def roughen(ob, strength, scale):
    """Irregularidad (madera, metal golpeado...)."""
    tex = bpy.data.textures.new(ob.name + "Noise", "CLOUDS")
    tex.noise_scale = scale
    disp = ob.modifiers.new("Rough", "DISPLACE")
    disp.texture = tex
    disp.strength = strength
    bake(ob)
    return ob


def remesh(ob, voxel, target_faces):
    """Funde las piezas solapadas en una sola superficie suave."""
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
    return smooth(ob)


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
    return ob


def skin_object(name, nodes, edges, subdiv=2):
    """Forma orgánica a partir de un "esqueleto" de puntos con grosor (modificador Skin)."""
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


class Skeleton:
    """Puntos con grosor y uniones, para cuerpos hechos con el modificador Skin."""

    def __init__(self):
        self.nodes, self.index = [], {}

    def node(self, name, pos, r):
        self.index[name] = len(self.nodes)
        self.nodes.append((Vector(pos), r))

    def pos(self, name):
        return self.nodes[self.index[name]][0]

    def has(self, name):
        return name in self.index

    def segment(self, name, named_edges, subdiv=2):
        names = []
        for a, b in named_edges:
            for n in (a, b):
                if n not in names:
                    names.append(n)
        local = {n: i for i, n in enumerate(names)}
        ob = skin_object(
            name, [self.nodes[self.index[n]] for n in names], [(local[a], local[b]) for a, b in named_edges], subdiv
        )
        bake(ob)
        return smooth(ob)


# --------------------------------------------------------------------------------------
# Materiales
# --------------------------------------------------------------------------------------


def _nodes(m):
    if m.node_tree is None:
        m.use_nodes = True
    return m.node_tree


def material(name, color=None, rough=0.6, vertex_color=False, sss=0.0, emission=0.0, bump=None, metallic=0.0):
    m = bpy.data.materials.new(name)
    nt = _nodes(m)
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


def worn_material(name, base, dark, scale=6.0, rough=0.7, metallic=0.0):
    """Material gastado: mezcla dos tonos con manchas (cuero viejo, metal oxidado, madera)."""
    m = bpy.data.materials.new(name)
    nt = _nodes(m)
    p = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = 8
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.38
    ramp.color_ramp.elements[0].color = (*base, 1)
    ramp.color_ramp.elements[1].position = 0.68
    ramp.color_ramp.elements[1].color = (*dark, 1)
    nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metallic
    return m


def eyeball_material(name, sclera, rim, iris_dark, iris_light, pupil, pupil_size=0.94):
    """Ojo de anime dibujado por el material (bordes limpios). El objeto mira hacia -Y local."""
    m = bpy.data.materials.new(name)
    nt = _nodes(m)
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
        (0.0, sclera),
        (0.735, sclera),
        (0.742, rim),
        (0.775, iris_dark),
        (0.88, iris_light),
        (pupil_size - 0.005, iris_light),
        (pupil_size, pupil),
        (1.0, pupil),
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


def give(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


# --------------------------------------------------------------------------------------
# Exportar a Roblox: textura única horneada, piezas R15 (+ extras), contorno, FBX y datos
# --------------------------------------------------------------------------------------


def _select_only(objs):
    bpy.context.view_layer.update()
    for o in scene().objects:
        if o is not None:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def _tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export_game_model(
    name,
    parts,
    hulled,
    joints,
    root_center,
    out_dir,
    repo,
    budgets,
    default_budget=400,
    uv_boost=None,
    extras=None,
    atlas_size=1024,
    hull_thickness=0.02,
    outline_rgb=(0.012, 0.016, 0.008),
):
    """
    parts:   {pieza R15: [objetos]}
    hulled:  nombres de objetos con contorno anime
    joints:  [(articulación, pieza padre, pieza hija, Vector punto de giro)]
    extras:  {nombre: {"objects": [...], "attach": pieza, "hidden": bool}}  (piezas soldadas)
    Devuelve {pieza: objeto final}.
    """
    extras = extras or {}
    uv_boost = uv_boost or {}
    missing = [p for p in R15_PARTS if p not in parts]
    if missing:
        raise RuntimeError(f"Faltan piezas: {missing}")
    groups = {p: list(parts[p]) for p in R15_PARTS}
    for extra_name, extra in extras.items():
        groups[extra_name] = list(extra["objects"])
    game_objects = [o for objs in groups.values() for o in objs]
    stray = [o.name for o in bpy.data.objects if o.type == "MESH" and o not in game_objects]
    if stray:
        print(f"[{name}] AVISO: objetos sin pieza asignada:", stray)

    # 0) Presupuesto de triángulos por objeto
    for o in game_objects:
        budget = budgets.get(o.name, default_budget)
        tris = _tris(o)
        if tris > budget:
            dec = o.modifiers.new("Decimate", "DECIMATE")
            dec.ratio = budget / tris
            bake(o)
            smooth(o)

    # 1) Coordenadas de textura: todo en una imagen; ojos y cara con más resolución
    scene().tool_settings.use_uv_select_sync = True
    _select_only(game_objects)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in game_objects:
        k = uv_boost.get(o.name, 1.0)
        if k != 1.0:
            uv = o.data.uv_layers.active.data
            cx = sum(loop.uv.x for loop in uv) / len(uv)
            cy = sum(loop.uv.y for loop in uv) / len(uv)
            for loop in uv:
                loop.uv = (cx + (loop.uv.x - cx) * k, cy + (loop.uv.y - cy) * k)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in game_objects:
        for loop in o.data.uv_layers.active.data:
            loop.uv = loop.uv * 0.97  # la esquina de arriba a la derecha queda para el contorno

    # 2) Hornear todos los colores en la textura
    atlas = bpy.data.images.new(name + "_Texture", atlas_size, atlas_size, alpha=False)
    for m in {m for o in game_objects for m in o.data.materials if m}:
        image_node = m.node_tree.nodes.new("ShaderNodeTexImage")
        image_node.image = atlas
        m.node_tree.nodes.active = image_node
    scene().render.engine = "CYCLES"
    scene().cycles.samples = 8
    _select_only(game_objects)
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=True, margin=8)

    import numpy as np

    pixels = np.empty(atlas_size * atlas_size * 4, dtype=np.float32)
    atlas.pixels.foreach_get(pixels)
    pixels = pixels.reshape(atlas_size, atlas_size, 4)
    corner = int(atlas_size * 0.975)
    pixels[corner:, corner:, 0:3] = outline_rgb
    atlas.pixels.foreach_set(pixels.ravel())
    atlas.update()
    export_dir = os.path.join(out_dir, "export")
    os.makedirs(export_dir, exist_ok=True)
    atlas.filepath_raw = os.path.join(export_dir, name + "_Texture.png")
    atlas.file_format = "PNG"
    atlas.save()
    atlas.pack()

    final_mat = bpy.data.materials.new(name)
    nt = _nodes(final_mat)
    final_mat.use_backface_culling = True
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = atlas
    nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7

    # 3) Contorno anime: copia un poco más gruesa con las caras al revés
    def make_hull(ob):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.transform(ob.matrix_world)
        bm.normal_update()
        for v in bm.verts:
            v.co += v.normal * hull_thickness
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        uv = bm.loops.layers.uv.active
        for face in bm.faces:
            for loop in face.loops:
                loop[uv].uv = (0.99, 0.99)
        return bm_object(ob.name + "Outline", bm)

    # 4) Unir cada pieza
    final = {}
    for part, objs in groups.items():
        objs = objs + [make_hull(o) for o in objs if o.name in hulled]
        for o in objs:
            o.data.materials.clear()
            o.data.materials.append(final_mat)
            o.data.polygons.foreach_set("material_index", [0] * len(o.data.polygons))
        target = objs[0]
        _select_only(objs)
        with bpy.context.temp_override(
            active_object=target, object=target, selected_objects=objs, selected_editable_objects=objs
        ):
            bpy.ops.object.join()
        target.name = part
        target.data.name = part
        for attr in list(target.data.color_attributes):
            target.data.color_attributes.remove(attr)
        final[part] = target

    # 5) Medidas y triángulos
    info, total = {}, 0
    for part, ob in final.items():
        cos = [ob.matrix_world @ v.co for v in ob.data.vertices]
        lo = Vector((min(c.x for c in cos), min(c.y for c in cos), min(c.z for c in cos)))
        hi = Vector((max(c.x for c in cos), max(c.y for c in cos), max(c.z for c in cos)))
        tris = _tris(ob)
        total += tris
        info[part] = ((lo + hi) / 2, hi - lo, tris)
        print(f"[{name}] {part}: {tris} triángulos")
        if tris > 20000:
            raise RuntimeError(f"{part} supera el límite de triángulos de Roblox")
    print(f"[{name}] total: {total} triángulos")

    # 6) FBX
    _select_only(list(final.values()))
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(export_dir, name + ".fbx"),
        use_selection=True,
        object_types={"MESH"},
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_ALL",
        add_leaf_bones=False,
        colors_type="NONE",
    )

    # 7) Datos para el juego
    def v3(v):
        return f"Vector3.new({v.x:.4f}, {v.y:.4f}, {v.z:.4f})"

    lua = [
        f"-- GENERADO por el script de Blender de {name}: no editar a mano (se sobrescribe).",
        "-- Medidas en coordenadas de Blender (1 unidad = 1 stud; mira hacia -Y, arriba es +Z).",
        "-- server/MeshRig.luau las usa para montar el modelo importado en Roblox.",
        "return {",
        f'\tTemplate = "{name}",',
        f"\tRoot = {v3(root_center)},",
        "\tParts = {",
    ]
    for part in R15_PARTS:
        center, size, tris = info[part]
        lua.append(f"\t\t{part} = {{ Center = {v3(center)}, Size = {v3(size)}, Triangles = {tris} }},")
    for extra_name, extra in extras.items():
        center, size, tris = info[extra_name]
        hidden = "true" if extra.get("hidden") else "false"
        lua.append(
            f"\t\t{extra_name} = {{ Center = {v3(center)}, Size = {v3(size)}, Triangles = {tris}, "
            f'Attach = "{extra["attach"]}", Hidden = {hidden} }},'
        )
    lua += ["\t},", "\tJoints = {"]
    for joint_name, part0, part1, pos in joints:
        lua.append(
            f'\t\t{{ Name = "{joint_name}", Part0 = "{part0}", Part1 = "{part1}", Position = {v3(Vector(pos))} }},'
        )
    lua += ["\t},", "}", ""]
    rig_dir = os.path.join(repo, "src", "server", "MonsterRigs")
    os.makedirs(rig_dir, exist_ok=True)
    with open(os.path.join(rig_dir, name + ".luau"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lua))
    return final


# --------------------------------------------------------------------------------------
# Vistas previas
# --------------------------------------------------------------------------------------


def aim(ob, target):
    ob.rotation_euler = (Vector(target) - ob.location).to_track_quat("-Z", "Y").to_euler()


def preview_scene():
    world = bpy.data.worlds.new("World")
    scene().world = world
    if world.node_tree is None:
        world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*lin(190, 205, 215), 1)
    bg.inputs["Strength"].default_value = 0.6
    ground_bm = bmesh.new()
    bmesh.ops.create_grid(ground_bm, x_segments=1, y_segments=1, size=12)
    give(bm_object("Ground", ground_bm), material("Ground", lin(150, 160, 135), rough=0.95))
    for light_name, loc, energy, size in (
        ("Key", (-4, -6, 7), 1000, 4),
        ("Fill", (5, -4, 3.5), 330, 5),
        ("Rim", (2, 6, 6), 750, 3),
    ):
        light = bpy.data.lights.new(light_name, "AREA")
        light.energy = energy
        light.size = size
        ob = link(light_name, light)
        ob.location = loc
        aim(ob, (0, -0.2, 2.2))
    s = scene()
    s.render.resolution_x = 900
    s.render.resolution_y = 1100
    for candidate in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            s.render.engine = candidate
            break
        except TypeError:
            pass
    try:
        s.eevee.taa_render_samples = 64
    except AttributeError:
        pass


def render(path, loc, target, ortho_scale, res=(900, 1100)):
    s = scene()
    s.render.resolution_x, s.render.resolution_y = res
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam_data.clip_end = 100
    cam = link("Cam", cam_data)
    cam.location = loc
    aim(cam, target)
    s.camera = cam
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def skin_noise(p, base, dark, amount=0.14, scale=5.0):
    n = noise.noise(Vector(p) * scale)
    return mix(base, dark, 0.18 + amount * n)
