class_name CombatController
extends Node
## Estado de combate do jogador: qual golpe está ativo, em que fase, buffer de entrada,
## janelas de encadeamento e de cancelamento. NÃO conhece animação, efeitos nem alvos: só
## emite sinais. O Player consulta e aplica movimento; o visual e os efeitos escutam.
##
## Fases de um golpe (tempos de clipe de StrikeData, divididos por `speed` para virar real):
##   WINDUP   preparação, até `active_start`
##   ACTIVE   contato: a lâmina pode acertar, até `active_end`
##   RECOVERY recuperação; encadeia a partir de `chain_open`, cancela por esquiva em
##            `dodge_cancel_from` e por movimento em `move_cancel_from`

signal strike_started(data: StrikeData, index: int, swing_id: int)
signal strike_ended(data: StrikeData, completed: bool)
signal strike_phase_changed(phase: int)
signal hitstop_started(duration: float)

enum Phase { NONE, WINDUP, ACTIVE, RECOVERY }

var combo: ComboSet
var phase := Phase.NONE
var current: StrikeData
var index := -1
## Identificador único de cada golpe executado (evita acertar o mesmo alvo duas vezes no mesmo golpe).
var swing_id := 0
## Tempo REAL decorrido no golpe atual (s). Congela durante o hitstop.
var time := 0.0

var _buffer := 0.0
var _since_end := 99.0
var _next_index := 0
var _hitstop := 0.0
var _phase_before := Phase.NONE
## Preenchidos durante a troca de um golpe por outro (encadeamento): quem escuta `strike_ended` e
## `strike_started` sabe que o corpo não deve voltar à locomoção entre os dois.
var chaining := false
## O golpe em curso é o contra-golpe de oportunidade.
var is_counter := false
var chained_from: StrikeData = null
var chained_from_clip_time := 0.0


func _init(combo_set: ComboSet = null) -> void:
	combo = combo_set if combo_set != null else ComboSet.load_default()


func is_attacking() -> bool:
	return phase != Phase.NONE


## Tempo do clipe (s, relativo ao início do trecho) correspondente ao tempo real decorrido.
func clip_time() -> float:
	return time * current.speed if current != null else 0.0


func in_hitstop() -> bool:
	return _hitstop > 0.0


## Registra a intenção de atacar (chamado quando o botão é apertado).
func press_attack() -> void:
	_buffer = combo.input_buffer_time


## Há ataque guardado esperando.
func has_buffered_attack() -> bool:
	return _buffer > 0.0


func consume_buffer() -> void:
	_buffer = 0.0


## Começa um golpe se possível. Devolve true se começou.
## `can_act`: o jogador está livre para atacar (não está esquivando).
func try_start(can_act: bool) -> bool:
	if not can_act or _buffer <= 0.0:
		return false
	if phase == Phase.NONE:
		_start(_next_index if _since_end <= combo.combo_reset_time else 0)
		return true
	if clip_time() >= current.chain_open:
		_start((index + 1) % combo.strikes.size())
		return true
	return false


func _start(i: int) -> void:
	is_counter = false
	var finished_before := current
	chained_from = null
	if phase != Phase.NONE and finished_before != null:
		chained_from = finished_before
		chained_from_clip_time = clip_time()
		chaining = true
		strike_ended.emit(finished_before, true)
		chaining = false
	index = i
	current = combo.strikes[i]
	swing_id += 1
	time = 0.0
	_buffer = 0.0
	_hitstop = 0.0
	_next_index = (i + 1) % combo.strikes.size()
	_set_phase(Phase.WINDUP)
	strike_started.emit(current, i, swing_id)


## Começa o contra-golpe de oportunidade. Só a Player chama, depois de gastar a oportunidade.
## Não mexe na cadeia: depois dele a próxima cadeia recomeça no golpe 1.
func start_counter() -> bool:
	if combo.counter_strike == null or phase != Phase.NONE:
		return false
	chained_from = null
	index = combo.strikes.size()   # fatia própria no AnimationTree, fora da cadeia
	current = combo.counter_strike
	swing_id += 1
	time = 0.0
	_buffer = 0.0
	_hitstop = 0.0
	_next_index = 0
	is_counter = true
	_set_phase(Phase.WINDUP)
	strike_started.emit(current, index, swing_id)
	return true


func dodge_cancel_open() -> bool:
	return phase != Phase.NONE and clip_time() >= current.dodge_cancel_from


func move_cancel_open() -> bool:
	return phase == Phase.RECOVERY and clip_time() >= current.move_cancel_from


## Interrompe o golpe (esquiva ou movimento). O encadeamento continua valendo por `combo_reset_time`.
func cancel() -> void:
	if phase == Phase.NONE:
		return
	var data := current
	_end_internal()
	strike_ended.emit(data, false)


## Congela o atacante por `duration` s reais (chamado pelo acerto).
func start_hitstop(duration: float) -> void:
	if duration > 0.0:
		_hitstop = maxf(_hitstop, duration)
		hitstop_started.emit(duration)


## Avança o relógio do combate. Devolve true se um golpe terminou por completo neste tick.
func tick(delta: float) -> bool:
	# O buffer congela junto com o relógio do golpe durante o hitstop: sem isso, o congelamento do
	# impacto consumiria o tempo de um aperto guardado e o encadeamento se perderia no acerto.
	if not (phase != Phase.NONE and _hitstop > 0.0):
		_buffer = maxf(_buffer - delta, 0.0)
	if phase == Phase.NONE:
		_since_end += delta
		return false
	if _hitstop > 0.0:
		_hitstop = maxf(_hitstop - delta, 0.0)
		return false
	time += delta
	var ct := clip_time()
	if ct >= current.clip_length() - 0.0001:
		var data := current
		_end_internal()
		strike_ended.emit(data, true)
		return true
	var target := Phase.WINDUP
	if ct >= current.active_end:
		target = Phase.RECOVERY
	elif ct >= current.active_start:
		target = Phase.ACTIVE
	if target != phase:
		_set_phase(target)
	return false


## Avanço (m) que o golpe quer aplicar entre dois instantes de tempo REAL, com perfil suave.
func advance_between(t0: float, t1: float) -> float:
	if current == null or current.advance_distance <= 0.0:
		return 0.0
	var a := _advance_fraction(t0 * current.speed)
	var b := _advance_fraction(t1 * current.speed)
	return (b - a) * current.advance_distance


func _advance_fraction(clip_t: float) -> float:
	var span := maxf(current.advance_end - current.advance_start, 0.0001)
	var s := clampf((clip_t - current.advance_start) / span, 0.0, 1.0)
	return s * s * (3.0 - 2.0 * s)


func _end_internal() -> void:
	_set_phase(Phase.NONE)
	_since_end = 0.0
	_hitstop = 0.0
	# `current` e `index` permanecem para o próximo golpe da cadeia; só `phase` indica "ativo".


func _set_phase(p: Phase) -> void:
	phase = p
	strike_phase_changed.emit(p)
