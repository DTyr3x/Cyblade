class_name CombatVitals
extends Node
## Vida do jogador para TREINO (sem morte: zerou, volta cheia e conta uma derrota) e contadores
## provisórios do C1. A Energia Neural e a pressão de postura só são somadas; o efeito vem no C2/C3.

signal changed

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
	health -= amount
	_since_damage = 0.0
	if health <= 0.0:
		defeats += 1
		health = max_health
	changed.emit()


func add_neural_energy(amount: float) -> void:
	neural_energy += amount
	changed.emit()


func tick(delta: float) -> void:
	_since_damage += delta
	if _since_damage >= regen_delay and health < max_health:
		health = minf(health + regen_rate * delta, max_health)
