class_name EnemyAttackData
extends Resource
## Um ataque inimigo (C1: o golpe do Instrutor). Só dados, em segundos.
##
##   espera ─► preparação (windup) ─► golpe (strike_time) ─► recuperação ─► espera (interval)
##                      sinal forte em (contato - cue_lead)      contato em active_start do golpe

const DEFAULT_PATH := "res://game/data/instrutor_ataque.tres"

@export var display_name := "Golpe do Instrutor"
@export_group("Tempo")
@export var windup := 0.60
## O sinal didático (brilho + "tic") acontece este tempo antes do contato.
@export var cue_lead := 0.25
@export var strike_time := 0.12
## Janela de contato dentro do golpe (s a partir do início do golpe).
@export var active_start := 0.06
@export var active_end := 0.12
@export var recovery := 0.50
## Desequilíbrio depois de sofrer parry perfeito (s).
@export var off_balance := 0.80

@export_group("Alcance e efeito")
@export var attack_range := 2.2
@export var arc_deg := 90.0
@export var damage := 20.0
## Reservado para o C2 (postura do jogador).
@export var posture_damage := 15.0
## Reservado: golpes que não podem ser defendidos.
@export var parryable := true


static func load_default() -> EnemyAttackData:
	if ResourceLoader.exists(DEFAULT_PATH):
		var res := load(DEFAULT_PATH) as EnemyAttackData
		if res != null:
			return res
	return EnemyAttackData.new()


## Tempo desde o início da preparação até o contato.
func time_to_contact() -> float:
	return windup + active_start
