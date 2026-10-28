class_name PlayerTuning
extends Resource
## Parâmetros de movimento e esquiva. Valores são pontos de partida para playtest,
## ancorados na pesquisa de Dinghai onde há medição (ver docs/adr/0002-movimento.md).

@export_group("Movimento")
## Velocidade máxima de corrida, m/s (referência medida: ~5–7 m/s).
@export var max_speed := 6.0
## Tempo até a velocidade máxima, s (câmera de referência: ~0,13 s).
@export var accel_time := 0.12
## Tempo de frenagem até parar, s (referência: parada quase imediata).
@export var decel_time := 0.08
## Multiplicador de aceleração ao inverter o sentido.
@export var reverse_accel_multiplier := 1.5
## Velocidade de giro do corpo, graus/s.
@export var turn_rate_deg := 1080.0
@export var gravity := 30.0

@export_group("Esquiva")
## Distância total do deslocamento, m (referência: ~3–5 m).
@export var dodge_distance := 4.0
## Duração do deslocamento, s (referência: ~0,23–0,27 s).
@export var dodge_duration := 0.25
## Recuperação sem controle após o deslocamento, s (referência: total ~0,43 s).
@export var dodge_recovery := 0.18
## Quanto tempo uma esquiva pedida durante a recuperação continua valendo, s.
@export var dodge_buffer_time := 0.15
## Janela de invulnerabilidade dentro do deslocamento, s. Escolha de design nossa:
## i-frames não foram confirmados em Dinghai.
@export var dodge_iframe_start := 0.05
@export var dodge_iframe_end := 0.20


func accel() -> float:
	return max_speed / accel_time


func decel() -> float:
	return max_speed / decel_time
