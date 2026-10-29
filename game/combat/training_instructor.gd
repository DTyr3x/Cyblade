class_name TrainingInstructor
extends TrainingDummy
## Instrutor de treino (C1): um alvo que ATACA num ciclo fixo, sem IA, para treinar defesa e parry.
##
##   ESPERA ─► PREPARAÇÃO (corpo acende, braço-lâmina sobe) ─► GOLPE (contato) ─► RECUPERAÇÃO ─► ESPERA
##                       sinal didático: brilho branco + "tic" `cue_lead` s antes do contato
##   parry perfeito ─► DESEQUILÍBRIO (recua, braço jogado para cima) ─► RECUPERAÇÃO
##
## Herda do boneco a hurtbox (os golpes do jogador o acertam) e as molas de reação. Corpo procedural.
## Só ataca com o jogador dentro de `engage_range`. Tempo do ciclo em segundos de simulação.

signal phase_changed(phase: int)
signal cue
signal contact(info: Dictionary)

enum Phase { WAIT, WINDUP, STRIKE, RECOVERY, OFF_BALANCE }

const ARM_REST := -20.0
const ARM_RAISED := -200.0
const ARM_CONTACT := -90.0
const ARM_END := -40.0

@export var attack: EnemyAttackData
## Intervalo de espera entre o fim de um ataque e a próxima preparação (s).
@export var interval := 1.4
## Só ataca com o jogador mais perto que isto (m).
@export var engage_range := 4.0
## Giro para encarar o jogador (graus/s), até o sinal; depois o golpe fica travado na direção.
@export var turn_rate_deg := 540.0
@export var enabled := true

var phase := Phase.WAIT
var phase_time := 0.0
var swing := 0
## Instante (relógio de combate) do próximo contato agendado; -1 se não há preparação em curso.
var next_contact_time := -1.0
## Contadores do C1 (efeito no C2): pressão de postura sofrida.
var posture_pressure := 0.0
var results: Array[Dictionary] = []

var target: Node3D
var _arm: Node3D
var _blade_mat: StandardMaterial3D
var _cue_done := false
var _resolved := false
var _hold := 0.0
var _glint := 0.0
var _arm_angle := ARM_REST
var _thrown := 0.0


func _ready() -> void:
	if attack == null:
		attack = EnemyAttackData.load_default()
	super._ready()
	add_to_group(&"inimigo")


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = HURT_RADIUS
	cap.height = HURT_TOP + 0.1
	shape.shape = cap
	shape.position.y = (HURT_TOP + 0.1) * 0.5
	add_child(shape)

	_pivot = Node3D.new()
	add_child(_pivot)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.20, 0.22, 0.26)
	_mat.metallic = 0.5
	_mat.roughness = 0.45
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.55, 0.12)   # âmbar: cor da preparação
	_mat.emission_energy_multiplier = 0.0
	var visor := StandardMaterial3D.new()
	visor.albedo_color = Color(0.1, 0.9, 1.0)
	visor.emission_enabled = true
	visor.emission = Color(0.1, 0.9, 1.0)
	visor.emission_energy_multiplier = 2.0
	var base := CylinderMesh.new()
	base.top_radius = 0.40
	base.bottom_radius = 0.45
	base.height = 0.12
	_add_mesh(base, Vector3(0, 0.06, 0), _mat)
	var legs := CylinderMesh.new()
	legs.top_radius = 0.16
	legs.bottom_radius = 0.22
	legs.height = 0.75
	_add_mesh(legs, Vector3(0, 0.5, 0), _mat)
	var torso := CapsuleMesh.new()
	torso.radius = 0.30
	torso.height = 0.85
	_add_mesh(torso, Vector3(0, 1.15, 0), _mat)
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	_add_mesh(head, Vector3(0, 1.72, 0), _mat)
	var eye := BoxMesh.new()
	eye.size = Vector3(0.22, 0.05, 0.02)
	_add_mesh(eye, Vector3(0, 1.74, 0.16), visor)

	# Braço-lâmina: pivô no ombro direito; o braço e a lâmina descem ao longo de -Y local.
	_arm = Node3D.new()
	_arm.position = Vector3(-0.36, 1.38, 0.05)
	_pivot.add_child(_arm)
	var arm_mesh := MeshInstance3D.new()
	var arm := CapsuleMesh.new()
	arm.radius = 0.07
	arm.height = 0.6
	arm_mesh.mesh = arm
	arm_mesh.position = Vector3(0, -0.3, 0)
	arm_mesh.material_override = _mat
	_arm.add_child(arm_mesh)
	_blade_mat = StandardMaterial3D.new()
	_blade_mat.albedo_color = Color(0.75, 0.8, 0.88)
	_blade_mat.metallic = 0.8
	_blade_mat.roughness = 0.3
	_blade_mat.emission_enabled = true
	_blade_mat.emission = Color(1, 1, 1)
	_blade_mat.emission_energy_multiplier = 0.0
	var blade_mesh := MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.03, 0.9, 0.08)
	blade_mesh.mesh = blade
	blade_mesh.position = Vector3(0, -1.0, 0)
	blade_mesh.material_override = _blade_mat
	_arm.add_child(blade_mesh)


## Ponta da lâmina do Instrutor no mundo (efeitos: faíscas no contato).
func blade_tip() -> Vector3:
	return _arm.global_transform * Vector3(0, -1.4, 0)


func blade_mid() -> Vector3:
	return _arm.global_transform * Vector3(0, -0.95, 0)


## Congela o ciclo e o corpo (hitstop local).
func freeze(duration: float) -> void:
	_hold = maxf(_hold, duration)
	_freeze = maxf(_freeze, duration)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _hold > 0.0:
		_hold = maxf(_hold - delta, 0.0)
		_update_visual(0.0)
		return
	if not enabled or attack == null:
		_update_visual(delta)
		return
	phase_time += delta
	match phase:
		Phase.WAIT:
			_face_target(delta)
			if phase_time >= interval and _target_in_range(engage_range):
				_enter(Phase.WINDUP)
				_cue_done = false
				_resolved = false
				swing += 1
				next_contact_time = CombatClock.time + attack.time_to_contact()
		Phase.WINDUP:
			var to_cue := attack.time_to_contact() - attack.cue_lead
			if phase_time < to_cue:
				_face_target(delta)
			elif not _cue_done:
				_cue_done = true
				_glint = 1.0
				cue.emit()
			if phase_time >= attack.windup:
				_enter(Phase.STRIKE, phase_time - attack.windup)
		Phase.STRIKE:
			if not _resolved and phase_time >= attack.active_start:
				_try_contact(phase_time - attack.active_start)
			if phase_time >= attack.active_end and not _resolved:
				_resolved = true
				results.append({"swing": swing, "result": "fora de alcance"})
			if phase_time >= attack.strike_time and phase == Phase.STRIKE:
				_enter(Phase.RECOVERY, phase_time - attack.strike_time)
		Phase.RECOVERY:
			if phase_time >= attack.recovery:
				_enter(Phase.WAIT, 0.0)
				next_contact_time = -1.0
		Phase.OFF_BALANCE:
			if phase_time >= attack.off_balance:
				_enter(Phase.RECOVERY, 0.0)
	_update_visual(delta)


## Testa o contato; `late` = quanto este passo passou do instante exato do contato.
func _try_contact(late: float) -> void:
	if target == null or not _target_in_arc():
		return
	_resolved = true
	var t := CombatClock.time - late
	var info := {"swing": swing, "time": t}
	if target.has_method("receive_enemy_attack"):
		info.merge(target.receive_enemy_attack(attack, t, self), true)
	results.append(info)
	contact.emit(info)
	if info.get("result", -1) == DefenseController.Result.PERFECT:
		posture_pressure += float(info.get("posture_pressure", 0.0))
		_enter(Phase.OFF_BALANCE, 0.0)
		_thrown = 1.0
		_lean_vel += Vector2(-4.5, 0.0)
		_flash = 0.6
	freeze(float(info.get("hitstop", 0.0)))


func _target_in_range(r: float) -> bool:
	if target == null:
		return false
	var d := target.global_position - global_position
	d.y = 0.0
	return d.length() <= r


func _target_in_arc() -> bool:
	if not _target_in_range(attack.attack_range):
		return false
	var d := target.global_position - global_position
	d.y = 0.0
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	return rad_to_deg(fwd.normalized().angle_to(d.normalized())) <= attack.arc_deg * 0.5


func _face_target(delta: float) -> void:
	if target == null or not _target_in_range(engage_range + 1.0):
		return
	var d := target.global_position - global_position
	var yaw := atan2(d.x, d.z)
	rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(turn_rate_deg) * delta)


func _enter(p: Phase, carry := 0.0) -> void:
	phase = p
	phase_time = carry
	phase_changed.emit(p)


## Braço-lâmina, brilho da preparação e do sinal.
func _update_visual(delta: float) -> void:
	var target_angle := ARM_REST
	var glow := 0.0
	match phase:
		Phase.WINDUP:
			var s := clampf(phase_time / (attack.windup * 0.8), 0.0, 1.0)
			target_angle = lerpf(ARM_REST, ARM_RAISED, s * s * (3.0 - 2.0 * s))
			glow = 0.3 + 1.2 * clampf(phase_time / attack.windup, 0.0, 1.0)
		Phase.STRIKE:
			var s := phase_time / maxf(attack.active_start, 0.001)
			if s <= 1.0:
				target_angle = lerpf(ARM_RAISED, ARM_CONTACT, s)
			else:
				var s2 := clampf((phase_time - attack.active_start) / maxf(attack.strike_time - attack.active_start, 0.001), 0.0, 1.0)
				target_angle = lerpf(ARM_CONTACT, ARM_END, s2)
			glow = 1.5
		Phase.RECOVERY:
			target_angle = lerpf(ARM_END, ARM_REST, clampf(phase_time / attack.recovery, 0.0, 1.0))
		Phase.OFF_BALANCE:
			target_angle = -170.0
	if phase == Phase.STRIKE or phase == Phase.WINDUP:
		_arm_angle = target_angle
	else:
		_arm_angle = lerpf(_arm_angle, target_angle, MotionMath.smooth_alpha(delta, 0.06)) if delta > 0.0 else _arm_angle
	_arm.rotation.x = deg_to_rad(_arm_angle)
	_glint = maxf(_glint - delta * 10.0, 0.0)
	_blade_mat.emission_energy_multiplier = _glint * 4.0
	_mat.emission_energy_multiplier = maxf(glow, _flash * 0.9)
