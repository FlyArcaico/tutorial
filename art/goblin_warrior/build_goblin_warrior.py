# Slime Rebirth — Goblin Guerrero (modelo de Blender)
#
# Uso (sin abrir Blender):
#   blender -b --factory-startup --python art/goblin_warrior/build_goblin_warrior.py -- art/goblin_warrior
#   (añade "design" al final para solo sacar vistas previas del diseño, sin exportar)
#
# Mismo estilo que el Goblin de nivel 1 (anime realista, contorno), pero más alto, fibroso y
# seguro de sí mismo: calvo, orejas largas hacia atrás, ojos rasgados y enfadados, nariz
# afilada, colmillos inferiores, armadura de cuero de la tribu, espada corta y escudo.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
import rbx_creature as rc  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
DESIGN_ONLY = "design" in argv
PREVIEW = os.path.join(OUT, "previews")
os.makedirs(PREVIEW, exist_ok=True)
REPO = os.path.abspath(os.path.join(OUT, "..", ".."))
random.seed(21)
rc.reset()

lin, mix = rc.lin, rc.mix

# --------------------------------------------------------------------------------------
# Materiales
# --------------------------------------------------------------------------------------

SKIN_BASE = lin(146, 170, 70)
SKIN_DARK = lin(92, 112, 44)
SKIN_LIGHT = lin(178, 192, 102)
SKIN = rc.material("Skin", vertex_color=True, rough=0.55, sss=0.12, bump=(70, 0.05))
INNER_EAR = rc.material("InnerEar", lin(176, 112, 70), rough=0.6, sss=0.2)
LEATHER = rc.worn_material("Leather", lin(108, 66, 40), lin(66, 40, 25), scale=7, rough=0.55)
LEATHER_DARK = rc.worn_material("LeatherDark", lin(72, 44, 28), lin(46, 28, 18), scale=7, rough=0.55)
CLOTH = rc.worn_material("Cloth", lin(178, 156, 112), lin(120, 98, 66), scale=9, rough=0.95)
CLOTH_DARK = rc.worn_material("ClothDark", lin(118, 92, 62), lin(80, 60, 40), scale=9, rough=0.95)
IRON = rc.worn_material("Iron", lin(120, 118, 112), lin(70, 62, 55), scale=12, rough=0.45, metallic=0.8)
BLADE = rc.worn_material("Blade", lin(176, 176, 170), lin(108, 100, 92), scale=10, rough=0.35, metallic=0.85)
WOOD = rc.worn_material("Wood", lin(120, 80, 48), lin(78, 50, 30), scale=5, rough=0.8)
IVORY = rc.material("Ivory", lin(238, 230, 205), rough=0.35)
LINE = rc.material("Line", lin(28, 20, 14), rough=0.6)
SHINE = rc.material("Shine", (1, 1, 1), rough=0.1, emission=4)
EYEBALL = rc.eyeball_material(
    "EyeBall",
    sclera=lin(236, 228, 196),
    rim=lin(90, 60, 10),
    iris_dark=lin(176, 130, 24),
    iris_light=lin(244, 206, 78),
    pupil=lin(14, 10, 6),
    pupil_size=0.962,
)

PART = {}
HULLED = set()


def assign(part, *objs):
    PART.setdefault(part, []).extend(objs)


def outline(ob):
    HULLED.add(ob.name)
    return ob


# --------------------------------------------------------------------------------------
# Cuerpo
# --------------------------------------------------------------------------------------

sk = rc.Skeleton()
node = sk.node

# Columna: un poco inclinada hacia delante, pecho ancho
node("pelvis", (0, 0.02, 1.72), (0.27, 0.21))
node("waist", (0, 0.0, 1.92), (0.25, 0.2))
node("belly", (0, -0.02, 2.04), (0.26, 0.2))
node("chest", (0, -0.07, 2.36), (0.34, 0.23))
node("upper", (0, -0.1, 2.58), (0.33, 0.21))
node("neck", (0, -0.2, 2.95), 0.13)

for side, s in ((1, "L"), (-1, "R")):
    # Brazos fibrosos: hombro, bíceps, codo, antebrazo, muñeca, mano
    node("sh" + s, (side * 0.44, -0.1, 2.6), 0.15)
    node("bi" + s, (side * 0.53, -0.08, 2.36), 0.125)
    node("el" + s, (side * 0.59, -0.07, 2.1), 0.095)
    node("fa" + s, (side * 0.63, -0.12, 1.88), 0.11)
    node("wr" + s, (side * 0.65, -0.19, 1.63), 0.075)
    node("ha" + s, (side * 0.66, -0.23, 1.49), (0.1, 0.085))
    hand = sk.pos("ha" + s)
    # Puños cerrados (empuñadura de la espada / asa del escudo)
    for k, dx in enumerate((-0.04, 0.0, 0.04)):
        node(f"f{k}{s}", hand + Vector((dx, -0.075, -0.05)), 0.036)
    node("th" + s, hand + Vector((-side * 0.07, -0.06, 0.01)), 0.032)
    # Piernas: postura abierta y algo flexionada
    node("hip" + s, (side * 0.19, 0.02, 1.6), 0.17)
    node("thi" + s, (side * 0.25, -0.04, 1.28), 0.18)
    node("kn" + s, (side * 0.29, -0.1, 0.96), 0.12)
    node("ca" + s, (side * 0.3, -0.03, 0.66), 0.13)
    node("an" + s, (side * 0.3, 0.03, 0.3), 0.085)
    node("bt" + s, (side * 0.3, 0.03, 0.4), 0.14)  # caña de la bota en el tobillo
    node("he" + s, (side * 0.3, 0.1, 0.11), 0.1)
    node("ba" + s, (side * 0.3, -0.19, 0.1), (0.135, 0.095))
    node("to" + s, (side * 0.3, -0.3, 0.09), (0.12, 0.085))

edges_named = [("pelvis", "waist"), ("waist", "belly"), ("belly", "chest"), ("chest", "upper"), ("upper", "neck")]
for s in ("L", "R"):
    edges_named += [
        ("upper", "sh" + s),
        ("sh" + s, "bi" + s),
        ("bi" + s, "el" + s),
        ("el" + s, "fa" + s),
        ("fa" + s, "wr" + s),
        ("wr" + s, "ha" + s),
        ("ha" + s, "th" + s),
        ("pelvis", "hip" + s),
        ("hip" + s, "thi" + s),
        ("thi" + s, "kn" + s),
        ("kn" + s, "ca" + s),
        ("ca" + s, "an" + s),
        ("an" + s, "he" + s),
        ("an" + s, "ba" + s),
        ("ba" + s, "to" + s),
    ] + [("ha" + s, f"f{k}{s}") for k in range(3)]
# Cuerpo entero (para los remaches) y moldes por zonas para ajustar la ropa: así la ropa
# del torso no se pega a los brazos que cuelgan al lado (luego se borran)
body = sk.segment("Body", edges_named)
torso_mold = sk.segment(
    "TorsoMold",
    [("pelvis", "waist"), ("waist", "belly"), ("belly", "chest"), ("chest", "upper"), ("upper", "neck"), ("pelvis", "hipL"), ("pelvis", "hipR")],
)
arm_mold, leg_mold = {}, {}
for s in ("L", "R"):
    arm_mold[s] = sk.segment("ArmMold" + s, [("sh" + s, "bi" + s), ("bi" + s, "el" + s), ("el" + s, "fa" + s), ("fa" + s, "wr" + s)])
    leg_mold[s] = sk.segment("LegMold" + s, [("kn" + s, "ca" + s), ("ca" + s, "an" + s)])
HANDS = {1: sk.pos("haL"), -1: sk.pos("haR")}


def body_color(p):
    c = rc.skin_noise(p, SKIN_BASE, SKIN_DARK)
    # Pecho y abdomen algo más claros; manos más oscuras
    if p.y < -0.05:
        c = mix(c, SKIN_LIGHT, 0.35 * math.exp(-(((p.z - 2.3) / 0.35) ** 2)))
    near_hand = max(math.exp(-(((p - HANDS[s]).length / 0.2) ** 2)) for s in (1, -1))
    return mix(c, SKIN_DARK, 0.5 * near_hand)


def segment(name, named_edges, material=SKIN):
    ob = sk.segment(name, named_edges)
    rc.paint(ob, body_color)
    rc.give(ob, material)
    outline(ob)
    assign(name, ob)
    return ob


segment("LowerTorso", [("pelvis", "waist"), ("pelvis", "hipL"), ("pelvis", "hipR")])
segment(
    "UpperTorso",
    [("waist", "belly"), ("belly", "chest"), ("chest", "upper"), ("upper", "neck"), ("upper", "shL"), ("upper", "shR")],
)
for s, prefix in (("L", "Left"), ("R", "Right")):
    segment(prefix + "UpperArm", [("sh" + s, "bi" + s), ("bi" + s, "el" + s)])
    segment(prefix + "LowerArm", [("el" + s, "fa" + s), ("fa" + s, "wr" + s)])
    segment(prefix + "Hand", [("wr" + s, "ha" + s), ("ha" + s, "th" + s)] + [("ha" + s, f"f{k}{s}") for k in range(3)])
    segment(prefix + "UpperLeg", [("hip" + s, "thi" + s), ("thi" + s, "kn" + s)])
    segment(prefix + "LowerLeg", [("kn" + s, "ca" + s), ("ca" + s, "an" + s)])
    # El pie es la bota
    segment(prefix + "Foot", [("an" + s, "bt" + s), ("an" + s, "he" + s), ("an" + s, "ba" + s), ("ba" + s, "to" + s)], LEATHER_DARK)

# --------------------------------------------------------------------------------------
# Cabeza: calva, alargada, barbilla afilada, ceño en V, nariz afilada, orejas hacia atrás
# --------------------------------------------------------------------------------------

C = Vector((0, -0.27, 3.3))

bm = rc.uv_sphere(64, 32)
for v in bm.verts:
    x, y, z = v.co
    X = x * 0.43
    Y = y * 0.44
    Z = z * 0.5
    if z < -0.15:  # mandíbula que se estrecha hacia una barbilla afilada
        X *= 1 - 0.42 * min(1, (-z - 0.15) / 0.85)
    if y < 0:  # boca un poco adelantada
        Y -= 0.09 * (-y) * math.exp(-(((z + 0.45) / 0.35) ** 2))
    if y < 0 and z > 0.35:  # frente inclinada
        Y += 0.08 * (z - 0.35) * (-y)
    if y > 0 and z > -0.3:  # cráneo más grande por detrás
        Y += 0.09 * y * (z + 0.3)
    if abs(x) > 0.55 and -0.35 < z < 0.1:  # mejillas hundidas bajo los pómulos
        X *= 0.97
    v.co = C + Vector((X, Y, Z))
head_base = rc.bm_object("HeadBase", bm)


def face_point(x, z, ob=None):
    p = rc.ray(ob or head_base, (x, C.y - 3, z), (0, 1, 0))
    return p if p is not None else Vector((x, C.y - 0.45, z))


parts = [head_base]
# Nariz afilada que baja hacia delante
nose_tip = face_point(0, C.z - 0.06)
parts.append(rc.ellipsoid("Nose", nose_tip + Vector((0, -0.06, -0.01)), (0.055, 0.11, 0.06), rot=(math.radians(-38), 0, 0)))
for side in (1, -1):
    parts.append(rc.ellipsoid("Nostril", nose_tip + Vector((side * 0.04, -0.015, -0.045)), (0.035, 0.04, 0.032)))
bridge = face_point(0, C.z + 0.08)
parts.append(rc.ellipsoid("Bridge", bridge + Vector((0, 0.01, -0.02)), (0.05, 0.05, 0.13), rot=(math.radians(-22), 0, 0)))
for side in (1, -1):
    # Ceño en V: las cejas bajan hacia el centro (cara de enfado)
    brow = face_point(side * 0.11, C.z + 0.14)
    parts.append(
        rc.ellipsoid("Brow", brow + Vector((0, 0.035, 0)), (0.15, 0.05, 0.04), rot=(0, math.radians(-side * 24), 0))
    )
chin = face_point(0, C.z - 0.46)
parts.append(rc.ellipsoid("Chin", chin + Vector((0, 0.04, 0.0)), (0.06, 0.05, 0.06)))

EAR_ROOT_X, EAR_L = 0.38, 1.0


def ear_point(side, a, y, z, inner=False):
    """Oreja larga y afilada que va hacia fuera y hacia atrás, subiendo un poco."""
    h = 0.2 * (1 - a**1.3) + 0.005
    t = 0.05 * (1 - 0.55 * a)
    X = a * EAR_L
    Z = z * h + 0.3 * a * a
    if inner:
        Y = -t + 0.03 * math.sin(math.pi * a) - 0.004 + y * 0.006
    else:
        Y = y * t
        if y < 0:
            Y += 0.03 * (1 - abs(z)) * math.sin(math.pi * a)
    Y += 0.32 * a * a  # hacia atrás
    return Vector((side * (EAR_ROOT_X + X * 0.9), C.y + 0.06 + Y, C.z + 0.04 + Z))


for side in (1, -1):
    bm = rc.uv_sphere(32, 16)
    for v in bm.verts:
        x, y, z = v.co
        v.co = ear_point(side, (x + 1) / 2, y, z)
    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    parts.append(rc.bm_object("Ear", bm))

head = rc.join("Head", parts)
rc.remesh(head, 0.011, 3000)
EAR_TIP_X = EAR_ROOT_X + EAR_L * 0.9


def head_color(p):
    c = rc.skin_noise(p, SKIN_BASE, SKIN_DARK)
    c = mix(c, SKIN_DARK, 0.55 * max(0, (abs(p.x) - 0.6) / (EAR_TIP_X - 0.6)))  # puntas de las orejas
    c = mix(c, SKIN_DARK, 0.3 * max(0, min(1, (p.z - (C.z + 0.3)) / 0.25)))  # coronilla
    for side in (1, -1):  # sombra alrededor de los ojos (mirada dura)
        eye = Vector((side * 0.16, C.y - 0.38, C.z + 0.05))
        c = mix(c, SKIN_DARK, 0.35 * math.exp(-(((p - eye).length / 0.12) ** 2)))
    return c


rc.paint(head, head_color)
rc.give(head, SKIN)
outline(head)
assign("Head", head)

inner = []
for side in (1, -1):
    bm = rc.uv_sphere(20, 10)
    for v in bm.verts:
        x, y, z = v.co
        v.co = ear_point(side, 0.1 + 0.72 * (x + 1) / 2, y, z * 0.55, inner=True)
    if side < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    inner.append(rc.bm_object("InnerEar", bm))
inner_ears = rc.smooth(rc.give(rc.join("InnerEars", inner), INNER_EAR))
assign("Head", inner_ears)

# Ojos rasgados de mirada dura: párpado superior bajo e inclinado hacia dentro y párpado
# inferior. Los párpados cerrados (para parpadear) van en una pieza aparte, oculta.
EYE_R = 0.088
lids_open, lashes, shines, closed = [], [], [], []
for side in (1, -1):
    hit = face_point(side * 0.165, C.z + 0.05, head)
    center = hit + Vector((0, 0.04, 0))
    look = Vector((side * -0.06, -1, -0.02)).normalized()
    bm = rc.uv_sphere(32, 16, EYE_R)
    eyeball = rc.bm_object("Eye" + ("L" if side > 0 else "R"), bm)
    eyeball.location = center
    eyeball.rotation_mode = "QUATERNION"
    eyeball.rotation_quaternion = Vector((0, -1, 0)).rotation_difference(look)
    rc.smooth(rc.give(eyeball, EYEBALL))
    assign("Head", eyeball)
    shine = (look + Vector((side * 0.3, 0, 0.45))).normalized() * EYE_R * 1.03
    shines.append(rc.ellipsoid("Shine", center + shine, (0.014, 0.008, 0.014)))

    lid_r = EYE_R * 1.1
    for upper, cut, tilt in ((True, 0.2, -side * 24), (False, -0.55, side * 8)):
        m_lid = Matrix.Translation(center) @ Euler((math.radians(-6), math.radians(tilt), 0)).to_matrix().to_4x4()
        bm = rc.uv_sphere(28, 14, lid_r)
        if upper:
            doomed = [v for v in bm.verts if v.co.z < cut * lid_r]
        else:
            doomed = [v for v in bm.verts if v.co.z > cut * lid_r]
        bmesh.ops.delete(bm, geom=doomed, context="VERTS")
        bmesh.ops.transform(bm, matrix=m_lid, verts=bm.verts)
        lid = rc.thicken(rc.bm_object("Lid", bm), 0.012, subdiv=0)
        lids_open.append(lid)
        if upper:
            rr = math.sqrt(1 - cut * cut) * lid_r * 1.02
            pts = [
                m_lid @ Vector((rr * math.cos(math.radians(a)), rr * math.sin(math.radians(a)), cut * lid_r))
                for a in range(200, 345, 8)
            ]
            lashes.append(rc.tube("Lash", pts, 0.011))
    # Párpado cerrado (parpadeo): cubre el ojo entero por delante
    bm = rc.uv_sphere(24, 12, lid_r * 1.04)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.2 * lid_r], context="VERTS")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(center), verts=bm.verts)
    closed.append(rc.thicken(rc.bm_object("Blink", bm), 0.01, subdiv=0))
    closed.append(
        rc.tube(
            "BlinkLine",
            [center + Vector((side * -0.07 + side * 0.14 * i / 6, -lid_r * 1.08, -0.01 - 0.012 * math.sin(math.pi * i / 6))) for i in range(7)],
            0.009,
        )
    )

lids = rc.smooth(rc.join("Lids", lids_open))
rc.paint(lids, lambda p: mix(SKIN_BASE, SKIN_DARK, 0.4))
assign("Head", rc.give(lids, SKIN))
assign("Head", rc.smooth(rc.give(rc.join("EyeLash", lashes), LINE)))
assign("Head", rc.smooth(rc.give(rc.join("EyeShine", shines), SHINE)))
blink_line = [o for o in closed if o.name.startswith("BlinkLine")]
blink_lid = rc.smooth(rc.join("BlinkLids", [o for o in closed if not o.name.startswith("BlinkLine")]))
rc.paint(blink_lid, lambda p: mix(SKIN_BASE, SKIN_DARK, 0.4))
rc.give(blink_lid, SKIN)
blink_lines = rc.smooth(rc.give(rc.join("BlinkLines", blink_line), LINE))
EYELIDS = [blink_lid, blink_lines]

# Boca seria con las comisuras hacia abajo y dos colmillos inferiores
mouth_pts = []
for i in range(9):
    x = -0.17 + 0.34 * i / 8
    z = C.z - 0.3 - 0.035 * (x / 0.17) ** 2
    mouth_pts.append(face_point(x, z, head) + Vector((0, 0.006, 0)))
assign("Head", rc.give(rc.tube("Mouth", mouth_pts, 0.013), LINE))
fangs = []
for side in (1, -1):
    fx = side * 0.085
    base = face_point(fx, C.z - 0.34, head) + Vector((0, -0.028, 0))
    fangs.append(rc.cone("Fang", base, (side * 0.1, -0.35, 1), 0.13, 0.034, seg=12))
assign("Head", rc.subdivide(rc.give(rc.join("Fangs", fangs), IVORY), 1))

HEAD_SCALE = 0.86
HEAD_PIVOT = sk.pos("neck") + Vector((0, -0.02, 0.0))
HEAD_DROP = Vector((0, 0.02, -0.1))  # la cabeza baja un poco para apoyarse bien en el cuello
head_matrix = (
    Matrix.Translation(HEAD_PIVOT + HEAD_DROP) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-HEAD_PIVOT)
)
for ob in PART["Head"] + EYELIDS:
    ob.matrix_world = head_matrix @ ob.matrix_world
C = HEAD_PIVOT + HEAD_DROP + (C - HEAD_PIVOT) * HEAD_SCALE

# --------------------------------------------------------------------------------------
# Equipo: túnica, peto de cuero con correas, hombreras, cinturón, falda, brazales, botas
# --------------------------------------------------------------------------------------

# Túnica de tela debajo del peto
tunic = rc.ring("Tunic", (0, -0.04, 2.15), (0, 0, 1), 0.6, 0.55, seg=40, rows=6)
assign("UpperTorso", outline(rc.give(rc.wrap_on(tunic, torso_mold, 0.01, 0.02), CLOTH)))

# Peto de cuero (algo más ancho por delante) y cuello de cuero
vest = rc.ring("Vest", (0, -0.08, 2.47), (0, -0.05, 1), 0.65, 0.48, seg=40, rows=6)
assign("UpperTorso", outline(rc.give(rc.wrap_on(vest, torso_mold, 0.028, 0.03), LEATHER)))
collar = rc.ring("Collar", (0, -0.14, 2.7), (0, -0.25, 1), 0.45, 0.09, seg=32, rows=3)
assign("UpperTorso", outline(rc.give(rc.wrap_on(collar, torso_mold, 0.05, 0.03), LEATHER_DARK)))
# Correas cruzadas en X sobre el peto
straps = []
for tilt in (1, -1):
    strap = rc.ring("Strap", (0, -0.07, 2.36), (tilt * math.tan(math.radians(38)), 0, 1), 0.65, 0.085, seg=40, rows=2)
    straps.append(rc.wrap_on(strap, torso_mold, 0.062, 0.018, subdiv=0))
assign("UpperTorso", outline(rc.give(rc.join("Straps", straps), LEATHER_DARK)))
rivets = []
for x, z in ((0.0, 2.36), (0.2, 2.5), (-0.2, 2.5), (0.22, 2.22), (-0.22, 2.22)):
    hit = rc.ray(torso_mold, (x, -3, z), (0, 1, 0))
    if hit:
        rivets.append(rc.ellipsoid("Rivet", hit + Vector((0, -0.075, 0)), (0.022, 0.018, 0.022)))
assign("UpperTorso", rc.give(rc.join("ChestRivets", rivets), IRON))


# Hombreras de varias capas de cuero con remaches (van con el brazo)
def pauldron(side, prefix):
    sh = sk.pos("sh" + ("L" if side > 0 else "R"))
    plates = []
    for layer, (radius, drop, out, tilt) in enumerate(((0.21, 0.0, 0.03, 30), (0.19, -0.1, 0.09, 50))):
        bm = rc.uv_sphere(28, 14, 1)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.05], context="VERTS")
        m = (
            Matrix.Translation(sh + Vector((side * out, 0.0, 0.03 + drop)))
            @ Euler((0, math.radians(side * tilt), 0)).to_matrix().to_4x4()
            @ Matrix.Diagonal((radius * 1.0, radius * 1.08, radius * 0.88, 1))
        )
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        plate = rc.thicken(rc.bm_object(f"{prefix}Pauldron{layer}", bm), 0.03, subdiv=1)
        plates.append(rc.give(plate, LEATHER if layer == 0 else LEATHER_DARK))
    studs = []
    for k in range(4):
        # Remaches sobre la hombrera de arriba (se buscan desde fuera hacia el hombro)
        angle = math.radians(-50 + k * 33)
        direction = Vector((side * 0.75, math.sin(angle), 0.65)).normalized()
        hit = rc.ray(plates[0], sh + direction * 1.5, -direction)
        if hit:
            studs.append(rc.ellipsoid("Stud", hit, (0.02, 0.02, 0.016)))
    stud_ob = rc.give(rc.join(f"{prefix}PauldronStuds", studs), IRON)
    for plate in plates:
        outline(plate)
    assign(prefix + "UpperArm", *plates, stud_ob)


pauldron(1, "Left")
pauldron(-1, "Right")

# Cinturón grueso con hebilla de hierro y bolsa
belt = rc.ring("Belt", (0, -0.0, 1.86), (0, -0.08, 1), 0.55, 0.13, seg=40, rows=3)
assign("LowerTorso", outline(rc.give(rc.wrap_on(belt, torso_mold, 0.03, 0.04), LEATHER_DARK)))
buckle_hit = rc.ray(belt, (0, -3, 1.86), (0, 1, 0)) or Vector((0, -0.3, 1.86))
buckle = [
    rc.box("BuckleFrame", buckle_hit + Vector((0, -0.01, 0)), (0.17, 0.03, 0.14)),
    rc.box("BucklePin", buckle_hit + Vector((0, -0.03, 0)), (0.02, 0.03, 0.12)),
]
assign("LowerTorso", rc.give(rc.join("Buckle", buckle), IRON))
pouch = rc.smooth(rc.give(rc.ellipsoid("Pouch", (-0.3, -0.06, 1.72), (0.08, 0.07, 0.11), rot=(0, 0, math.radians(-20))), LEATHER))
assign("LowerTorso", outline(pouch))


def flap(name, angle_deg, width, length, top=1.8, push=0.0, wave=0.012):
    """Tira de la falda: cuelga del cinturón alrededor de la cadera, con el borde roto."""
    a = math.radians(angle_deg)
    out = Vector((math.sin(a), -math.cos(a), 0))
    across = Vector((math.cos(a), math.sin(a), 0))
    cols, rows = 6, 8
    verts, faces = [], []
    for r in range(rows):
        t = r / (rows - 1)
        for c in range(cols):
            u = c / (cols - 1) * 2 - 1
            radius = 0.3 + 0.1 * t + push
            base = Vector((out.x * radius * 1.02, out.y * radius * 0.85, 0))
            z = top - t * length
            if r == rows - 1:
                z += 0.05 * abs(math.sin(u * 6.1 + angle_deg)) + random.uniform(-0.035, 0.02)
            p = base + across * (u * width / 2 * (1 + 0.1 * t)) + out * (wave * math.sin(u * 5 + t * 3))
            p.z = z
            verts.append(p)
    for r in range(rows - 1):
        for c in range(cols - 1):
            i = r * cols + c
            faces.append((i, i + 1, i + cols + 1, i + cols))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    return rc.thicken(rc.link(name, me), 0.022, subdiv=1)


skirt = []
for angle, width, length, mat, push in (
    (0, 0.34, 0.68, CLOTH, 0.02),  # tela delantera, la más larga
    (-38, 0.3, 0.5, LEATHER, 0.0),
    (38, 0.3, 0.5, LEATHER, 0.0),
    (-80, 0.3, 0.46, CLOTH_DARK, 0.0),
    (80, 0.3, 0.46, CLOTH_DARK, 0.0),
    (-130, 0.32, 0.5, LEATHER, 0.0),
    (130, 0.32, 0.5, LEATHER, 0.0),
    (180, 0.36, 0.6, CLOTH, 0.02),
):
    piece = outline(rc.give(flap(f"Skirt{angle}", angle, width, length, push=push), mat))
    skirt.append(piece)
assign("LowerTorso", *skirt)

# Brazales de cuero con correas (antebrazos) y botas altas con correas
for side, s, prefix in ((1, "L", "Left"), (-1, "R", "Right")):
    el, wr = sk.pos("el" + s), sk.pos("wr" + s)
    bracer = rc.ring("Bracer", el.lerp(wr, 0.62), wr - el, 0.2, (wr - el).length * 0.62, seg=28, rows=4)
    assign(prefix + "LowerArm", outline(rc.give(rc.wrap_on(bracer, arm_mold[s], 0.02, 0.03), LEATHER)))
    bands = [
        rc.wrap_on(rc.ring("Band", el.lerp(wr, t), (wr - el) + Vector((0, 0.05 * side, 0)), 0.2, 0.04, seg=24, rows=2), arm_mold[s], 0.035, 0.016, subdiv=0)
        for t in (0.42, 0.68, 0.9)
    ]
    assign(prefix + "LowerArm", rc.give(rc.join(prefix + "BracerBands", bands), LEATHER_DARK))

    kn, an = sk.pos("kn" + s), sk.pos("an" + s)
    shaft = rc.ring("BootShaft", kn.lerp(an, 0.68), an - kn, 0.25, (an - kn).length * 1.08, seg=28, rows=7)
    assign(prefix + "LowerLeg", outline(rc.give(rc.wrap_on(shaft, leg_mold[s], 0.022, 0.03), LEATHER_DARK)))
    cuff = rc.ring("BootCuff", kn.lerp(an, 0.17), an - kn, 0.28, 0.1, seg=28, rows=2)
    assign(prefix + "LowerLeg", outline(rc.give(rc.wrap_on(cuff, leg_mold[s], 0.045, 0.03, subdiv=0), LEATHER)))
    wraps = [
        rc.wrap_on(rc.ring("BootWrap", kn.lerp(an, t), (an - kn) + Vector((0.12 * side, 0.1, 0)), 0.25, 0.045, seg=24, rows=2), leg_mold[s], 0.042, 0.016, subdiv=0)
        for t in (0.38, 0.6, 0.8)
    ]
    assign(prefix + "LowerLeg", rc.give(rc.join(prefix + "BootWraps", wraps), LEATHER))

# --------------------------------------------------------------------------------------
# Espada corta goblin (mano derecha) y escudo redondo (antebrazo izquierdo)
# --------------------------------------------------------------------------------------

grip = HANDS[-1]
d = Vector((-0.12, -0.62, -0.78)).normalized()  # la hoja apunta hacia delante y abajo
thick_axis = Vector((-1, 0, 0))
thick_axis = (thick_axis - d * thick_axis.dot(d)).normalized()
w = d.cross(thick_axis).normalized()  # ancho de la hoja (el filo mira hacia delante/abajo)
if w.y > 0:
    w = -w

# Hoja: recta por el lomo, filo curvo que se ensancha hacia la punta y punta recortada,
# con alguna mella en el filo
outline_pts = [(0.14, -0.075), (0.45, -0.095), (0.8, -0.125), (1.1, -0.135), (1.28, -0.1), (1.42, 0.0), (1.3, 0.065), (0.8, 0.065), (0.14, 0.06)]
chipped = []
for u, v in outline_pts:
    if v < -0.08 and 0.3 < u < 1.2:
        v += random.choice((0.0, 0.0, 0.012))
    chipped.append((u, v))
bm = bmesh.new()
verts = [bm.verts.new(grip + d * u + w * v) for u, v in chipped]
bm.faces.new(verts)
blade = rc.bm_object("Blade", bm)
blade = rc.thicken(blade, 0.04, subdiv=0)
# Afilar el filo: los vértices del lado del filo se acercan al plano central
for vtx in blade.data.vertices:
    rel = vtx.co - grip
    if rel.dot(w) < -0.06:
        center_offset = rel.dot(thick_axis)
        vtx.co -= thick_axis * center_offset * 0.75
assign("RightHand", outline(rc.give(rc.subdivide(blade, 1), BLADE)))
guard = rc.box("Guard", grip + d * 0.12, (0.07, 0.07, 0.07))
guard_bar = rc.cylinder("GuardBar", grip + d * 0.12 - w * 0.17, grip + d * 0.12 + w * 0.15, 0.035, seg=10)
pommel = rc.ellipsoid("Pommel", grip - d * 0.17, (0.05, 0.05, 0.05))
assign("RightHand", outline(rc.give(rc.join("Hilt", [guard, guard_bar, pommel]), IRON)))
handle = rc.cylinder("Handle", grip - d * 0.14, grip + d * 0.1, 0.038, seg=12)
assign("RightHand", rc.give(handle, LEATHER_DARK))
grip_wraps = [rc.ring("GripWrap", grip + d * t, d, 0.045, 0.025, seg=16, rows=2) for t in (-0.1, -0.04, 0.02, 0.08)]
assign("RightHand", rc.give(rc.thicken(rc.join("GripWraps", grip_wraps), 0.012, subdiv=0), LEATHER))

# Escudo: tablas de madera, borde de hierro, refuerzo central y remaches
fa_l, wr_l = sk.pos("faL"), sk.pos("wrL")
forearm_mid = fa_l.lerp(wr_l, 0.4)
shield_normal = Vector((1, -0.45, 0.05)).normalized()  # mira hacia fuera y un poco al frente
shield_center = forearm_mid + shield_normal * 0.17
SHIELD_R = 0.44
rot = Vector((0, 0, 1)).rotation_difference(shield_normal).to_matrix().to_4x4()
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=40, radius1=SHIELD_R, radius2=SHIELD_R * 0.96, depth=0.06)
bmesh.ops.transform(bm, matrix=Matrix.Translation(shield_center) @ rot, verts=bm.verts)
board = rc.roughen(rc.bm_object("ShieldBoard", bm), 0.008, 0.3)
assign("LeftLowerArm", outline(rc.give(board, WOOD)))
rim = rc.ring("ShieldRim", shield_center, shield_normal, SHIELD_R + 0.01, 0.075, seg=40, rows=2)
assign("LeftLowerArm", outline(rc.give(rc.thicken(rim, 0.035, subdiv=1), IRON)))
boss = rc.ellipsoid("ShieldBoss", shield_center + shield_normal * 0.035, (0.11, 0.11, 0.06))
boss.matrix_world = Matrix.Translation(shield_center + shield_normal * 0.035) @ rot @ Matrix.Translation(-(shield_center + shield_normal * 0.035))
studs = []
ref = Vector((0, 0, 1))
for k in range(8):
    angle = math.radians(k * 45)
    local = Vector((math.cos(angle), math.sin(angle), 0)) * (SHIELD_R - 0.06)
    studs.append(rc.ellipsoid("ShieldStud", shield_center + rot.to_3x3() @ local + shield_normal * 0.035, (0.022, 0.022, 0.022)))
plank_lines = []
for k in (-1, 0, 1):
    a = rot.to_3x3() @ Vector((k * 0.14, -SHIELD_R * 0.9, 0)) + shield_center + shield_normal * 0.032
    b = rot.to_3x3() @ Vector((k * 0.14, SHIELD_R * 0.9, 0)) + shield_center + shield_normal * 0.032
    plank_lines.append(rc.cylinder("Plank", a, b, 0.007, seg=6))
assign("LeftLowerArm", rc.give(rc.join("ShieldMetal", [boss] + studs), IRON))
assign("LeftLowerArm", rc.give(rc.join("ShieldPlanks", plank_lines), LEATHER_DARK))
strap_ring = rc.ring("ShieldStrap", forearm_mid, wr_l - fa_l, 0.2, 0.05, seg=20, rows=2)
assign("LeftLowerArm", rc.give(rc.wrap_on(strap_ring, arm_mold["L"], 0.05, 0.02, subdiv=0), LEATHER_DARK))

for mold in [body, torso_mold] + list(arm_mold.values()) + list(leg_mold.values()):
    rc.remove(mold)

# --------------------------------------------------------------------------------------
# Puntos de giro (R15) y exportación
# --------------------------------------------------------------------------------------

ROOT_CENTER = Vector((0, 0.02, 1.72))
JOINTS = [
    ("Root", "HumanoidRootPart", "LowerTorso", sk.pos("pelvis")),
    ("Waist", "LowerTorso", "UpperTorso", sk.pos("waist")),
    ("Neck", "UpperTorso", "Head", sk.pos("neck")),
]
for s, prefix in (("L", "Left"), ("R", "Right")):
    JOINTS += [
        (prefix + "Shoulder", "UpperTorso", prefix + "UpperArm", sk.pos("sh" + s)),
        (prefix + "Elbow", prefix + "UpperArm", prefix + "LowerArm", sk.pos("el" + s)),
        (prefix + "Wrist", prefix + "LowerArm", prefix + "Hand", sk.pos("wr" + s)),
        (prefix + "Hip", "LowerTorso", prefix + "UpperLeg", sk.pos("hip" + s)),
        (prefix + "Knee", prefix + "UpperLeg", prefix + "LowerLeg", sk.pos("kn" + s)),
        (prefix + "Ankle", prefix + "LowerLeg", prefix + "Foot", sk.pos("an" + s)),
    ]

if DESIGN_ONLY:
    for ob in EYELIDS:  # en el diseño, los ojos abiertos
        ob.hide_render = True
    rc.preview_scene()
    rc.render(os.path.join(PREVIEW, "design_three_quarter.png"), (-7.5, -9.5, 4.0), (0, -0.2, 2.15), 4.9)
    rc.render(os.path.join(PREVIEW, "design_head.png"), (-3.2, -8, 3.9), C, 1.6)
    rc.render(os.path.join(PREVIEW, "design_front.png"), (0, -12, 2.15), (0, 0, 2.15), 4.9)
    rc.render(os.path.join(PREVIEW, "design_side.png"), (12, 0, 2.15), (0, -0.2, 2.15), 4.9)
    print("[warrior] diseño listo")
    raise SystemExit(0)

final = rc.export_game_model(
    "GoblinWarrior",
    PART,
    HULLED,
    JOINTS,
    ROOT_CENTER,
    OUT,
    REPO,
    default_budget=260,
    budgets={
        **{f"Skirt{a}": 150 for a in (0, -38, 38, -80, 80, -130, 130, 180)},
        "LeftPauldron0": 300,
        "LeftPauldron1": 260,
        "RightPauldron0": 300,
        "RightPauldron1": 260,
        "Head": 3200,
        "LowerTorso": 700,
        "UpperTorso": 900,
        "Tunic": 500,
        "Vest": 600,
        "Belt": 300,
        "LeftHand": 500,
        "RightHand": 500,
        "LeftFoot": 500,
        "RightFoot": 500,
        "Blade": 500,
        "ShieldBoard": 400,
        "ShieldRim": 400,
        "EyeL": 500,
        "EyeR": 500,
    },
    uv_boost={"EyeL": 3.0, "EyeR": 3.0, "Head": 1.5, "Lids": 1.5, "BlinkLids": 1.5},
    extras={"Eyelids": {"objects": EYELIDS, "attach": "Head", "hidden": True}},
)
final["Eyelids"].hide_render = True

rc.preview_scene()
rc.render(os.path.join(PREVIEW, "three_quarter.png"), (-7.5, -9.5, 4.0), (0, -0.2, 2.15), 4.9)
rc.render(os.path.join(PREVIEW, "head.png"), (-3.2, -8, 3.9), C, 1.6)
rc.render(os.path.join(PREVIEW, "front.png"), (0, -12, 2.15), (0, 0, 2.15), 4.9)
rc.render(os.path.join(PREVIEW, "side.png"), (12, 0, 2.15), (0, -0.2, 2.15), 4.9)
rc.render(os.path.join(PREVIEW, "back.png"), (0, 12, 2.15), (0, 0, 2.15), 4.9)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "goblin_warrior_v1.blend"))
print("[warrior] listo")
