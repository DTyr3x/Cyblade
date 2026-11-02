class_name TrainingInstructor
extends TrainingDummy
## Instrutor de treino (C1): um alvo que ATACA num ciclo fixo, sem IA, para treinar defesa e parry.
##
##   ESPERA ─► PREPARAÇÃO (corpo acende, braço-lâmina sobe) ─► GOLPE (contato) ─► RECUPERAÇÃO ─► ESPERA
##                       sinal didático: brilho branco + "tic" `cue_lead` s antes do contato
##   parry perfeito ─► DESEQUILÍBRIO (recua, braço jogado para cima) ─► RECUPERAÇÃO
##   postura cheia ─► QUEBRADO (joelho no chão, visor apagado) ─► RECUPERAÇÃO
##   Cravada ─► CAÍDO ─► RECUPERAÇÃO
##
## Herda do boneco a hurtbox (os golpes do jogador o acertam) e as molas de reação. Corpo procedural.
## Só ataca com o jogador dentro de `engage_range`. Tempo do ciclo em segundos de simulação.

signal phase_changed(phase: int)
signal cue
signal contact(info: Dictionary)
## Esquiva justa reconhecida (dentro da ameaça, no tempo certo).
signal evade_credited

enum Phase { WAIT, WINDUP, STRIKE, RECOVERY, OFF_BALANCE, BROKEN, DOWN }

const ARM_REST := -20.0
const ARM_RAISED := -200.0
const ARM_CONTACT := -90.0
const ARM_END := -40.0
const ARM_LIMP := -6.0
## Pose quebrada: desce sobre o joelho, tronco à frente.
const KNEEL_DROP := 0.38
const KNEEL_TILT := 0.45

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
## Perfil de postura (vazio = padrão em game/data/postura_instrutor.tres).
@export var posture_data: PostureData
## Núcleo de pressão de postura (C2.0).
var posture: PostureController
## Contador do C1: agora lido do núcleo, para não existirem duas contas.
var posture_pressure: float:
	get:
		return posture.parry_pressure_total
var results: Array[Dictionary] = []
## Derrotas por Cravada.
var defeats := 0

var target: Node3D
var _arm: Node3D
var _blade_mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D
var _cue_done := false
var _resolved := false
var _hold := 0.0
var _glint := 0.0
var _arm_angle := ARM_REST
var _thrown := 0.0
var _kneel := 0.0
var _wait_override := -1.0


func _ready() -> void:
	if attack == null:
		attack = EnemyAttackData.load_default()
	super._ready()
	posture = PostureController.new(posture_data)
	posture.name = "Postura"
	add_child(posture)
	posture.broken.connect(_on_broken)
	posture.recovered.connect(_on_recovered)
	posture.finished.connect(_on_finished)
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
	_visor_mat = visor
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


func blade_base() -> Vector3:
	return _arm.global_transform * Vector3(0, -0.55, 0)


func blade_mid() -> Vector3:
	return _arm.global_transform * Vector3(0, -0.95, 0)


## Um golpe que acertou: reações do boneco e pressão de postura.
func receive_hit(info: Dictionary) -> void:
	super.receive_hit(info)
	var t := CombatClock.time
	if info.get("finisher", false):
		posture.complete_finish(t)
	else:
		posture.apply_hit(t, float(info.get("posture", 0.0)), bool(info.get("posture_locks", false)), int(info["swing"]))


## Congela o ciclo e o corpo (hitstop local).
func freeze(duration: float) -> void:
	_hold = maxf(_hold, duration)
	_freeze = maxf(_freeze, duration)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	posture.update(CombatClock.time)
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
			_tick_wait(delta)
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
			_tick_strike_motion(delta)
			if not _resolved and phase_time >= attack.active_start:
				_try_contact(phase_time - attack.active_start)
			if phase_time >= attack.active_end and not _resolved:
				_resolved = true
				results.append({"swing": swing, "result": "fora de alcance"})
				_credit_evade(CombatClock.time - (phase_time - attack.active_start))
			if phase_time >= attack.strike_time and phase == Phase.STRIKE:
				_on_strike_done(phase_time - attack.strike_time)
		Phase.RECOVERY:
			if phase_time >= attack.recovery:
				_enter(Phase.WAIT, 0.0)
				next_contact_time = -1.0
				_on_recovery_done()
		Phase.OFF_BALANCE:
			if phase_time >= attack.off_balance:
				_enter(Phase.RECOVERY, 0.0)
		Phase.DOWN:
			if phase_time >= posture.data.finish_down_time:
				_enter(Phase.RECOVERY, 0.0)
	_update_visual(delta)


## Espera entre ataques. O robô troca por aproximação e escolha de golpe.
func _tick_wait(delta: float) -> void:
	_face_target(delta)
	var wait_for := _wait_override if _wait_override >= 0.0 else interval
	if phase_time >= wait_for and _target_in_range(engage_range):
		_wait_override = -1.0
		_begin_attack()


func _begin_attack() -> void:
	_enter(Phase.WINDUP)
	_cue_done = false
	_resolved = false
	swing += 1
	next_contact_time = CombatClock.time + attack.time_to_contact()


## Movimento do corpo durante o golpe (investida do robô).
func _tick_strike_motion(_delta: float) -> void:
	pass


## Fim do golpe: encadeia o próximo da sequência ou recupera.
func _on_strike_done(carry: float) -> void:
	if attack.follow_up != null:
		attack = attack.follow_up
		_begin_attack()
		phase_time = carry
	else:
		_enter(Phase.RECOVERY, carry)


func _on_recovery_done() -> void:
	pass


## Esquiva justa: o inimigo sabe que o golpe era uma ameaça real, o jogador só diz quando esquivou.
func _credit_evade(t: float) -> void:
	if target != null and target.has_method("fair_evade") and target.fair_evade(attack, self, t, posture.data.evade_window):
		posture.apply_evade(t, swing)
		posture.expose(t + posture.data.evade_exposed_time)
		evade_credited.emit()


func _on_broken(_by_precision: bool) -> void:
	_enter(Phase.BROKEN)
	next_contact_time = -1.0
	_resolved = true
	var h := posture.data.break_hitstop
	freeze(h)
	if target != null and target.has_method("on_enemy_broken"):
		target.on_enemy_broken(h, posture.data.break_neural_energy)


func _on_recovered() -> void:
	_wait_override = posture.data.post_break_interval
	_enter(Phase.RECOVERY, 0.0)


func _on_finished() -> void:
	defeats += 1
	_enter(Phase.DOWN)


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
	if info.get("evaded", false):
		_credit_evade(t)
	if info.get("result", -1) == DefenseController.Result.PERFECT:
		posture.expose(t + attack.off_balance)
		posture.apply_parry(t, float(info.get("posture_pressure", 0.0)), swing)
		if phase != Phase.BROKEN:
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
		Phase.BROKEN, Phase.DOWN:
			target_angle = ARM_LIMP
	if phase == Phase.STRIKE or phase == Phase.WINDUP:
		_arm_angle = target_angle
	else:
		_arm_angle = lerpf(_arm_angle, target_angle, MotionMath.smooth_alpha(delta, 0.06)) if delta > 0.0 else _arm_angle
	_arm.rotation.x = deg_to_rad(_arm_angle)
	_glint = maxf(_glint - delta * 10.0, 0.0)
	_blade_mat.emission_energy_multiplier = _glint * 4.0
	# Abertura de contra-ataque: o visor do Instrutor passa de ciano a branco enquanto a oportunidade
	# está aberta (discreto, sem partículas).
	var open := target != null and target.get("defense") != null and (target.get("defense") as DefenseController).opportunity_open(CombatClock.time) and (target.get("defense") as DefenseController).opportunity_source == self
	_visor_mat.emission = Color(0.1, 0.9, 1.0).lerp(Color(1, 1, 1), 1.0 if open else 0.0)
	_visor_mat.albedo_color = _visor_mat.emission
	_visor_mat.emission_energy_multiplier = 5.0 if open else 2.0
	var down := phase == Phase.BROKEN or phase == Phase.DOWN
	if down:
		_visor_mat.emission_energy_multiplier = 0.0
	_mat.emission_energy_multiplier = maxf(glow, _flash * 0.9)
	_kneel = lerpf(_kneel, 1.0 if down else 0.0, MotionMath.smooth_alpha(delta, 0.05 if down else 0.14))
	_pivot.position.y = _slide.y - KNEEL_DROP * _kneel
	_pivot.rotation.x = _lean.x + KNEEL_TILT * _kneel
