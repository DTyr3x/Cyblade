class_name ComboSet
extends Resource
## Sequência de golpes de uma arma. Hoje é uma lista linear; a futura Forja de Combos poderá
## montar outros ComboSet (ou ramificações) sem tocar no controlador de combate.

const DEFAULT_PATH := "res://game/data/katana_combo.tres"
## Clipe autoral do golpe 1 (gerado por tools/build_katana_strike.ps1).
const KESA_CLIP := "res://assets/animations/katana/katana_kesa.res"
## Clipe autoral do golpe 2 (tools/build_katana_strike.ps1).
const KIRIAGE_CLIP := "res://assets/animations/katana/katana_kiriage.res"
## Clipe autoral do golpe 3 (tools/build_katana_strike.ps1).
const TSUKI_CLIP := "res://assets/animations/katana/katana_tsuki.res"
## Clipes autorais do C1.1 (tools/build_katana_strike.ps1).
const COUNTER_CLIP := "res://assets/animations/katana/katana_contra.res"

@export var weapon_family: StringName = WeaponStance.KATANA
@export var strikes: Array[StrikeData] = []
## Contra-golpe de oportunidade (C1.1): fora da cadeia. Só começa pela oportunidade aberta por um parry
## perfeito (ver DefenseController); fora dela a cadeia normal vale, como antes.
@export var counter_strike: StrikeData
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
	# Golpe 1 (H2.1): "Kesa avançado", animação autoral (tools/blender/author_katana_strike.py).
	# Tempos em quadros de 60 Hz do clipe: preparação 0-6, contato 7-13, encadeia 17, livre 21.
	var s1 := StrikeData.new()
	s1.id = &"kesa_avancado"
	s1.display_name = "Kesa avançado"
	s1.clip_resource = load(KESA_CLIP) as Animation
	s1.authored_grip = true
	s1.clip_from = 0.0
	s1.clip_to = 33.0 / 60.0
	s1.speed = 1.0
	s1.active_start = 7.0 / 60.0
	s1.active_end = 13.0 / 60.0
	s1.chain_open = 17.0 / 60.0
	s1.dodge_cancel_from = 3.0 / 60.0
	s1.move_cancel_from = 21.0 / 60.0
	s1.advance_distance = 0.9
	s1.advance_start = 3.0 / 60.0
	s1.advance_end = 15.0 / 60.0
	s1.turn_lock = 6.0 / 60.0
	s1.hitstop = 0.06
	s1.reaction = StrikeData.Reaction.LIGHT_LEFT
	s1.damage = 10.0
	s1.knockback = 0.15

	# Golpe 2 (H2.2): "Kiriage de retorno", animação autoral que NASCE da pose do Kesa no quadro 17
	# (tools/blender/katana_kiriage_keys.py). Quadros de 60 Hz: preparação 0-7, contato 8-13,
	# encadeia 17, livre 20, fim 30.
	var s2 := StrikeData.new()
	s2.id = &"kiriage_de_retorno"
	s2.display_name = "Kiriage de retorno"
	s2.clip_resource = load(KIRIAGE_CLIP) as Animation
	s2.authored_grip = true
	s2.seamless_chain = true
	s2.sync_swish = true
	s2.clip_from = 0.0
	s2.clip_to = 30.0 / 60.0
	s2.speed = 1.0
	s2.active_start = 8.0 / 60.0
	s2.active_end = 13.0 / 60.0
	s2.chain_open = 17.0 / 60.0
	s2.dodge_cancel_from = 3.0 / 60.0
	s2.move_cancel_from = 20.0 / 60.0
	s2.advance_distance = 0.6
	s2.advance_start = 2.0 / 60.0
	s2.advance_end = 12.0 / 60.0
	s2.turn_lock = 5.0 / 60.0
	s2.reaction = StrikeData.Reaction.LIGHT_RIGHT
	s2.damage = 10.0
	s2.hitstop = 0.06
	s2.knockback = 0.15

	# Golpe 3 (H2.3): "Tsuki de passo duplo", finalizador autoral que NASCE da pose do Kiriage no quadro 17
	# (tools/blender/katana_tsuki_keys.py). Quadros de 60 Hz: coil 0-6, passo 1 6-13, passo 2 e
	# estocada 13-17, extensão 17-22, encadeia 28, livre 26, fim 36.
	var s3 := StrikeData.new()
	s3.id = &"tsuki_de_passo_duplo"
	s3.display_name = "Tsuki de passo duplo"
	s3.clip_resource = load(TSUKI_CLIP) as Animation
	s3.authored_grip = true
	s3.seamless_chain = true
	s3.sync_swish = true
	s3.clip_from = 0.0
	s3.clip_to = 36.0 / 60.0
	s3.speed = 1.0
	s3.active_start = 14.0 / 60.0
	s3.active_end = 21.0 / 60.0
	s3.chain_open = 28.0 / 60.0
	s3.dodge_cancel_from = 3.0 / 60.0
	s3.move_cancel_from = 26.0 / 60.0
	s3.advance_distance = 1.2
	s3.advance_start = 4.0 / 60.0
	s3.advance_end = 20.0 / 60.0
	s3.turn_lock = 8.0 / 60.0
	s3.damage = 25.0
	s3.hitstop = 0.10
	s3.knockback = 0.8
	s3.reaction = StrikeData.Reaction.HEAVY
	s3.camera_shake = 0.03

	set.strikes = [s1, s2, s3]
	set.counter_strike = counter_default()
	return set


## Contra-corte (C1.1): corte horizontal curto e rápido, da direita para a esquerda, que nasce da pose
## de saída da deflexão (tools/blender/katana_counter_keys.py). Quadros de 60 Hz: coil 0-4, contato
## 5-10, livre 14, fim 22.
static func counter_default() -> StrikeData:
	var c := StrikeData.new()
	c.id = &"contra_corte"
	c.display_name = "Contra-corte"
	c.clip_resource = load(COUNTER_CLIP) as Animation
	c.authored_grip = true
	c.sync_swish = true
	c.clip_from = 0.0
	c.clip_to = 22.0 / 60.0
	c.speed = 1.0
	c.active_start = 5.0 / 60.0
	c.active_end = 10.0 / 60.0
	c.chain_open = 22.0 / 60.0
	c.dodge_cancel_from = 2.0 / 60.0
	c.move_cancel_from = 14.0 / 60.0
	c.advance_distance = 0.7
	c.advance_start = 2.0 / 60.0
	c.advance_end = 10.0 / 60.0
	c.turn_lock = 4.0 / 60.0
	c.damage = 30.0
	c.hitstop = 0.09
	c.knockback = 0.5
	c.reaction = StrikeData.Reaction.LIGHT_RIGHT
	return c
