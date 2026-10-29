# Poses-chave do Kiriage de retorno (golpe 2). Ver tools/blender/author_katana_strike.py.
#
# CONTINUIDADE: o primeiro quadro do Kiriage é a pose do Kesa (aprovado) no quadro JOIN_FRAME, que é
# exatamente quando a janela de encadeamento do Kesa abre. Todos os canais começam do valor do Kesa
# naquele quadro, então o encadeamento não tem salto de quadril, tronco, mãos, lâmina nem pés.
#
# Espaço: o mesmo do Kesa (mundo antes de subtrair o avanço da cápsula), com a origem na cápsula
# no início do Kiriage. -Y é a frente; yaw > 0 gira para a esquerda do personagem.
#
# Movimento (corte ascendente, de baixo à esquerda para o alto à direita):
#   0-4   continua o que o Kesa já fazia (a lâmina sobe pelo centro); o quadril carrega o peso na
#         perna da frente e gira ainda mais para a esquerda
#   4-9   o pé direito avança (okuri-ashi), o quadril desenrola para a direita e a lâmina sobe
#   9-13  contato e corte; o ombro direito sobe; o peso passa para a perna da frente
#   13-30 pé esquerdo desliza para a frente; termina em guarda média-alta à direita, lâmina para a frente e
#         para cima, pronta para uma estocada (terceiro golpe futuro)
JOIN_FRAME = 17


def _add(a, d):
    return tuple(a[i] + d[i] for i in range(3))


def build(k0):
    pelvis0 = k0["pelvis_pos"]
    hand0 = k0["hand_r"]
    fr0 = k0["foot_r"]
    fl0 = k0["foot_l"]
    keys = {
        "pelvis_pos": [
            (0, pelvis0),
            (3, _add(pelvis0, (0.0, -0.03, -0.03))),
            (6, _add(pelvis0, (0.0, -0.16, -0.05))),
            (10, _add(pelvis0, (0.0, -0.40, 0.03))),
            (14, _add(pelvis0, (0.0, -0.55, 0.08))),
            (20, _add(pelvis0, (0.0, -0.60, 0.09))),
            (30, _add(pelvis0, (0.0, -0.60, 0.07))),
        ],
        "pelvis_yaw": [(0, k0["pelvis_yaw"]), (3, k0["pelvis_yaw"] + 4), (8, -6), (12, -16), (16, -18), (24, -10), (30, -8)],
        "pelvis_pitch": [(0, k0["pelvis_pitch"]), (6, 8), (10, 6), (14, 3), (30, 4)],
        "chest_yaw": [(0, k0["chest_yaw"]), (3, k0["chest_yaw"] + 8), (8, -12), (12, -34), (16, -40), (24, -22), (30, -16)],
        "chest_pitch": [(0, k0["chest_pitch"]), (6, 12), (10, 4), (14, -2), (24, 4), (30, 6)],
        "chest_roll": [(0, k0["chest_roll"]), (8, -2), (12, 9), (16, 11), (24, 5), (30, 3)],
        "hand_r": [
            (0, hand0),
            (4, _add(hand0, (-0.10, -0.18, -0.02))),
            (7, _add(hand0, (-0.28, -0.52, 0.16))),
            (9, _add(hand0, (-0.42, -0.78, 0.36))),
            (11, _add(hand0, (-0.56, -0.90, 0.54))),
            (14, _add(hand0, (-0.64, -0.86, 0.66))),
            (22, _add(hand0, (-0.58, -0.74, 0.52))),
            (30, _add(hand0, (-0.54, -0.78, 0.38))),
        ],
        "blade_dir": [
            (0, k0["blade_dir"]),
            (4, (0.50, -0.30, -0.80)),
            (7, (0.15, -0.80, -0.55)),
            (9, (-0.25, -0.90, 0.15)),
            (11, (-0.55, -0.65, 0.50)),
            (14, (-0.62, -0.20, 0.76)),
            (22, (-0.50, -0.55, 0.65)),
            (30, (-0.25, -0.88, 0.38)),
        ],
        "foot_r": [
            (0, fr0), (3, fr0),
            (6, _add(fr0, (0.0, -0.30, 0.18))),
            (9, _add(fr0, (0.0, -0.60, 0.0))),
            (30, _add(fr0, (0.0, -0.60, 0.0))),
        ],
        "foot_l": [
            (0, fl0), (9, fl0),
            (12, _add(fl0, (0.0, -0.25, 0.14))),
            (16, _add(fl0, (0.0, -0.62, 0.11))),
            (20, _add(fl0, (0.0, -0.66, 0.0))),
            (30, _add(fl0, (0.0, -0.66, 0.0))),
        ],
        "foot_r_yaw": [(0, k0["foot_r_yaw"]), (30, k0["foot_r_yaw"])],
        "foot_l_yaw": [(0, k0["foot_l_yaw"]), (30, k0["foot_l_yaw"])],
    }
    frames = 31      # 0..30 -> 0,50 s
    return keys, frames, 0.60, 2, 12
