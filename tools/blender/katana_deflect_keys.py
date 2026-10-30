# Deflexão (parry perfeito, C1.1): desvia a lâmina inimiga com um varrido de mãos, braços, ombros e
# tronco, saindo da guarda e chegando à pose de "pronto" (lâmina à frente, mãos no quadril direito),
# de onde se contra-ataca, esquiva ou corre. Clipe de 0,30 s aplicado só da coluna para cima (as pernas
# seguem a locomoção).
#
# CONTINUIDADE: o primeiro quadro parte da guarda (C1.0); o clipe toca a partir do instante do contato.
# Mesmo espaço dos golpes: -Y frente, -X direita do personagem, Z para cima; yaw > 0 gira para a esquerda.
#
#   0-2   impacto: as lâminas se encontram; as mãos recuam um pouco e o tronco absorve (o jogo congela aqui)
#   2-9   desvio: o tronco gira para a direita, os ombros conduzem e as mãos varrem do peito-esquerda ao
#         quadril-direita; a lâmina desce em arco empurrando a arma inimiga para o lado de fora
#   9-18  assenta na pose de pronto: lâmina à frente na altura do quadril, peso à frente

FRAMES = 19


def build(k0):
    """`k0` = pose de guarda (canal -> valor)."""
    h0 = k0["hand_r"]
    keys = {
        "pelvis_pos": [(0, k0["pelvis_pos"]), (18, k0["pelvis_pos"])],
        "pelvis_yaw": [(0, k0["pelvis_yaw"]), (2, k0["pelvis_yaw"] + 2), (9, -2.0), (18, -4.0)],
        "pelvis_pitch": [(0, k0["pelvis_pitch"]), (9, 8.0), (18, 8.0)],
        "chest_yaw": [(0, k0["chest_yaw"]), (2, 10.0), (6, -12.0), (9, -26.0), (13, -22.0), (18, -20.0)],
        "chest_pitch": [(0, k0["chest_pitch"]), (2, 12.0), (9, 8.0), (18, 8.0)],
        "chest_roll": [(0, k0["chest_roll"]), (2, 4.0), (9, -5.0), (18, -4.0)],
        "hand_r": [
            (0, h0),
            (2, (h0[0] - 0.02, h0[1] - 0.04, h0[2] - 0.03)),            # recua e cede no impacto
            (5, (-0.24, -0.46, 1.20)),
            (9, (-0.40, -0.56, 1.02)),                                  # fim do varrido, à direita
            (13, (-0.34, -0.58, 1.00)),
            (18, (-0.32, -0.56, 1.00)),
        ],
        "blade_dir": [
            (0, k0["blade_dir"]),
            (2, (0.40, -0.62, 0.66)),                                   # cruza a linha de ataque
            (5, (-0.15, -0.85, 0.50)),
            (9, (-0.78, -0.55, 0.12)),                                  # empurrada para a direita, para fora
            (13, (-0.52, -0.82, 0.22)),
            (18, (-0.40, -0.86, 0.26)),                                 # pronto: à frente, na altura do quadril
        ],
        "foot_r": [(0, k0["foot_r"]), (18, k0["foot_r"])],
        "foot_l": [(0, k0["foot_l"]), (18, k0["foot_l"])],
        "foot_r_yaw": [(0, k0["foot_r_yaw"]), (18, k0["foot_r_yaw"])],
        "foot_l_yaw": [(0, k0["foot_l_yaw"]), (18, k0["foot_l_yaw"])],
    }
    return keys, FRAMES, 0.0, 0, 1
