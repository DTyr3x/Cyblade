class_name PostureController
extends Node
## Núcleo de pressão de postura de UM inimigo (C2.0). Lógica pura: recebe o instante `t` do relógio de
## combate, nunca lê quadros, e não conhece animação, efeitos nem golpes específicos.
##
##   `current`  pressão atual: sobe com cada fonte e cai na recuperação.
##   `locked`   pressão cravada: piso de `current`. Não cai com a recuperação; só some no fim do confronto.
##
## `locked` é uma MARCA dentro de `current`, não uma segunda conta: cravar nunca soma pontos, então um evento
## que gera e crava pressão conta uma vez só. Invariante: 0 <= locked <= current <= max_posture().
##
## Chegar ao máximo nesta etapa só é registrado (`full_reached`): a quebra vem no C2.2.

## Toda pressão aceita. `info`: fonte, ganho, pressão atual e cravada depois do evento.
signal pressure_applied(info: Dictionary)
signal full_reached

enum Source { HIT, PARRY, EVADE }

var data: PostureData
## Configuração de treino: desligado, nenhuma fonte altera a pressão (isola os testes do C1 e o Instrutor
## didático). O total de parry continua sendo somado, porque é o contador do C1.
var enabled := true
var current := 0.0
var locked := 0.0
var escalation_steps := 0
## Quantas vezes a postura encheu (HUD e testes).
var times_full := 0
## Eventos repetidos descartados.
var rejected_events := 0
## Contador do C1: pressão de parry somada desde o início, sem recuperação.
var parry_pressure_total := 0.0

var _last_event := {Source.HIT: -1, Source.PARRY: -1, Source.EVADE: -1}
var _last_gain_t := -INF
var _updated_t := -INF


func _init(posture_data: PostureData = null) -> void:
	data = posture_data if posture_data != null else PostureData.load_default()


## Postura máxima com o escalonamento atual: base × (1 + por aplicação × aplicações).
func max_posture() -> float:
	return data.max_posture * (1.0 + data.escalation_per_step * escalation_steps)


func lock_limit() -> float:
	return max_posture() * data.lock_cap_ratio


## Até onde parry e esquiva podem levar a pressão: o trecho final exige um golpe que acerte.
func defense_limit() -> float:
	return max_posture() * (1.0 - data.offense_only_ratio)


func current_ratio() -> float:
	return current / max_posture()


func locked_ratio() -> float:
	return locked / max_posture()


func is_full() -> bool:
	return current >= max_posture() - 0.0001


## Golpe que ACERTOU o alvo. `event_id` é o número do golpe; `locks` vem do StrikeData (contra-corte).
func apply_hit(t: float, amount: float, locks: bool, event_id: int) -> float:
	return _apply(t, Source.HIT, amount * data.hit_gain_ratio, locks, event_id)


## Parry perfeito: gera e crava. `event_id` é o número do ataque inimigo.
func apply_parry(t: float, amount: float, event_id: int) -> float:
	if event_id > int(_last_event[Source.PARRY]):
		parry_pressure_total += amount
	return _apply(t, Source.PARRY, amount * data.parry_gain_ratio, true, event_id)


## Esquiva justa: gera e crava. Ainda sem quem chame no jogo: a detecção de ameaça real vem no C2.1.
func apply_evade(t: float, event_id: int) -> float:
	return _apply(t, Source.EVADE, data.evade_pressure * data.evade_gain_ratio, true, event_id)


func _apply(t: float, source: Source, amount: float, locks: bool, event_id: int) -> float:
	if amount <= 0.0:
		return 0.0
	# Um evento só conta uma vez, mesmo que chegue repetido (os números de golpe só crescem).
	if event_id <= int(_last_event[source]):
		rejected_events += 1
		return 0.0
	_last_event[source] = event_id
	if not enabled:
		return 0.0
	update(t)
	var gain := minf(amount, max_posture() * data.max_single_gain_ratio)
	if source != Source.HIT:
		gain = minf(gain, maxf(defense_limit() - current, 0.0))
	var was_full := is_full()
	current = minf(current + gain, max_posture())
	if locks:
		locked = maxf(locked, minf(current, lock_limit()))
	_last_gain_t = t
	pressure_applied.emit({"source": source, "gain": gain, "current": current, "locked": locked, "time": t})
	if is_full() and not was_full:
		times_full += 1
		full_reached.emit()
	return gain


## Recuperação até o instante `t`, em forma fechada: o resultado não depende do tamanho dos passos.
func update(t: float) -> void:
	if not enabled:
		_updated_t = t
		return
	if t <= _updated_t:
		return
	var from := maxf(_updated_t, _last_gain_t + data.recovery_delay)
	var reset_t := _last_gain_t + data.combat_reset_time
	var floor_until := minf(t, reset_t)
	if floor_until > from:
		current = maxf(locked, current - data.recovery_rate * (floor_until - from))
		from = floor_until
	if t >= reset_t:
		_end_confrontation()
		if t > from:
			current = maxf(current - data.recovery_rate * (t - from), 0.0)
	_updated_t = t


## Aplica um aumento da postura máxima (a quebra do C2.2 vai chamar). Devolve false se o limite já foi usado.
func escalate() -> bool:
	if escalation_steps >= data.escalation_max_steps:
		return false
	_set_escalation(escalation_steps + 1)
	return true


## Normalização: quando a postura máxima muda, a FRAÇÃO preenchida não muda (pressão atual e cravada são
## reescaladas juntas). Aumentar o máximo não dá nem tira progresso, e os limites seguem sendo frações.
func _set_escalation(steps: int) -> void:
	var before := max_posture()
	escalation_steps = steps
	var k := max_posture() / before
	current *= k
	locked *= k


func _end_confrontation() -> void:
	locked = 0.0
	if escalation_steps > 0:
		_set_escalation(0)


## Volta ao início (treino e testes). Não apaga o total de parry do C1 nem os números de evento.
func reset() -> void:
	current = 0.0
	locked = 0.0
	escalation_steps = 0
	_last_gain_t = -INF
	_updated_t = -INF
