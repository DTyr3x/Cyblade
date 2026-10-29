class_name CombatClock
extends RefCounted
## Relógio de simulação do combate (s). Avança uma vez por passo de física (a Main chama `advance`
## antes dos filhos), então aperto e contato são comparados no MESMO relógio, independente do FPS de
## render. Resolução: um passo de física (1/120 s).

static var time := 0.0


static func advance(delta: float) -> void:
	time += delta
