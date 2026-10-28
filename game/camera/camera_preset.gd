class_name CameraPreset
extends Resource
## Um enquadramento de câmera. A câmera troca de preset com suavização.

@export var preset_name := "padrão"
## Inclinação para baixo, graus (0 = horizontal, 90 = de cima).
@export var pitch_deg := 45.0
## Distância do foco até a câmera, m.
@export var distance := 20.0
## Campo de visão vertical, graus.
@export var fov_deg := 34.0
## Altura do ponto de foco acima dos pés do jogador, m.
@export var focus_height := 1.0
## Desloca o foco para a frente da câmera, m. Positivo põe o jogador mais baixo na tela.
@export var framing_shift := 0.0
## Constante de tempo do acompanhamento, s (menor = mais colado).
@export var follow_tau := 0.10
## Antecipação do movimento, m (distância máxima à frente na velocidade de referência).
@export var look_ahead := 0.4
@export var look_ahead_tau := 0.3
## Tempo aproximado para completar a troca para este preset, s.
@export var blend_time := 0.6
