# Contra-corte (contra-ataque de oportunidade, C1.1): corte horizontal curto e rápido, da direita para
# a esquerda, na altura do peito, com passo curto à frente e giro de quadril. Nasce da pose de "pronto"
# em que a deflexão termina (quadro 18), então o contra-ataque sai sem recomeçar a postura.
#
# Quadros (60 Hz): 0-4 coil (peso e giro para a direita) · 5-10 corte (contato) · 10-14 passagem ·
# 14-22 volta à guarda média, livre para esquivar, correr ou golpear.
# Mesmo espaço dos golpes: -Y frente, -X direita do personagem, Z para cima.

FRAMES = 23


def _add(a, d):
    return tuple(a[i] + d[i] for i in range(3))


def build(k0):
    p0 = k0["pelvis_pos"]
    h0 = k0["hand_r"]
    fr0 = k0["foot_r"]
    fl0 = k0["foot_l"]
    pel = [(0, (0.0, 0.0, 0.0)), (4, (0.0, 0.03, -0.04)), (8, (0.0, -0.30, -0.06)), (11, (0.0, -0.52, -0.06)), (22, (0.0, -0.60, 0.0))]
    pelvis_keys = [(f, _add(p0, d)) for f, d in pel]

    def hand(f, rel):
        p = next(v for ff, v in pelvis_keys if ff == f)
        return (f, _add(p, rel))

    keys = {
        "pelvis_pos": pelvis_keys,
        "pelvis_yaw": [(0, k0["pelvis_yaw"]), (4, -14.0), (8, 12.0), (11, 22.0), (22, 4.0)],
        "pelvis_pitch": [(0, k0["pelvis_pitch"]), (8, 10.0), (11, 12.0), (22, 6.0)],
        "chest_yaw": [(0, k0["chest_yaw"]), (4, -30.0), (8, 20.0), (11, 36.0), (22, 6.0)],
        "chest_pitch": [(0, k0["chest_pitch"]), (8, 14.0), (11, 14.0), (22, 8.0)],
        "chest_roll": [(0, k0["chest_roll"]), (8, 0.0), (11, 3.0), (22, 2.0)],
        "hand_r": [
            (0, h0),
            hand(4, (-0.34, -0.20, 0.30)),
            hand(8, (-0.02, -0.82, 0.32)),     # contato: à frente, cruzando a linha central
            hand(11, (0.36, -0.74, 0.30)),     # fim do corte, à esquerda
            (22, _add(pelvis_keys[-1][1], (-0.10, -0.44, 0.50))),
        ],
        "blade_dir": [
            (0, k0["blade_dir"]),
            (4, (-0.30, -0.92, 0.22)),
            (8, (0.12, -0.99, 0.05)),
            (11, (0.80, -0.58, -0.05)),
            (22, (0.10, -0.80, 0.55)),
        ],
        "foot_r": [(0, fr0), (4, fr0), (7, _add(fr0, (0.0, -0.22, 0.14))), (10, _add(fr0, (0.0, -0.50, 0.0))), (22, _add(fr0, (0.0, -0.50, 0.0)))],
        "foot_l": [(0, fl0), (9, fl0), (13, _add(fl0, (0.0, -0.20, 0.10))), (17, _add(fl0, (0.0, -0.40, 0.0))), (22, _add(fl0, (0.0, -0.40, 0.0)))],
        "foot_r_yaw": [(0, k0["foot_r_yaw"]), (22, k0["foot_r_yaw"])],
        "foot_l_yaw": [(0, k0["foot_l_yaw"]), (22, k0["foot_l_yaw"])],
    }
    return keys, FRAMES, 0.70, 2, 10
