class_name MotionMath
extends RefCounted
## Funções puras de movimento. Ficam separadas do nó do jogador para
## poderem ser testadas sem cena e sem física.


## Aproxima a velocidade horizontal da velocidade desejada.
## `reverse_mult` acelera a inversão de sentido (entrada oposta à velocidade atual).
static func approach_velocity(velocity: Vector3, target: Vector3, accel: float, decel: float, reverse_mult: float, delta: float) -> Vector3:
	var wants_move := target.length() > 0.01
	var rate := accel if wants_move else decel
	if wants_move and velocity.dot(target) < 0.0:
		rate *= reverse_mult
	return velocity.move_toward(target, rate * delta)


## Distância percorrida na esquiva ao progresso `progress` (0..1).
## Perfil de velocidade v(s) = v0 * (1 - s²): sai rápido e desacelera até zero.
## A integral é 1,5·s − 0,5·s³, que vale exatamente 1 em s = 1.
static func dodge_distance_at(progress: float, total_distance: float) -> float:
	var s := clampf(progress, 0.0, 1.0)
	return total_distance * (1.5 * s - 0.5 * s * s * s)


## Coeficiente de suavização exponencial independente da taxa de quadros.
## Após 5·tau o erro restante é menor que 1%.
static func smooth_alpha(delta: float, tau: float) -> float:
	if tau <= 0.0001:
		return 1.0
	return 1.0 - exp(-delta / tau)
