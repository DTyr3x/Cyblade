class_name StrikeData
extends Resource
## Dados de UM golpe. Só dados: nenhum comportamento. Todos os tempos marcados "(clipe)" estão no
## tempo do clipe de origem recortado (s, antes da velocidade); o tempo real é tempo_clipe / speed.
## Assim `speed` muda o ritmo do golpe inteiro sem desalinhar janelas, e cada janela
## (preparação, contato, encadeamento, cancelamento, recuperação) é editada separadamente.

enum Reaction { LIGHT_LEFT, LIGHT_RIGHT, HEAVY }

@export var id: StringName = &"golpe"
@export var display_name := "Golpe"

@export_group("Animação")
## Trecho do clipe `Sword_Attack` usado (s do clipe original) e espelhamento esquerda/direita.
@export var clip_from := 0.08
@export var clip_to := 0.95
@export var mirrored := false
## Velocidade de ataque: multiplica a reprodução do clipe E todas as janelas (1 = clipe original).
@export_range(0.5, 3.0, 0.05) var speed := 1.8

@export_group("Janelas (clipe)")
## Fim da preparação = início do contato (lâmina pode acertar).
@export var active_start := 0.22
## Fim do contato; depois disso é recuperação.
@export var active_end := 0.46
## A partir daqui um novo ataque (guardado no buffer ou apertado agora) encadeia o próximo golpe.
@export var chain_open := 0.50
## A partir daqui a esquiva cancela o golpe. Cedo de propósito: a esquiva sempre responde.
@export var dodge_cancel_from := 0.10
## A partir daqui a direção pressionada cancela a recuperação e volta à corrida.
@export var move_cancel_from := 0.62

@export_group("Avanço e orientação")
## Distância que o personagem avança (m) entre `advance_start` e `advance_end` (clipe).
@export var advance_distance := 0.9
@export var advance_start := 0.10
@export var advance_end := 0.40
## Giro máximo do corpo na preparação (graus/s), para mirar a direção pressionada ou o alvo.
@export var turn_rate_deg := 900.0
## Depois deste instante (clipe) o corpo não gira mais (o golpe segue na direção escolhida).
@export var turn_lock := 0.22

@export_group("Impacto")
@export var damage := 10.0
## Congelamento curto, em segundos reais, só do atacante e do alvo (o resto do jogo segue).
@export var hitstop := 0.05
## Deslocamento do alvo ao ser atingido (m) e tipo de reação visual.
@export var knockback := 0.15
@export var reaction: Reaction = Reaction.LIGHT_LEFT
## Tremor de câmera (m) no acerto. 0 nos golpes comuns; só o golpe final tem um valor discreto.
@export var camera_shake := 0.0

@export_group("Alcance")
## Lâmina da katana: segmento de `blade_from` a `blade_to` ao longo do eixo da arma (m a partir do punho)
## e raio de tolerância do acerto.
@export var blade_from := 0.21
@export var blade_to := 0.99
@export var hit_radius := 0.10


func clip_length() -> float:
	return clip_to - clip_from


## Converte tempo do clipe (relativo ao início do trecho) em segundos reais e o contrário.
func to_real(clip_time: float) -> float:
	return clip_time / speed


func total_real() -> float:
	return clip_length() / speed
