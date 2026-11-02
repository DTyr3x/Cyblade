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
##   ESTÁVEL ─máximo─► QUEBRADO ─botão─► FINALIZANDO ─contato─► ESTÁVEL (rebote)
##                        │  ▲               │
##                        │  └── cancelou ───┘
##                        └── tempo acabou ───────────────► ESTÁVEL (rebote)

## Toda pressão aceita. `info`: fonte, ganho, pressão atual e cravada depois do evento.
signal pressure_applied(info: Dictionary)
signal full_reached
## A postura quebrou. `by_precision`: o último golpe cravava (contra-corte).
signal broken(by_precision: bool)
## A quebra acabou sem finalização.
signal recovered
## A Cravada completou.
signal finished

enum Source { HIT, PARRY, EVADE }
enum State { STABLE, BROKEN, FINISHING }

var data: PostureData
## Configuração de treino: desligado, nenhuma fonte altera a pressão (isola os testes do C1 e o Instrutor
## didático). O total de parry continua sendo somado, porque é o contador do C1.
var enabled := true
## Desligado, a postura enche e só registra (treino da pressão e testes do núcleo).
var break_enabled := true
var state := State.STABLE
var broken_until := -INF
var rebound_until := -INF
var exposed_until := -INF
var breaks := 0
var finishes := 0
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
var _finish_left := 0.0


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


## Esquiva justa: gera e crava. Quem detecta a ameaça real é o inimigo (`TrainingInstructor._credit_evade`).
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
	if state != State.STABLE:
		return 0.0
	var gain := amount
	if source == Source.HIT and not locks and t <= exposed_until:
		gain *= data.exposed_multiplier
	if t < rebound_until:
		gain *= data.rebound_gain_ratio
	gain = minf(gain, max_posture() * data.max_single_gain_ratio)
	if source != Source.HIT:
		gain = minf(gain, maxf(defense_limit() - current, 0.0))
	var was_full := is_full()
	current = minf(current + gain, max_posture())
	if locks:
		locked = maxf(locked, minf(current, lock_limit()))
	_last_gain_t = t
	pressure_applied.emit({"source": source, "gain": gain, "locks": locks, "current": current, "locked": locked, "time": t})
	if is_full() and not was_full:
		times_full += 1
		full_reached.emit()
		if break_enabled:
			_break(t, locks)
	return gain


## Recuperação até o instante `t`, em forma fechada: o resultado não depende do tamanho dos passos.
func update(t: float) -> void:
	if not enabled:
		_updated_t = t
		return
	if state == State.BROKEN and t >= broken_until:
		_end_break(t)
		recovered.emit()
	if t <= _updated_t or state != State.STABLE:
		_updated_t = maxf(_updated_t, t)
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


## Abre a exposição até `until`: golpes comuns pressionam mais (o contra-corte já crava e não recebe o bônus).
func expose(until: float) -> void:
	exposed_until = maxf(exposed_until, until)


func can_finish(t: float) -> bool:
	return state == State.BROKEN and t <= broken_until


## A Cravada começou: a janela congela e o inimigo não levanta no meio do golpe.
func begin_finish(t: float) -> void:
	_finish_left = broken_until - t
	state = State.FINISHING


## Cancelou antes do contato: a janela volta a correr.
func cancel_finish(t: float) -> void:
	if state == State.FINISHING:
		state = State.BROKEN
		broken_until = t + maxf(_finish_left, data.finish_resume_min)


func complete_finish(t: float) -> void:
	if state != State.FINISHING:
		return
	finishes += 1
	_end_break(t)
	finished.emit()


## Quebra sem encher pela pressão (inimigo no fim da vida).
func force_break(t: float) -> void:
	if enabled and break_enabled and state == State.STABLE:
		current = max_posture()
		_break(t, false)


func _break(t: float, by_precision: bool) -> void:
	state = State.BROKEN
	breaks += 1
	broken_until = t + data.break_duration + (data.break_precision_bonus if by_precision else 0.0)
	broken.emit(by_precision)


## Fim da quebra, com ou sem finalização: postura zerada, rebote e postura máxima maior neste confronto.
func _end_break(t: float) -> void:
	state = State.STABLE
	current = 0.0
	locked = 0.0
	rebound_until = t + data.rebound_time
	_last_gain_t = t
	_updated_t = t
	escalate()


## Aplica um aumento da postura máxima. Devolve false se o limite do confronto já foi usado.
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
	state = State.STABLE
	broken_until = -INF
	rebound_until = -INF
	exposed_until = -INF
	_last_gain_t = -INF
	_updated_t = -INF
