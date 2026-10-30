# Autoria do golpe 1 da katana (H2.1): "Kesa avançado" — corte diagonal descendente com as duas
# mãos, partindo de uma guarda alta à direita, com passo deslizante (okuri-ashi) e queda de quadril.
#
# Animação ORIGINAL do CYBLADE, feita por poses-chave em código sobre o rig do pacote UAL (CC0):
# alvos de IK para mãos e pés, rotações de quadril e coluna em espaço do armature. O Blender só
# resolve IK e avalia a pose; o resultado vai para um JSON que tools/blender_pose_to_godot.gd
# converte em um recurso Animation do Godot.
#
# Uso (sem interface):
#   blender -b --python tools/blender/author_katana_strike.py -- <ual.glb> <saida.json>
#
# Convenções do Blender após importar o glTF: Z para cima, personagem olha para -Y, lado direito -X.
# A animação é autorada no MUNDO (pés plantados no chão) e depois o avanço da cápsula é subtraído,
# então no jogo o pé de apoio fica parado enquanto a cápsula avança (sem escorregar).
import json
import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 60
FRAMES = 34                      # 0..33 -> 0,55 s
ADV_DIST = 0.90                  # avanço total da cápsula (m), igual ao StrikeData
ADV_START, ADV_END = 3, 15       # quadros do avanço (perfil smoothstep, igual ao CombatController)

# ---------------------------------------------------------------------------------------------
# Poses-chave (quadro, valores). Posições no MUNDO (antes de tirar o avanço). Ângulos em graus.
# yaw > 0 gira o corpo para a ESQUERDA do personagem (anti-horário visto de cima).
# ---------------------------------------------------------------------------------------------
KEYS = {
    # Quadril: deslocamento do quadril (x lateral, y frente(-)/trás(+), z altura absoluta da pélvis)
    "pelvis_pos": [
        (0, (0.00, 0.02, 0.88)),
        (4, (0.02, 0.06, 0.90)),     # preparação: peso para trás, sobe um pouco
        (9, (0.00, -0.55, 0.80)),    # contato: peso desce e vai para a frente
        (13, (-0.02, -0.84, 0.78)),
        (20, (0.00, -0.92, 0.84)),
        (33, (0.00, -0.92, 0.88)),
    ],
    "pelvis_yaw": [(0, -10), (4, -28), (9, 10), (13, 22), (20, 8), (33, -10)],
    "pelvis_pitch": [(0, 4), (4, 0), (9, 12), (13, 14), (20, 8), (33, 4)],   # inclinação à frente
    "chest_yaw": [(0, -12), (4, -48), (9, 18), (13, 34), (20, 10), (33, -12)],  # total da coluna
    "chest_pitch": [(0, 6), (4, -6), (9, 16), (13, 20), (20, 10), (33, 6)],
    "chest_roll": [(0, 0), (4, 6), (9, -8), (13, -10), (20, -4), (33, 0)],   # + sobe o ombro direito; no corte ele desce
    # Mão direita (punho) e direção da lâmina (vetor, normalizado depois)
    "hand_r": [
        (0, (-0.10, -0.32, 1.08)),
        (4, (-0.30, -0.02, 1.62)),   # guarda alta à direita, lâmina por cima do ombro
        (7, (-0.18, -0.62, 1.50)),   # a lâmina começa a descer pela frente
        (9, (0.00, -1.05, 1.20)),    # contato (já com o avanço), braços estendidos
        (12, (0.20, -1.10, 0.92)),
        (16, (0.30, -1.00, 0.86)),   # fim do corte, baixo à esquerda
        (22, (0.04, -1.18, 1.02)),   # zanshin: volta à guarda média
        (33, (-0.10, -1.24, 1.08)),
    ],
    "blade_dir": [
        (0, (0.05, -0.70, 0.71)),
        (4, (-0.35, 0.55, 0.76)),    # ponta para trás e para cima
        (7, (0.10, -0.55, 0.83)),
        (9, (0.45, -0.85, -0.05)),
        (12, (0.70, -0.40, -0.60)),
        (16, (0.65, 0.05, -0.76)),
        (22, (0.10, -0.80, 0.20)),
        (33, (0.05, -0.70, 0.71)),
    ],
    # Pés (tornozelo no mundo): pé direito à frente; passo do direito, depois o esquerdo desliza.
    "foot_r": [
        (0, (-0.13, -0.18, 0.10)), (4, (-0.13, -0.18, 0.10)), (7, (-0.12, -0.65, 0.17)),
        (9, (-0.12, -1.06, 0.10)), (33, (-0.12, -1.06, 0.10)),
    ],
    "foot_l": [
        (0, (0.14, 0.18, 0.10)), (10, (0.14, 0.18, 0.10)), (14, (0.14, -0.20, 0.12)),
        (18, (0.14, -0.60, 0.10)), (33, (0.14, -0.60, 0.10)),
    ],
    "foot_r_yaw": [(0, -10), (33, -10)],
    "foot_l_yaw": [(0, 25), (12, 25), (18, 15), (33, 15)],
}
GRIP_GAP = 0.11   # distância entre as mãos no cabo (m)
KESA_KEYS = KEYS
KESA_PARAMS = (FRAMES, ADV_DIST, ADV_START, ADV_END)


def pose_in_place(table, params, frame):
    """Pose de um golpe qualquer no quadro `frame`, no espaço da cápsula (avanço subtraído).
    `params` = (frames, distância, início, fim do avanço)."""
    dist, start, end = params[1], params[2], params[3]
    s = min(max((frame - start) / (end - start), 0.0), 1.0)
    a = dist * s * s * (3 - 2 * s)
    out = {}
    for ch in table:
        v = interp(ch, frame, table)
        if ch in ("pelvis_pos", "hand_r", "foot_r", "foot_l"):
            v = (v[0], v[1] + a, v[2])
        out[ch] = v
    return out


def kesa_pose_at(frame):
    """Pose do Kesa (APROVADO, não alterar) no quadro `frame`, no espaço da cápsula (avanço já
    subtraído). É o ponto de partida do Kiriage: a primeira pose dele é exatamente esta."""
    dist, start, end = KESA_PARAMS[1], KESA_PARAMS[2], KESA_PARAMS[3]
    s = min(max((frame - start) / (end - start), 0.0), 1.0)
    a = dist * s * s * (3 - 2 * s)
    out = {}
    for ch in KESA_KEYS:
        v = interp(ch, frame)
        if ch in ("pelvis_pos", "hand_r", "foot_r", "foot_l"):
            v = (v[0], v[1] + a, v[2])
        out[ch] = v
    return out


def interp(channel, f, table=None):
    """Catmull-Rom pelas chaves (tuplas ou escalares)."""
    keys = (KEYS if table is None else table)[channel]
    if f <= keys[0][0]:
        return keys[0][1]
    if f >= keys[-1][0]:
        return keys[-1][1]
    for i in range(len(keys) - 1):
        f0, v0 = keys[i]
        f1, v1 = keys[i + 1]
        if f0 <= f <= f1:
            t = (f - f0) / (f1 - f0)
            vp = keys[i - 1][1] if i > 0 else v0
            vn = keys[i + 2][1] if i + 2 < len(keys) else v1
            def cr(a, b, c, d):
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t)
            if isinstance(v0, tuple):
                return tuple(cr(vp[k], v0[k], v1[k], vn[k]) for k in range(3))
            return cr(vp, v0, v1, vn)
    return keys[-1][1]


def adv(f):
    s = min(max((f - ADV_START) / (ADV_END - ADV_START), 0.0), 1.0)
    return ADV_DIST * s * s * (3 - 2 * s)


def in_place(p, f):
    """Tira o avanço da cápsula (o personagem anda para -Y)."""
    return Vector((p[0], p[1] + adv(f), p[2]))


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def rot_about(m4, axis_mat, pivot):
    return Matrix.Translation(pivot) @ axis_mat @ Matrix.Translation(-pivot) @ m4


def main():
    global KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END
    argv = sys.argv[sys.argv.index("--") + 1:]
    glb, out_path = argv[0], argv[1]
    clip = argv[2] if len(argv) > 2 else "kesa"
    if clip == "kiriage":
        sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
        import katana_kiriage_keys
        KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END = katana_kiriage_keys.build(kesa_pose_at(katana_kiriage_keys.JOIN_FRAME))
    elif clip == "deflexao" or clip == "contra":
        sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
        import katana_guard_keys
        import katana_deflect_keys
        gk, _gf, _gd, _gs, _ge = katana_guard_keys.build()
        guard = {ch: v[0][1] for ch, v in gk.items()}
        dk, df, dd, ds, de = katana_deflect_keys.build(guard)
        if clip == "deflexao":
            KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END = dk, df, dd, ds, de
        else:
            import katana_counter_keys
            k0 = pose_in_place(dk, (df, dd, ds, de), df - 1)
            KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END = katana_counter_keys.build(k0)
    elif clip == "guarda":
        sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
        import katana_guard_keys
        KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END = katana_guard_keys.build()
    elif clip == "tsuki":
        sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
        import katana_kiriage_keys
        import katana_tsuki_keys
        kk, kf, kd, ks, ke = katana_kiriage_keys.build(kesa_pose_at(katana_kiriage_keys.JOIN_FRAME))
        k0 = pose_in_place(kk, (kf, kd, ks, ke), katana_tsuki_keys.JOIN_FRAME)
        KEYS, FRAMES, ADV_DIST, ADV_START, ADV_END = katana_tsuki_keys.build(k0)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb, bone_heuristic="FORTUNE")
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    scene = bpy.context.scene
    pose = arm.pose
    pb = pose.bones
    bones = arm.data.bones

    # Base dos dedos: mão fechada do clipe Sword_Idle (quadro 0), para as duas mãos.
    fist = {}
    idle = bpy.data.actions.get("Sword_Idle")
    if arm.animation_data is None:
        arm.animation_data_create()
    if idle is not None:
        arm.animation_data.action = idle
        scene.frame_set(0)
        bpy.context.view_layer.update()
        for b in pb:
            if any(k in b.name for k in ("thumb", "index", "middle", "ring", "pinky")) and b.name.endswith("_r"):
                q = b.rotation_quaternion.copy()
                fist[b.name] = q
                # Mão esquerda fechada: espelho da direita (eixos locais simétricos em X).
                fist[b.name[:-2] + "_l"] = Quaternion((q.w, q.x, -q.y, -q.z))
    arm.animation_data.action = None
    for b in pb:
        b.rotation_mode = "QUATERNION"

    coll = scene.collection
    def empty(name):
        e = bpy.data.objects.new(name, None)
        coll.objects.link(e)
        e.rotation_mode = "QUATERNION"
        return e

    tgt = {n: empty(n) for n in ["w_r", "w_l", "pole_r", "pole_l", "tip", "a_r", "a_l", "k_r", "k_l", "fr_rot", "fl_rot"]}

    def ik(bone, target, pole, angle):
        c = pb[bone].constraints.new("IK")
        c.target = target
        c.pole_target = pole
        c.pole_angle = angle
        c.chain_count = 2
        return c

    ik_r = ik("lowerarm_r", tgt["w_r"], tgt["pole_r"], 0.0)
    ik_l = ik("lowerarm_l", tgt["w_l"], tgt["pole_l"], 0.0)
    ikf_r = ik("calf_r", tgt["a_r"], tgt["k_r"], 0.0)
    ikf_l = ik("calf_l", tgt["a_l"], tgt["k_l"], 0.0)
    for side in ("r", "l"):
        d = pb["hand_" + side].constraints.new("DAMPED_TRACK")
        d.target = tgt["tip"]
        d.track_axis = "TRACK_Z"           # +Z da mão = direção do polegar = lâmina na pegada
        cr = pb["foot_" + side].constraints.new("COPY_ROTATION")
        cr.target = tgt["f%s_rot" % side]

    rest_world = {b.name: (arm.matrix_world @ b.matrix_local) for b in bones}

    # Calibra o pole_angle de cada cadeia: com o alvo na posição de repouso, escolhe o ângulo que
    # mantém o osso superior mais perto do repouso.
    def calibrate(c, upper):
        best = (1e9, 0.0)
        for deg in range(-180, 180, 5):
            c.pole_angle = math.radians(deg)
            bpy.context.view_layer.update()
            m = (arm.matrix_world @ pb[upper].matrix).to_3x3()
            r = rest_world[upper].to_3x3()
            err = sum(abs(m[i][j] - r[i][j]) for i in range(3) for j in range(3))
            if err < best[0]:
                best = (err, c.pole_angle)
        c.pole_angle = best[1]
        return round(math.degrees(best[1]))

    # Alvos de calibração: braços na pose T (punho no repouso), cotovelo atrás; pernas retas, joelho à frente.
    tgt["w_r"].location = rest_world["hand_r"].to_translation()
    tgt["w_l"].location = rest_world["hand_l"].to_translation()
    tgt["pole_r"].location = rest_world["lowerarm_r"].to_translation() + Vector((0, 0.5, 0))
    tgt["pole_l"].location = rest_world["lowerarm_l"].to_translation() + Vector((0, 0.5, 0))
    tgt["a_r"].location = rest_world["foot_r"].to_translation()
    tgt["a_l"].location = rest_world["foot_l"].to_translation()
    tgt["k_r"].location = rest_world["calf_r"].to_translation() + Vector((0, -0.5, 0))
    tgt["k_l"].location = rest_world["calf_l"].to_translation() + Vector((0, -0.5, 0))
    tgt["tip"].location = rest_world["hand_r"].to_translation() + Vector((0, -1, 0))
    for side in ("r", "l"):
        tgt["f%s_rot" % side].rotation_quaternion = rest_world["foot_" + side].to_quaternion()
    poles = {
        "r": calibrate(ik_r, "upperarm_r"),
        "l": calibrate(ik_l, "upperarm_l"),
        "fr": calibrate(ikf_r, "thigh_r"),
        "fl": calibrate(ikf_l, "thigh_l"),
    }
    print("POLES", poles)

    frames = []
    names = [b.name for b in bones]
    for f in range(FRAMES):
        # 1) Zera a pose e aplica os dedos fechados.
        for b in pb:
            b.location = (0, 0, 0)
            b.rotation_quaternion = fist.get(b.name, Quaternion())
            b.scale = (1, 1, 1)
        bpy.context.view_layer.update()

        # 2) Quadril.
        pp = in_place(interp("pelvis_pos", f), f)
        rest_p = rest_world["pelvis"]
        rot = rz(interp("pelvis_yaw", f)) @ Matrix.Rotation(math.radians(interp("pelvis_pitch", f)), 4, "X")
        pb["pelvis"].matrix = Matrix.Translation(pp) @ rot @ Matrix(rest_p.to_3x3()).to_4x4()
        bpy.context.view_layer.update()

        # 3) Coluna: o giro total do peito em relação ao quadril é distribuído pelas 3 vértebras.
        extra_yaw = interp("chest_yaw", f) - interp("pelvis_yaw", f)
        extra_pitch = interp("chest_pitch", f) - interp("pelvis_pitch", f)
        roll = interp("chest_roll", f)
        for name, share in (("spine_01", 0.3), ("spine_02", 0.35), ("spine_03", 0.35)):
            m = pb[name].matrix
            head = m.to_translation()
            r = rz(extra_yaw * share) @ Matrix.Rotation(math.radians(extra_pitch * share), 4, "X") @ Matrix.Rotation(math.radians(-roll * share), 4, "Y")
            pb[name].matrix = rot_about(m, r, head)
            bpy.context.view_layer.update()
        # Cabeça mantém o olhar à frente: desfaz boa parte do giro do peito.
        for name, share in (("neck_01", 0.4), ("Head", 0.4)):
            m = pb[name].matrix
            head = m.to_translation()
            r = rz(-interp("chest_yaw", f) * share) @ Matrix.Rotation(math.radians(-interp("chest_pitch", f) * share * 0.8), 4, "X")
            pb[name].matrix = rot_about(m, r, head)
            bpy.context.view_layer.update()

        # 4) Mãos (as duas no cabo), lâmina, pés e joelhos.
        hr = in_place(interp("hand_r", f), f)
        bd = Vector(interp("blade_dir", f)).normalized()
        tgt["w_r"].location = hr
        tgt["w_l"].location = hr - bd * GRIP_GAP
        tgt["tip"].location = hr + bd * 1.0
        tgt["pole_r"].location = hr + Vector((-0.45, 0.35, -0.35))
        tgt["pole_l"].location = hr + Vector((0.45, 0.35, -0.45))
        ar = in_place(interp("foot_r", f), f)
        al = in_place(interp("foot_l", f), f)
        tgt["a_r"].location = ar
        tgt["a_l"].location = al
        tgt["k_r"].location = ar + Vector((0, -0.6, 0.45))
        tgt["k_l"].location = al + Vector((0.1, -0.6, 0.45))
        for side, ch in (("r", "foot_r_yaw"), ("l", "foot_l_yaw")):
            tgt["f%s_rot" % side].rotation_quaternion = (rz(interp(ch, f)).to_quaternion() @ rest_world["foot_" + side].to_quaternion())
        bpy.context.view_layer.update()

        frames.append({n: [list(r) for r in (arm.matrix_world @ pb[n].matrix)] for n in names})

    rest = {n: [list(r) for r in rest_world[n]] for n in names}
    parents = {b.name: (b.parent.name if b.parent else "") for b in bones}
    with open(out_path, "w") as fp:
        json.dump({"fps": FPS, "frames": frames, "rest": rest, "parents": parents,
                   "advance": {"distance": ADV_DIST, "start": ADV_START / FPS, "end": ADV_END / FPS}}, fp)
    print("SAIDA", out_path, len(frames))


main()
