class_name HumanoidPoseModifier
extends SkeletonModifier3D
## Ajustes procedurais de pose por cima da animação (executam depois do AnimationTree):
## inclinação do corpo pela velocidade, inclinação lateral nas curvas e braço da katana
## levado para trás na corrida (postura de espadachim).
##
## Tudo são rotações no espaço do modelo, suavizadas por exponencial independente da taxa
## de quadros. Nenhum valor aqui afeta movimento ou colisão.

## Frente do esqueleto no espaço do modelo (o glTF do pacote aponta para +Z).
const MODEL_FORWARD := Vector3(0, 0, 1)

@export_group("Inclinação")
## Inclinação lateral máxima nas curvas (graus).
@export var lean_side_deg := 9.0
## Ganho da curva: graus de inclinação por (rad/s de giro × fração da velocidade máxima).
@export var lean_per_turn_rate := 3.0
@export var lean_tau := 0.08

@export_group("Esquiva")
## Inclinação extra do corpo na investida da esquiva (graus) e suavização de entrada e saída.
@export var dash_lean_deg := 26.0
@export var dash_attack_tau := 0.03
@export var dash_release_tau := 0.09

@export_group("Postura de arma")
## Postura da família de arma equipada (direções do braço, peso em repouso, balanço conservado).
@export var stance: WeaponStance = WeaponStance.katana()
## Fração da velocidade máxima em que a postura já está 100% (começa acima de ~40%).
@export var run_full_ratio := 0.8
@export var run_start_ratio := 0.35
@export var posture_tau := 0.07

@export_group("Giros")
## Quanto do desvio de giro (corpo da cápsula x quadril visual) o tronco desfaz: o tronco
## "lidera" o giro e o quadril acompanha. 0 = nada, 1 = tronco alinhado com a cápsula.
@export_range(0.0, 1.0) var torso_lead := 0.7

var _run_amount := 0.0
var _dash_amount := 0.0
var _lean_fwd := 0.0
var _lean_side := 0.0
## Desvio de giro (rad): quanto o quadril visual está atrás da frente da cápsula.
var _turn_offset := 0.0
var _prev_forward := Vector3.FORWARD
var _bones := {}
## Poses globais calculadas por nós a partir das poses locais (evita forçar o Skeleton3D a
## recalcular a hierarquia a cada leitura, o que custava ~1,3 ms por quadro).
var _cache := {}


func set_motion(delta: float, velocity: Vector3, forward: Vector3, max_speed: float, dodging: bool) -> void:
	var dash_tau := dash_attack_tau if dodging else dash_release_tau
	_dash_amount = lerpf(_dash_amount, 1.0 if dodging else 0.0, MotionMath.smooth_alpha(delta, dash_tau))
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var ratio := clampf(speed / maxf(max_speed, 0.01), 0.0, 1.2)
	var run_target := clampf((ratio - run_start_ratio) / (run_full_ratio - run_start_ratio), 0.0, 1.0)
	_run_amount = lerpf(_run_amount, run_target, MotionMath.smooth_alpha(delta, posture_tau))

	var fwd_target := deg_to_rad(stance.lean_forward_deg) * minf(ratio, 1.0)
	_lean_fwd = lerpf(_lean_fwd, fwd_target, MotionMath.smooth_alpha(delta, lean_tau))

	# Giro do corpo (rad/s) a partir da variação da direção de frente.
	var yaw_rate := 0.0
	if delta > 0.0001:
		yaw_rate = _prev_forward.signed_angle_to(forward, Vector3.UP) / delta
	_prev_forward = forward
	var side_target := clampf(-yaw_rate * minf(ratio, 1.0) * deg_to_rad(lean_per_turn_rate) * 0.1, -1.0, 1.0)
	side_target *= deg_to_rad(lean_side_deg)
	_lean_side = lerpf(_lean_side, side_target, MotionMath.smooth_alpha(delta, lean_tau))


## Desvio de giro atual entre a frente da cápsula e o quadril visual (rad, com sinal).
func set_turn_offset(offset: float) -> void:
	_turn_offset = offset


func run_amount() -> float:
	return _run_amount


func dash_amount() -> float:
	return _dash_amount


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_cache.clear()
	if _bones.is_empty():
		for n in ["pelvis", "spine_01", "spine_02", "spine_03", "upperarm_r", "lowerarm_r", "hand_r"]:
			_bones[n] = sk.find_bone(n)
	# Tronco: o ângulo total é distribuído pela coluna; o giro (yaw) é desfeito em parte pelo peito,
	# que lidera enquanto o quadril (nó visual) acompanha.
	var share := {"pelvis": 0.25, "spine_01": 0.25, "spine_02": 0.25, "spine_03": 0.25}
	var twist := {"pelvis": 0.0, "spine_01": 0.2, "spine_02": 0.25, "spine_03": 0.25}
	for n: String in share:
		var lean := _lean_fwd + deg_to_rad(dash_lean_deg) * _dash_amount
		var q := Quaternion(Vector3.UP, -_turn_offset * torso_lead * twist[n] / 0.7) * Quaternion(Vector3.RIGHT, lean * share[n]) * Quaternion(MODEL_FORWARD, _lean_side * share[n])
		_rotate_model_space(sk, _bones[n], q)
	# Braço da katana para trás: o braço é conduzido para uma direção-alvo (cai rumo à postura
	# de espadachim conforme `_run_amount`), em vez de somar um desvio ao balanço do clipe.
	var arm_w := maxf(maxf(_run_amount, _dash_amount), stance.idle_amount)
	# Na corrida o braço conserva só uma fração do balanço do clipe (`arm_swing_keep`).
	var firm := lerpf(1.0, 1.0 - stance.arm_swing_keep, maxf(_run_amount, _dash_amount))
	arm_w *= firm
	if arm_w > 0.001:
		var chest: int = _bones["spine_03"]
		_aim_bone(sk, _bones["upperarm_r"], _bones["lowerarm_r"], _chest_dir(sk, chest, stance.upper_dir), arm_w)
		_aim_bone(sk, _bones["lowerarm_r"], _bones["hand_r"], _chest_dir(sk, chest, stance.fore_dir), arm_w)


## Direção-alvo (definida para o peito em repouso) levada para a pose atual do peito, então o
## braço acompanha o tronco em vez de balançar em relação a ele.
func _chest_dir(sk: Skeleton3D, chest: int, dir: Vector3) -> Vector3:
	var rest := sk.get_bone_global_rest(chest).basis
	return (_global(sk, chest).basis * (rest.inverse() * dir.normalized())).normalized()


## Gira o osso (em torno da sua origem) para que o vetor osso->filho aponte para `target_dir`
## (espaço do modelo), com intensidade `weight` (0..1).
func _aim_bone(sk: Skeleton3D, bone: int, child: int, target_dir: Vector3, weight: float) -> void:
	if bone < 0 or child < 0:
		return
	var cur := (_global(sk, child).origin - _global(sk, bone).origin).normalized()
	var full := Quaternion(cur, target_dir)
	_rotate_model_space(sk, bone, Quaternion.IDENTITY.slerp(full, weight))


## Aplica `delta_q` (espaço do modelo) à pose ATUAL do osso, girando em torno da sua origem.
func _rotate_model_space(sk: Skeleton3D, bone: int, delta_q: Quaternion) -> void:
	if bone < 0:
		return
	var parent := sk.get_bone_parent(bone)
	var g := _global(sk, bone)
	var new_g := Transform3D(Basis(delta_q) * g.basis, g.origin)
	var parent_g := _global(sk, parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_g.affine_inverse() * new_g
	sk.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
	_cache.clear()  # os descendentes mudaram


## Pose global do osso (espaço do esqueleto) a partir das poses locais atuais, com cache por quadro.
func _global(sk: Skeleton3D, bone: int) -> Transform3D:
	if _cache.has(bone):
		return _cache[bone]
	var parent := sk.get_bone_parent(bone)
	var g := (_global(sk, parent) if parent >= 0 else Transform3D.IDENTITY) * sk.get_bone_pose(bone)
	_cache[bone] = g
	return g
