class_name DefenseData
extends Resource
## Parâmetros da defesa e do parry (C1). Só dados, todos em SEGUNDOS (nada depende de contar quadros).
## Valores iniciais aprovados para protótipo; ajustar em playtest (`game/data/defesa.tres`).

const DEFAULT_PATH := "res://game/data/defesa.tres"

@export_group("Parry")
## Contato até este tempo depois do APERTO = parry perfeito (vale mesmo se o botão já foi solto).
@export_range(0.05, 0.30, 0.005) var perfect_window := 0.14
## Depois de uma tentativa sem contato (parry em falso), por este tempo um novo aperto só levanta a
## guarda normal, sem janela perfeita. Não trava movimento, ataque nem esquiva.
@export_range(0.0, 1.0, 0.01) var whiff_lockout := 0.25
## Congelamento local (jogador e Instrutor) no parry perfeito.
@export_range(0.0, 0.2, 0.005) var parry_hitstop := 0.07

@export_group("Defesa normal")
## Atraso até a guarda valer depois do aperto (0 = imediata).
@export_range(0.0, 0.1, 0.005) var guard_startup := 0.0
## Fração do dano que passa pela defesa normal.
@export_range(0.0, 1.0, 0.01) var block_damage_ratio := 0.20
## Empurrão do bloqueio (m) e duração dele (s).
@export var block_pushback := 0.20
@export var block_pushback_time := 0.10
## Depois de bloquear, a guarda fica erguida por este tempo mesmo soltando o botão (a esquiva cancela).
@export_range(0.0, 0.5, 0.01) var block_recovery := 0.15
@export_range(0.0, 0.2, 0.005) var block_hitstop := 0.03
## Velocidade andando de guarda (m/s).
@export var guard_move_speed := 2.5

@export_group("Golpe recebido")
## Reação ao levar o golpe (s); a esquiva cancela.
@export_range(0.0, 1.0, 0.01) var hit_reaction := 0.30
@export var hit_knockback := 0.30

@export_group("Entrada")
## Aperto de defesa durante uma ação que ainda não pode ser cancelada fica guardado por este tempo.
@export_range(0.0, 0.3, 0.01) var input_buffer := 0.10

@export_group("Contra-ataque de oportunidade (C1.1)")
## Depois de um parry PERFEITO, por este tempo o jogador pode contra-atacar com J (a oportunidade).
## Separada do desequilíbrio do Instrutor: são dois tempos independentes.
@export_range(0.1, 2.0, 0.01) var counter_window := 0.80
## Elegibilidade: só o parry perfeito abre a oportunidade (defesa normal e golpe recebido não).
@export var counter_requires_perfect := true
## Consumo: quantos contra-ataques um único parry rende (1 = nunca contra-ataques grátis em sequência).
@export_range(1, 3) var counter_charges := 1

@export_group("Recompensas (contadores do C1; efeito no C2/C3)")
@export var parry_posture_pressure := 25.0
@export var parry_neural_energy := 10.0


static func load_default() -> DefenseData:
	if ResourceLoader.exists(DEFAULT_PATH):
		var res := load(DEFAULT_PATH) as DefenseData
		if res != null:
			return res
	return DefenseData.new()
