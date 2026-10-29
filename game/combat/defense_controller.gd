class_name DefenseController
extends Node
## Estado defensivo do jogador e resolução temporal do contato (C1). Lógica pura: recebe tempos do
## CombatClock, não lê entrada nem conhece animação ou efeitos (só emite sinais).
##
##   aperto ─┬─ janela perfeita ─┬─ guarda normal (enquanto segurar) ─ soltar
##           │  contato = PARRY  │  contato = DEFESA
##           └───────────────────┴─ janela acabou sem contato = parry em falso (bloqueio de nova janela)

signal resolved(result: int, info: Dictionary)
signal whiffed(time: float)

enum Result { PERFECT, BLOCK, HIT }

var data: DefenseData

## Botão de defesa segurado.
var guarding := false
var last_result := -1
## Contato menos aperto (s) do último resultado; para o HUD ("PARRY +62 ms").
var last_offset := 0.0
## Quando o aperto chega DEPOIS de um golpe recebido: quanto atrasou (s). -1 = não se aplica.
var last_late_by := -1.0
var whiff_count := 0

var _press_t := -INF
var _perfect_until := -INF
var _attempt_open := false
var _lockout_until := -INF
var _block_until := -INF
var _last_hit_t := -INF


func _init(defense_data: DefenseData = null) -> void:
	data = defense_data if defense_data != null else DefenseData.load_default()


## O jogador apertou defesa em `t` (mesmo que a guarda só comece depois, por estar em reação ou
## no buffer). Serve para dizer no HUD quanto o aperto atrasou em relação ao último golpe recebido.
func note_input(t: float) -> void:
	last_late_by = (t - _last_hit_t) if t - _last_hit_t <= 0.3 else -1.0


## Aperto do botão de defesa no instante `t`. Abre a janela perfeita, salvo durante o bloqueio de
## parry em falso (aí só levanta a guarda normal).
func press(t: float) -> void:
	guarding = true
	_press_t = t
	if t < _lockout_until:
		_perfect_until = -INF
		_attempt_open = false
	else:
		_perfect_until = t + data.perfect_window
		_attempt_open = true


func release(_t: float) -> void:
	guarding = false


## Fecha a tentativa quando a janela acaba sem contato (parry em falso).
func update(t: float) -> void:
	if _attempt_open and t > _perfect_until:
		_attempt_open = false
		_lockout_until = t + data.whiff_lockout
		whiff_count += 1
		whiffed.emit(t)


func perfect_open(t: float) -> bool:
	return _attempt_open and t >= _press_t and t <= _perfect_until


func in_lockout(t: float) -> bool:
	return t < _lockout_until


## A guarda está valendo (segurando, dentro da janela de um toque ou na recuperação de bloqueio).
func is_defending(t: float) -> bool:
	if t < _press_t + data.guard_startup and not perfect_open(t):
		return false
	return guarding or perfect_open(t) or t < _block_until


func in_block_recovery(t: float) -> bool:
	return t < _block_until


## Resolve um contato inimigo no instante `t`. Devolve {result, damage, offset}.
func resolve(t: float, damage: float) -> Dictionary:
	var result := Result.HIT
	var dmg := damage
	if perfect_open(t):
		result = Result.PERFECT
		dmg = 0.0
		_attempt_open = false
	elif is_defending(t):
		result = Result.BLOCK
		dmg = damage * data.block_damage_ratio
		_block_until = t + data.block_recovery
	else:
		_last_hit_t = t
	last_result = result
	last_offset = t - _press_t
	var info := {"result": result, "damage": dmg, "offset": last_offset, "time": t}
	resolved.emit(result, info)
	return info
