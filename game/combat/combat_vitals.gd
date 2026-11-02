class_name CombatVitals
extends Node
## Vida do jogador. Em treino não há morte (zerou, volta cheia e conta uma derrota); no confronto, `defeated`
## encerra a luta. A Energia Neural só é somada; o efeito vem no C3.

signal changed
signal defeated

## Treino: zerou, volta cheia. Fora dele a vida fica em zero e `defeated` é emitido.
@export var training := true

@export var max_health := 100.0
## Depois de tanto tempo sem dano, a vida volta a esta taxa (por segundo).
@export var regen_delay := 2.5
@export var regen_rate := 30.0

var health := 100.0
var defeats := 0
var neural_energy := 0.0
var _since_damage := 99.0


func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if health <= 0.0:
		return
	health -= amount
	_since_damage = 0.0
	if health <= 0.0:
		defeats += 1
		if training:
			health = max_health
		else:
			health = 0.0
			defeated.emit()
	changed.emit()


func heal(amount: float) -> void:
	if health > 0.0:
		health = minf(health + amount, max_health)
		changed.emit()


func add_neural_energy(amount: float) -> void:
	neural_energy += amount
	changed.emit()


func tick(delta: float) -> void:
	_since_damage += delta
	if _since_damage >= regen_delay and health < max_health and health > 0.0:
		health = minf(health + regen_rate * delta, max_health)
