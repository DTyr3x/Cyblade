# Cravada (finalização manual, C2.3): estocada vertical original. Passo à frente com a katana subindo acima da
# cabeça, a lâmina gira e desce com as duas mãos até cravar a ponta no inimigo ajoelhado; segura um instante,
# puxa e volta à guarda. De cima, a lâmina subindo e descendo fica legível.
#
# Quadros (60 Hz): 0-9 passo e subida · 9-13 ápice · 13-19 descida · 19 contato · 19-27 cravado ·
# 27-34 puxa · 34-42 volta à guarda, livre para mover desde o quadro 27.
# Mesmo espaço dos golpes: -Y frente, -X direita do personagem, Z para cima.

FRAMES = 43


def _add(a, d):
    return tuple(a[i] + d[i] for i in range(3))


def build(k0):
    p0 = k0["pelvis_pos"]
    fr0 = k0["foot_r"]
    fl0 = k0["foot_l"]
    pel = [(0, (0.0, 0.0, 0.0)), (9, (0.0, -0.18, 0.03)), (13, (0.0, -0.30, 0.01)), (19, (0.0, -0.50, -0.28)), (27, (0.0, -0.52, -0.30)), (34, (0.0, -0.50, -0.12)), (42, (0.0, -0.46, 0.0))]
    pelvis_keys = [(f, _add(p0, d)) for f, d in pel]

    def hand(f, rel):
        p = next(v for ff, v in pelvis_keys if ff == f)
        return (f, _add(p, rel))

    keys = {
        "pelvis_pos": pelvis_keys,
        "pelvis_yaw": [(0, k0["pelvis_yaw"]), (13, -6.0), (19, 0.0), (42, k0["pelvis_yaw"])],
        "pelvis_pitch": [(0, k0["pelvis_pitch"]), (13, 2.0), (19, 20.0), (27, 22.0), (42, k0["pelvis_pitch"])],
        "chest_yaw": [(0, k0["chest_yaw"]), (13, -4.0), (19, 0.0), (42, k0["chest_yaw"])],
        "chest_pitch": [(0, k0["chest_pitch"]), (13, -8.0), (19, 30.0), (27, 32.0), (42, k0["chest_pitch"])],
        "chest_roll": [(0, k0["chest_roll"]), (19, 0.0), (42, k0["chest_roll"])],
        "hand_r": [
            (0, k0["hand_r"]),
            hand(9, (-0.04, -0.20, 0.84)),
            hand(13, (-0.02, -0.18, 0.92)),    # ápice, acima da cabeça
            hand(19, (0.0, -0.58, 0.42)),      # contato: ponta para baixo, à frente
            hand(27, (0.0, -0.60, 0.36)),
            hand(34, (-0.05, -0.48, 0.60)),
            hand(42, (-0.10, -0.39, 0.44)),
        ],
        "blade_dir": [
            (0, k0["blade_dir"]),
            (9, (0.10, 0.10, 0.99)),
            (13, (0.02, 0.42, 0.91)),
            (16, (0.0, -0.40, 0.92)),
            (17, (0.0, -0.96, 0.28)),
            (19, (0.0, -0.60, -0.80)),
            (27, (0.0, -0.46, -0.89)),
            (34, (0.20, -0.85, 0.48)),
            (42, k0["blade_dir"]),
        ],
        "foot_r": [(0, fr0), (5, fr0), (10, _add(fr0, (0.0, -0.28, 0.14))), (14, _add(fr0, (0.0, -0.58, 0.0))), (42, _add(fr0, (0.0, -0.58, 0.0)))],
        "foot_l": [(0, fl0), (17, fl0), (24, _add(fl0, (0.0, -0.18, 0.06))), (30, _add(fl0, (0.0, -0.34, 0.0))), (42, _add(fl0, (0.0, -0.34, 0.0)))],
        "foot_r_yaw": [(0, k0["foot_r_yaw"]), (42, k0["foot_r_yaw"])],
        "foot_l_yaw": [(0, k0["foot_l_yaw"]), (42, k0["foot_l_yaw"])],
    }
    return keys, FRAMES, 0.45, 2, 18
