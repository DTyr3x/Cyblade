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

@export_group("Esquiva justa")
@export_range(0.0, 50.0, 0.5) var evade_pressure := 14.0
## A esquiva começou até este tempo (s) antes do contato, com o jogador dentro da ameaça.
@export_range(0.05, 0.4, 0.01) var evade_window := 0.20

@export_group("Exposição")
## Golpes comuns valem isto enquanto o inimigo está exposto (desequilíbrio do parry ou depois da esquiva justa).
@export_range(1.0, 3.0, 0.05) var exposed_multiplier := 1.5
@export_range(0.0, 3.0, 0.05) var evade_exposed_time := 1.0

@export_group("Quebra")
@export_range(0.5, 5.0, 0.05) var break_duration := 1.8
## Janela extra quando a quebra veio de um golpe que crava (contra-corte).
@export_range(0.0, 2.0, 0.05) var break_precision_bonus := 0.4
@export_range(0.0, 0.3, 0.01) var break_hitstop := 0.10
## Depois da quebra, por este tempo (s) a pressão ganha vale `rebound_gain_ratio`.
@export_range(0.0, 10.0, 0.1) var rebound_time := 3.0
@export_range(0.0, 1.0, 0.05) var rebound_gain_ratio := 0.5
## Espera do inimigo antes do primeiro ataque depois de se levantar (s).
@export_range(0.0, 3.0, 0.05) var post_break_interval := 0.6

@export_group("Finalização")
@export_range(0.5, 6.0, 0.05) var finish_range := 2.6
## Arco, em torno da direção pressionada (ou da frente), em que o alvo pode ser finalizado.
@export_range(30.0, 360.0, 5.0) var finish_arc_deg := 180.0
## Distância em que a Cravada para diante do alvo.
@export_range(0.5, 2.0, 0.05) var finish_stop_distance := 1.05
## Cancelou antes do contato: a janela volta com pelo menos este tempo (s).
@export_range(0.0, 1.0, 0.05) var finish_resume_min := 0.25
## Tempo no chão depois da Cravada (Instrutor).
@export_range(0.0, 5.0, 0.1) var finish_down_time := 1.2
## Fração da vida máxima que a Cravada tira.
@export_range(0.0, 1.0, 0.01) var finish_health_ratio := 0.40

@export_group("Recompensas (contadores: o efeito da Energia Neural fica para o C3)")
@export var break_neural_energy := 10.0
@export var finish_neural_energy := 30.0

@export_group("Escalonamento")
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
