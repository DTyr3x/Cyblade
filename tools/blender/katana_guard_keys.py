# Pose de GUARDA (C1, defesa/parry): pose estática, aplicada só ao tronco e aos braços no jogo
# (as pernas continuam com a locomoção, para andar de guarda sem deslizar).
#
# Duas mãos no cabo, mãos à frente do peito, lâmina em diagonal à frente do rosto (ponta para cima e
# para a esquerda): a lâmina cruza a linha de ataque do inimigo. Tronco levemente inclinado, peso baixo.
# Mesmo espaço dos golpes: -Y é a frente, -X é a direita do personagem, Z para cima.


def build(_k0=None):
    pose = {
        "pelvis_pos": (0.0, 0.03, 0.86),
        "pelvis_yaw": -8.0,
        "pelvis_pitch": 6.0,
        "chest_yaw": 6.0,
        "chest_pitch": 8.0,
        "chest_roll": 2.0,
        "hand_r": (-0.10, -0.36, 1.30),
        "blade_dir": (0.55, -0.32, 0.77),
        "foot_r": (-0.13, -0.18, 0.10),
        "foot_l": (0.14, 0.18, 0.10),
        "foot_r_yaw": -10.0,
        "foot_l_yaw": 25.0,
    }
    keys = {ch: [(0, v), (1, v)] for ch, v in pose.items()}
    return keys, 2, 0.0, 0, 1
