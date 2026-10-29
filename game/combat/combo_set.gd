class_name ComboSet
extends Resource
## Sequência de golpes de uma arma. Hoje é uma lista linear; a futura Forja de Combos poderá
## montar outros ComboSet (ou ramificações) sem tocar no controlador de combate.

const DEFAULT_PATH := "res://game/data/katana_combo.tres"

@export var weapon_family: StringName = WeaponStance.KATANA
@export var strikes: Array[StrikeData] = []
## Depois de terminar um golpe, o encadeamento ainda vale por este tempo (s); depois recomeça no 1.
@export var combo_reset_time := 0.55
## Quanto tempo um ataque apertado antes da hora fica guardado (s).
@export var input_buffer_time := 0.25
## Alcance e ângulo da assistência de mira (alvo mais próximo na frente do personagem).
@export var aim_assist_range := 6.0
@export_range(0.0, 180.0) var aim_assist_angle_deg := 75.0


static func load_default() -> ComboSet:
	if ResourceLoader.exists(DEFAULT_PATH):
		var res := load(DEFAULT_PATH) as ComboSet
		if res != null and not res.strikes.is_empty():
			return res
	return katana_default()


## Valores de partida dos 3 golpes (também gravados em `game/data/katana_combo.tres`).
static func katana_default() -> ComboSet:
	var set := ComboSet.new()
	var s1 := StrikeData.new()
	s1.id = &"corte_diagonal"
	s1.display_name = "Corte diagonal"
	s1.mirrored = false
	s1.speed = 1.8
	s1.reaction = StrikeData.Reaction.LIGHT_LEFT
	s1.damage = 10.0
	s1.hitstop = 0.05
	s1.knockback = 0.15

	var s2 := StrikeData.new()
	s2.id = &"corte_reverso"
	s2.display_name = "Corte reverso"
	s2.mirrored = true
	s2.speed = 1.85
	s2.reaction = StrikeData.Reaction.LIGHT_RIGHT
	s2.damage = 10.0
	s2.hitstop = 0.05
	s2.knockback = 0.15

	var s3 := StrikeData.new()
	s3.id = &"golpe_final"
	s3.display_name = "Golpe final"
	s3.clip_from = 0.08
	s3.clip_to = 1.35
	s3.speed = 1.35
	s3.active_start = 0.26
	s3.active_end = 0.50
	s3.chain_open = 0.78
	s3.dodge_cancel_from = 0.10
	s3.move_cancel_from = 0.85
	s3.advance_distance = 1.5
	s3.advance_start = 0.12
	s3.advance_end = 0.46
	s3.turn_lock = 0.24
	s3.damage = 25.0
	s3.hitstop = 0.09
	s3.knockback = 0.55
	s3.reaction = StrikeData.Reaction.HEAVY
	s3.camera_shake = 0.03

	set.strikes = [s1, s2, s3]
	return set
