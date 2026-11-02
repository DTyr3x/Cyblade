class_name RobotEnemy
extends TrainingInstructor
## Primeiro inimigo real: um robô flutuante que aproveita o ciclo de ataque, a defesa, a postura e a Cravada do
## Instrutor e acrescenta o que falta para uma luta: vida, aproximação, distância de combate e três padrões.
##
##   aproxima ─► mantém distância, circula ─► escolhe o golpe ─► ciclo de ataque do Instrutor ─► volta
##   perto:  Corte duplo (âmbar, dois tempos) ou Varredura (vermelho, não defensável: esquive)
##   longe:  Investida (âmbar, faixa no chão até o jogador)
##
## O chão mostra a área do golpe durante a preparação, porque de cima o corpo do inimigo é pequeno.
## Com a vida no fim ele quebra sozinho: a luta sempre termina numa Cravada, nunca por acidente.

signal defeated
signal health_changed(health: float)

const CUT_PATH := "res://game/data/robo_corte_duplo.tres"
const LUNGE_PATH := "res://game/data/robo_investida.tres"
const SWEEP_PATH := "res://game/data/robo_varredura.tres"
const POSTURE_PATH := "res://game/data/postura_robo.tres"
const AMBER := Color(1.0, 0.55, 0.12)
const RED := Color(1.0, 0.08, 0.1)
const LAST_HEALTH := 1.0

@export var max_health := 600.0
## A esta distância do jogador o robô entra na luta (m).
@export var detect_range := 30.0
## Distância que ele procura manter (m) e abaixo da qual recua.
@export var fight_distance := 2.0
@export var too_close := 1.25
@export var move_speed := 4.4
@export var strafe_speed := 1.7
@export var retreat_speed := 2.8
## Intervalo entre ataques (s).
@export var cooldown_min := 0.45
@export var cooldown_max := 1.1
## Faixa em que ele usa a Investida (m).
@export var lunge_min := 3.4
@export var lunge_max := 9.0
## Chance de Varredura de perto.
@export var sweep_chance := 0.3
@export var rng_seed := 0

var health := 600.0
var engaged := false
var dead := false
## Quantas vezes cada padrão saiu (HUD e testes).
var pattern_counts := {}

var _cut: EnemyAttackData
var _lunge: EnemyAttackData
var _sweep: EnemyAttackData
var _rng := RandomNumberGenerator.new()
var _cooldown := 1.0
var _strafe := 1.0
var _strafe_left := 1.2
var _lunge_speed := 0.0
var _telegraph: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _fan_mesh: ArrayMesh
var _lane_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _sparks: CPUParticles3D


func _ready() -> void:
	_cut = load(CUT_PATH) as EnemyAttackData
	_lunge = load(LUNGE_PATH) as EnemyAttackData
	_sweep = load(SWEEP_PATH) as EnemyAttackData
	attack = _cut
	posture_data = load(POSTURE_PATH) as PostureData
	engage_range = detect_range
	health = max_health
	_rng.seed = rng_seed if rng_seed != 0 else randi()
	super._ready()
	_build_telegraph()


func _build() -> void:
	super._build()
	_mat.albedo_color = Color(0.13, 0.13, 0.17)
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.5, 0.03, 0.06)
	accent.emission_enabled = true
	accent.emission = RED
	accent.emission_energy_multiplier = 1.4
	var plate := BoxMesh.new()
	plate.size = Vector3(0.92, 0.2, 0.42)
	_add_mesh(plate, Vector3(0, 1.48, 0), _mat)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.08, 0.55, 0.3)
	_add_mesh(fin, Vector3(0, 1.62, -0.22), accent)
	var chest := BoxMesh.new()
	chest.size = Vector3(0.34, 0.1, 0.03)
	_add_mesh(chest, Vector3(0, 1.28, 0.3), accent)
	var left_arm := CapsuleMesh.new()
	left_arm.radius = 0.08
	left_arm.height = 0.7
	_add_mesh(left_arm, Vector3(0.42, 1.08, 0.02), _mat)
	var thruster := CylinderMesh.new()
	thruster.top_radius = 0.34
	thruster.bottom_radius = 0.2
	thruster.height = 0.06
	_add_mesh(thruster, Vector3(0, 0.02, 0), accent)

	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 60
	_sparks.lifetime = 0.8
	_sparks.explosiveness = 0.9
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 7.0
	_sparks.gravity = Vector3(0, -10.0, 0)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.02, 0.02, 0.1)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.7, 0.3)
	spark.material = spark_mat
	_sparks.mesh = spark
	_sparks.position = Vector3(0, 1.1, 0)
	add_child(_sparks)


## Área do golpe no chão: leque para o corte, faixa para a investida e círculo para a varredura.
func _build_telegraph() -> void:
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph_mat.no_depth_test = false
	_fan_mesh = _make_fan(_cut.attack_range, _cut.arc_deg)
	_ring_mesh = _make_fan(_sweep.attack_range, 360.0)
	_lane_mesh = _make_lane(1.5, _lunge.advance_distance + _lunge.attack_range)
	_telegraph = MeshInstance3D.new()
	_telegraph.position.y = 0.035
	_telegraph.material_override = _telegraph_mat
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph.visible = false
	add_child(_telegraph)


func _make_fan(radius: float, arc_deg: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 32
	var half := deg_to_rad(arc_deg) * 0.5
	for i in steps:
		var a0 := -half + 2.0 * half * i / steps
		var a1 := -half + 2.0 * half * (i + 1) / steps
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * radius)
	return st.commit()


func _make_lane(width: float, length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := width * 0.5
	for v: Vector3 in [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, length), Vector3(-w, 0, 0), Vector3(w, 0, length), Vector3(-w, 0, length)]:
		st.add_vertex(v)
	return st.commit()


func _tick_wait(delta: float) -> void:
	if target == null:
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if not engaged:
		if d > detect_range:
			return
		engaged = true
	_face_target(delta)
	var dir := to.normalized()
	var vel := Vector3.ZERO
	if d > fight_distance + 0.4:
		vel = dir * move_speed
	elif d < too_close:
		vel = -dir * retreat_speed
	else:
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe = -_strafe
			_strafe_left = _rng.randf_range(0.8, 1.6)
		vel = dir.cross(Vector3.UP) * _strafe * strafe_speed
	move_and_collide(vel * delta)
	_cooldown -= delta
	if _cooldown <= 0.0:
		var pick := _choose_attack(d)
		if pick != null:
			attack = pick
			pattern_counts[pick.display_name] = int(pattern_counts.get(pick.display_name, 0)) + 1
			_begin_attack()


func _choose_attack(d: float) -> EnemyAttackData:
	if d <= fight_distance + 0.7:
		return _sweep if _rng.randf() < sweep_chance else _cut
	if d >= lunge_min and d <= lunge_max:
		return _lunge
	return null


func _enter(p: Phase, carry := 0.0) -> void:
	super._enter(p, carry)
	if _telegraph == null:
		return
	match p:
		Phase.WINDUP:
			_show_telegraph()
		Phase.STRIKE:
			if attack.advance_distance > 0.0:
				var to := target.global_position - global_position
				to.y = 0.0
				var travel := clampf(to.length() - attack.attack_range * 0.7, 0.0, attack.advance_distance)
				_lunge_speed = travel / maxf(attack.active_start, 0.01)
		_:
			_telegraph.visible = false


func _show_telegraph() -> void:
	_telegraph.mesh = _lane_mesh if attack.advance_distance > 0.0 else (_ring_mesh if attack.spin else _fan_mesh)
	_telegraph.visible = true
	_mat.emission = AMBER if attack.parryable else RED


func _tick_strike_motion(delta: float) -> void:
	if attack.advance_distance > 0.0 and not _resolved and phase_time <= attack.active_end:
		move_and_collide(global_transform.basis.z * _lunge_speed * delta)


func _on_recovery_done() -> void:
	_cooldown = _wait_override if _wait_override >= 0.0 else _rng.randf_range(cooldown_min, cooldown_max)
	_wait_override = -1.0
	attack = _cut


func _update_visual(delta: float) -> void:
	super._update_visual(delta)
	if _telegraph != null and _telegraph.visible:
		var color := AMBER if attack.parryable else RED
		var k := clampf(phase_time / maxf(attack.time_to_contact(), 0.01), 0.0, 1.0) if phase == Phase.WINDUP else 1.0
		color.a = 0.08 + 0.34 * k
		_telegraph_mat.albedo_color = color
	if phase == Phase.STRIKE and attack.spin:
		_pivot.rotation.y = TAU * clampf(phase_time / attack.strike_time, 0.0, 1.0)


func receive_hit(info: Dictionary) -> void:
	if dead:
		return
	super.receive_hit(info)
	if info.get("finisher", false):
		return
	health = maxf(health - float(info["damage"]), LAST_HEALTH)
	health_changed.emit(health)
	if health <= LAST_HEALTH:
		posture.force_break(CombatClock.time)


func _on_finished() -> void:
	health -= max_health * posture.data.finish_health_ratio
	if health <= LAST_HEALTH:
		_die()
	else:
		health_changed.emit(health)
		super._on_finished()


func _die() -> void:
	health = 0.0
	dead = true
	health_changed.emit(health)
	defeats += 1
	_enter(Phase.DOWN)
	enabled = false
	_sparks.restart()
	_sparks.emitting = true
	defeated.emit()
