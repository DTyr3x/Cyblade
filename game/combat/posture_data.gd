class_name PostureData
extends Resource
## Perfil de postura de um tipo de inimigo (C2). Só dados, em pontos e segundos; nenhum valor em quadros.
## A pressão de cada golpe mora no StrikeData e a do parry no DefenseData; aqui ficam as regras do alvo.
## Todos os valores são hipóteses iniciais de playtest (ver docs/c2-0-nucleo-postura.md).

const DEFAULT_PATH := "res://game/data/postura_instrutor.tres"

@export_group("Postura")
## Postura máxima antes de qualquer escalonamento.
@export_range(1.0, 500.0, 1.0) var max_posture := 100.0

@export_group("Recuperação")
## Sem nova pressão por este tempo (s), a pressão atual começa a cair.
@export_range(0.0, 5.0, 0.05) var recovery_delay := 1.5
## Queda da pressão atual (pontos por segundo). Para no piso cravado.
@export_range(0.0, 100.0, 0.5) var recovery_rate := 15.0
## Sem nova pressão por este tempo (s), o confronto acaba: o piso cravado e o escalonamento somem.
@export_range(1.0, 30.0, 0.5) var combat_reset_time := 8.0

@export_group("Cravar e limites")
## Teto da pressão cravada, como fração da postura máxima.
@export_range(0.0, 1.0, 0.01) var lock_cap_ratio := 0.80
## Trecho final da postura que só um golpe que acerta pode preencher (parry e esquiva param antes dele).
@export_range(0.0, 1.0, 0.01) var offense_only_ratio := 0.20
## Teto de um único ganho, como fração da postura máxima.
@export_range(0.05, 1.0, 0.01) var max_single_gain_ratio := 0.40

@export_group("Multiplicadores por fonte")
## Quanto este tipo de inimigo sente cada fonte (1 = valor do golpe, do parry ou da esquiva).
@export_range(0.0, 3.0, 0.05) var hit_gain_ratio := 1.0
@export_range(0.0, 3.0, 0.05) var parry_gain_ratio := 1.0
@export_range(0.0, 3.0, 0.05) var evade_gain_ratio := 1.0

@export_group("Esquiva justa (integração pronta; a detecção vem no C2.1)")
@export_range(0.0, 50.0, 0.5) var evade_pressure := 14.0

@export_group("Escalonamento (planejado para a quebra do C2.2)")
## Cada aplicação soma esta fração à postura máxima, sobre o valor base (0,25 + 0,25 = ×1,5).
@export_range(0.0, 1.0, 0.01) var escalation_per_step := 0.25
## Aplicações permitidas por confronto.
@export_range(0, 5) var escalation_max_steps := 2


static func load_default() -> PostureData:
	if ResourceLoader.exists(DEFAULT_PATH):
		var res := load(DEFAULT_PATH) as PostureData
		if res != null:
			return res
	return PostureData.new()
