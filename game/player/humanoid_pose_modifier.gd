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
## Inclinação extra do tronco à frente na velocidade máxima (graus), somada à do clipe.
@export var lean_forward_deg := 6.0
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

@export_group("Postura de espadachim")
## Quanto o braço da katana vai para trás na corrida (graus) e flexão do cotovelo.
## Direções-alvo no espaço do modelo (+Z frente, +Y cima, -X lado direito do personagem).
@export var sword_upper_dir := Vector3(-0.25, -0.55, -0.79)
@export var sword_fore_dir := Vector3(-0.15, -0.05, -0.99)
## Fração da velocidade máxima em que a postura já está 100% (começa acima de ~40%).
@export var run_full_ratio := 0.8
@export var run_start_ratio := 0.35
@export var posture_tau := 0.07

var _run_amount := 0.0
var _dash_amount := 0.0
var _lean_fwd := 0.0
var _lean_side := 0.0
var _prev_forward := Vector3.FORWARD
var _bones := {}


func set_motion(delta: float, velocity: Vector3, forward: Vector3, max_speed: float, dodging: bool) -> void:
	var dash_tau := dash_attack_tau if dodging else dash_release_tau
	_dash_amount = lerpf(_dash_amount, 1.0 if dodging else 0.0, MotionMath.smooth_alpha(delta, dash_tau))
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var ratio := clampf(speed / maxf(max_speed, 0.01), 0.0, 1.2)
	var run_target := clampf((ratio - run_start_ratio) / (run_full_ratio - run_start_ratio), 0.0, 1.0)
	_run_amount = lerpf(_run_amount, run_target, MotionMath.smooth_alpha(delta, posture_tau))

	var fwd_target := deg_to_rad(lean_forward_deg) * minf(ratio, 1.0)
	_lean_fwd = lerpf(_lean_fwd, fwd_target, MotionMath.smooth_alpha(delta, lean_tau))

	# Giro do corpo (rad/s) a partir da variação da direção de frente.
	var yaw_rate := 0.0
	if delta > 0.0001:
		yaw_rate = _prev_forward.signed_angle_to(forward, Vector3.UP) / delta
	_prev_forward = forward
	var side_target := clampf(-yaw_rate * minf(ratio, 1.0) * deg_to_rad(lean_per_turn_rate) * 0.1, -1.0, 1.0)
	side_target *= deg_to_rad(lean_side_deg)
	_lean_side = lerpf(_lean_side, side_target, MotionMath.smooth_alpha(delta, lean_tau))


func run_amount() -> float:
	return _run_amount


func dash_amount() -> float:
	return _dash_amount


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		for n in ["pelvis", "spine_01", "spine_02", "spine_03", "upperarm_r", "lowerarm_r", "hand_r"]:
			_bones[n] = sk.find_bone(n)
	# Tronco: o ângulo total é distribuído pela coluna.
	var share := {"pelvis": 0.25, "spine_01": 0.25, "spine_02": 0.25, "spine_03": 0.25}
	for n: String in share:
		var lean := _lean_fwd + deg_to_rad(dash_lean_deg) * _dash_amount
		var q := Quaternion(Vector3.RIGHT, lean * share[n]) * Quaternion(MODEL_FORWARD, _lean_side * share[n])
		_rotate_model_space(sk, _bones[n], q)
	# Braço da katana para trás: o braço é conduzido para uma direção-alvo (cai rumo à postura
	# de espadachim conforme `_run_amount`), em vez de somar um desvio ao balanço do clipe.
	var sword_amount := maxf(_run_amount, _dash_amount)
	if sword_amount > 0.001:
		_aim_bone(sk, _bones["upperarm_r"], _bones["lowerarm_r"], sword_upper_dir.normalized(), sword_amount)
		_aim_bone(sk, _bones["lowerarm_r"], _bones["hand_r"], sword_fore_dir.normalized(), sword_amount)


## Gira o osso (em torno da sua origem) para que o vetor osso->filho aponte para `target_dir`
## (espaço do modelo), com intensidade `weight` (0..1).
func _aim_bone(sk: Skeleton3D, bone: int, child: int, target_dir: Vector3, weight: float) -> void:
	if bone < 0 or child < 0:
		return
	var cur := (sk.get_bone_global_pose(child).origin - sk.get_bone_global_pose(bone).origin).normalized()
	var full := Quaternion(cur, target_dir)
	_rotate_model_space(sk, bone, Quaternion.IDENTITY.slerp(full, weight))


## Aplica `delta_q` (espaço do modelo) à pose ATUAL do osso, girando em torno da sua origem.
func _rotate_model_space(sk: Skeleton3D, bone: int, delta_q: Quaternion) -> void:
	if bone < 0:
		return
	var parent := sk.get_bone_parent(bone)
	var g := sk.get_bone_global_pose(bone)
	var new_g := Transform3D(Basis(delta_q) * g.basis, g.origin)
	var parent_g := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_g.affine_inverse() * new_g
	sk.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
