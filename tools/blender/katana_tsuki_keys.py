# Poses-chave do Tsuki de passo duplo (golpe 3, finalizador). Ver tools/blender/author_katana_strike.py.
#
# CONTINUIDADE: o primeiro quadro do Tsuki é a pose do Kiriage (aprovado) no quadro JOIN_FRAME, que é
# quando a janela de encadeamento do Kiriage abre (lâmina alta à direita). Todos os canais começam do
# valor do Kiriage naquele quadro, sem salto de quadril, tronco, mãos, lâmina nem pés.
#
# Espaço: o mesmo do Kesa e do Kiriage (mundo antes de subtrair o avanço da cápsula), origem na cápsula
# no início do Tsuki; -Y é a frente; yaw > 0 gira para a esquerda do personagem.
#
# Movimento (estocada com as duas mãos, pé direito à frente):
#   0-6    a lâmina desce do alto-direita para a linha do quadril direito (guarda de estocada); o quadril
#          carrega o peso na perna de trás e gira para a direita
#   6-13   passo 1: o pé de trás (esquerdo) desliza até quase alcançar o da frente; as mãos ficam no
#          quadril direito, a lâmina aponta para a frente
#   13-17  passo 2 (fumikomi): o pé da frente dá a passada longa e o peso passa da perna de trás para a
#          da frente; as mãos disparam para a frente; o quadril quadra com o alvo
#   17-22  extensão total: braços estendidos, perna de trás esticada, tronco inclinado à frente
#   22-36  recuperação: a lâmina volta à guarda média, o pé de trás desliza para perto; livre para esquivar ou correr
JOIN_FRAME = 17


def _add(a, d):
    return tuple(a[i] + d[i] for i in range(3))


def build(k0):
    pelvis0 = k0["pelvis_pos"]
    fr0 = k0["foot_r"]
    fl0 = k0["foot_l"]
    # (quadro, deslocamento do quadril em relação ao quadril inicial)
    pel = [
        (0, (0.0, 0.0, 0.0)),
        (6, (0.0, 0.05, -0.05)),
        (13, (0.0, -0.32, -0.07)),
        (17, (0.0, -0.80, -0.14)),
        (22, (0.0, -1.02, -0.13)),
        (30, (0.0, -1.06, -0.05)),
        (36, (0.0, -1.06, 0.0)),
    ]
    pelvis_keys = [(f, _add(pelvis0, d)) for f, d in pel]

    def hand(f, rel):
        p = next(v for ff, v in pelvis_keys if ff == f)
        return (f, _add(p, rel))

    keys = {
        "pelvis_pos": pelvis_keys,
        "pelvis_yaw": [(0, k0["pelvis_yaw"]), (6, -22), (13, -14), (17, 4), (22, 6), (30, -2), (36, -4)],
        "pelvis_pitch": [(0, k0["pelvis_pitch"]), (6, 6), (13, 10), (17, 13), (22, 13), (30, 8), (36, 6)],
        "chest_yaw": [(0, k0["chest_yaw"]), (6, -42), (13, -30), (17, 8), (22, 12), (30, -4), (36, -8)],
        "chest_pitch": [(0, k0["chest_pitch"]), (6, 8), (13, 14), (17, 22), (22, 22), (30, 12), (36, 8)],
        "chest_roll": [(0, k0["chest_roll"]), (6, 2), (13, 0), (17, -2), (22, -2), (36, 2)],
        # Mãos relativas ao quadril: (lateral, frente, altura). Lateral negativa = lado direito do corpo.
        "hand_r": [
            (0, k0["hand_r"]),
            hand(6, (-0.30, -0.18, 0.30)),
            hand(13, (-0.32, -0.12, 0.30)),
            hand(17, (-0.12, -0.80, 0.33)),     # contato: braços estendidos à frente
            hand(22, (-0.12, -0.82, 0.31)),
            hand(30, (-0.20, -0.50, 0.50)),
            hand(36, (-0.20, -0.46, 0.50)),
        ],
        "blade_dir": [
            (0, k0["blade_dir"]),
            (6, (-0.22, -0.90, 0.28)),
            (13, (-0.18, -0.94, 0.24)),
            (17, (-0.04, -0.99, 0.08)),
            (22, (-0.05, -0.98, 0.10)),
            (30, (-0.20, -0.85, 0.45)),
            (36, (-0.22, -0.80, 0.55)),
        ],
        # Passo 1: pé esquerdo (de trás) desliza. Passo 2: pé direito (da frente) dá a passada longa.
        "foot_l": [
            (0, fl0), (5, fl0),
            (9, _add(fl0, (0.0, -0.22, 0.10))),
            (13, _add(fl0, (0.0, -0.44, 0.0))),
            (22, _add(fl0, (0.0, -0.44, 0.0))),
            (30, _add(fl0, (0.0, -0.58, 0.0))),
            (36, _add(fl0, (0.0, -0.58, 0.0))),
        ],
        "foot_r": [
            (0, fr0), (12, fr0),
            (15, _add(fr0, (0.0, -0.35, 0.20))),
            (18, _add(fr0, (0.0, -0.66, 0.0))),
            (36, _add(fr0, (0.0, -0.66, 0.0))),
        ],
        "foot_r_yaw": [(0, k0["foot_r_yaw"]), (36, k0["foot_r_yaw"])],
        "foot_l_yaw": [(0, k0["foot_l_yaw"]), (36, k0["foot_l_yaw"])],
    }
    frames = 37      # 0..36 -> 0,60 s
    return keys, frames, 1.20, 4, 20
