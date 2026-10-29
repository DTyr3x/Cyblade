class_name Player
extends CharacterBody3D
## Ninja jogável: movimento relativo à câmera, giro, aceleração, frenagem e esquiva.
##
## Estados: MOVE -> DODGE (deslocamento) -> RECOVERY (sem controle) -> MOVE; MOVE -> ATTACK (cadeia
## de golpes, ver CombatController) -> MOVE ou DODGE (cancelamento).
## Física em 120 Hz; a lógica usa só `delta`, nunca a taxa de quadros de render.

signal state_changed(new_state: int)
signal dodge_started(direction: Vector3)
signal dodge_finished

enum State { MOVE, DODGE, RECOVERY, ATTACK }

@export var tuning: PlayerTuning

## Guinada da câmera (rad). Quem monta a cena atualiza antes da física do jogador.
var move_yaw := 0.0
var state: State = State.MOVE
var state_time := 0.0
var dodge_direction := Vector3.ZERO

var _dodge_buffer := 0.0
var _dodge_exit_fraction := 0.0
var visual: HumanoidVisual
var combat: CombatController
var hit_detector: HitDetector


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	floor_snap_length = 0.4
	visual = HumanoidVisual.new()
	add_child(visual)
	visual.bind(self)
	combat = CombatController.new()
	combat.name = "Combat"
	add_child(combat)
	visual.setup_strikes(combat.combo)
	combat.strike_started.connect(_on_strike_started)
	combat.strike_ended.connect(_on_strike_ended)
	hit_detector = HitDetector.new(combat, visual)
	hit_detector.name = "HitDetector"
	add_child(hit_detector)


func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func is_invulnerable() -> bool:
	return state == State.DODGE \
		and state_time >= tuning.dodge_iframe_start \
		and state_time <= tuning.dodge_iframe_end


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer = tuning.dodge_buffer_time
	else:
		_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	if Input.is_action_just_pressed("attack"):
		combat.press_attack()
	if state != State.ATTACK:
		combat.tick(delta)   # relógio do combate fora de um golpe: buffer expira e o reinício da cadeia conta

	match state:
		State.MOVE:
			_tick_move(delta)
		State.DODGE:
			_tick_dodge(delta)
		State.RECOVERY:
			_tick_recovery(delta)
		State.ATTACK:
			_tick_attack(delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= tuning.gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	visual.update_pose(delta, velocity, -global_transform.basis.z, tuning.max_speed, state == State.DODGE)


func _input_direction() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, move_yaw)


func _tick_move(delta: float) -> void:
	var dir := _input_direction()
	if _dodge_buffer > 0.0:
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	if _try_start_attack():
		_tick_attack(delta)
		return
	_locomote(dir, delta)


## Locomoção normal: acelera/freia rumo à entrada e gira o corpo. Usada em MOVE e, quando a
## recuperação não trava o movimento, também em RECOVERY.
func _locomote(dir: Vector3, delta: float) -> void:
	var target := dir * tuning.max_speed
	var h := MotionMath.approach_velocity(horizontal_velocity(), target, tuning.accel(), tuning.decel(), tuning.reverse_accel_multiplier, delta)
	velocity.x = h.x
	velocity.z = h.z
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(tuning.turn_rate_deg) * delta)


func _start_dodge(input_dir: Vector3) -> void:
	var dir := input_dir
	if dir.length() < 0.1:
		dir = -global_transform.basis.z
	dodge_direction = Vector3(dir.x, 0.0, dir.z).normalized()
	# Só termina em velocidade de corrida se o jogador está dirigindo; parado, termina parado.
	_dodge_exit_fraction = 0.0
	if input_dir.length() >= 0.1:
		_dodge_exit_fraction = clampf(tuning.dodge_exit_speed_ratio * tuning.max_speed * tuning.dodge_duration / tuning.dodge_distance, 0.0, 1.0)
	rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
	_dodge_buffer = 0.0
	_enter(State.DODGE, 0.0)
	dodge_started.emit(dodge_direction)


func _tick_dodge(delta: float) -> void:
	var t0 := state_time
	var t1 := minf(state_time + delta, tuning.dodge_duration)
	var d0 := MotionMath.dodge_distance_at(t0 / tuning.dodge_duration, tuning.dodge_distance, _dodge_exit_fraction)
	var d1 := MotionMath.dodge_distance_at(t1 / tuning.dodge_duration, tuning.dodge_distance, _dodge_exit_fraction)
	var v := dodge_direction * ((d1 - d0) / delta)
	velocity.x = v.x
	velocity.z = v.z
	state_time += delta
	# Tolerância de ponto flutuante: sem ela, state_time = 0,2499999 gasta um tick extra com
	# velocidade zero (d1 - d0 = 0) e cria uma parada de 1 tick entre a esquiva e a corrida.
	if state_time >= tuning.dodge_duration - 0.0001:
		_enter(State.RECOVERY, maxf(state_time - tuning.dodge_duration, 0.0))
		dodge_finished.emit()


func _tick_recovery(delta: float) -> void:
	if tuning.dodge_recovery_locks_movement:
		var h := MotionMath.approach_velocity(horizontal_velocity(), Vector3.ZERO, tuning.accel(), tuning.decel(), 1.0, delta)
		velocity.x = h.x
		velocity.z = h.z
	else:
		_locomote(_input_direction(), delta)
	state_time += delta
	if _try_start_attack():
		return
	if state_time >= tuning.dodge_recovery:
		_enter(State.MOVE, 0.0)


func _enter(new_state: State, carry: float) -> void:
	state = new_state
	state_time = carry
	state_changed.emit(new_state)


# --- Ataque ---------------------------------------------------------------------------

## Começa (ou encadeia) um golpe se há ataque guardado. A esquiva tem prioridade sobre o ataque.
func _try_start_attack() -> bool:
	if _dodge_buffer > 0.0 or not combat.has_buffered_attack():
		return false
	if combat.try_start(true):
		_enter(State.ATTACK, 0.0)
		return true
	return false


func _on_strike_started(data: StrikeData, index: int, _swing: int) -> void:
	visual.play_strike(data, index, combat.chained_from, combat.chained_from_clip_time)
	_aim_for_strike(data)


func _on_strike_ended(_data: StrikeData, _completed: bool) -> void:
	# Num encadeamento o corpo não volta à locomoção entre os dois golpes: o próximo `play_strike` assume.
	if combat.chaining:
		return
	visual.end_strike()


## Gira o corpo logo na saída para a direção pressionada ou, sem direção, para o alvo mais próximo
## na frente (assistência de mira). O giro continua na preparação (turn_lock), então o golpe sai
## na direção que o jogador mostrou, sem esperar a animação.
func _aim_for_strike(data: StrikeData) -> void:
	var dir := _input_direction()
	if dir.length() < 0.1:
		dir = _assist_direction()
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		var max_step := deg_to_rad(data.turn_rate_deg) * 0.04
		rotation.y = rotate_toward(rotation.y, target_yaw, max_step)


func _assist_direction() -> Vector3:
	var best := Vector3.ZERO
	var best_d := combat.combo.aim_assist_range
	var fwd := -global_transform.basis.z
	for t: Node in get_tree().get_nodes_in_group(HitDetector.HURTBOX_GROUP):
		var to := (t as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > best_d:
			continue
		if rad_to_deg(fwd.angle_to(to.normalized())) > combat.combo.aim_assist_angle_deg:
			continue
		best_d = d
		best = to.normalized()
	return best


func _tick_attack(delta: float) -> void:
	var dir := _input_direction()
	# Cancelamento por esquiva: vale assim que a janela do golpe abre.
	if _dodge_buffer > 0.0 and combat.dodge_cancel_open():
		combat.cancel()
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	# Encadeamento: ataque guardado + janela aberta.
	if combat.has_buffered_attack() and combat.try_start(true):
		state_time = 0.0
	# Cancelamento da recuperação por movimento: o jogador nunca fica preso depois de atacar.
	if combat.move_cancel_open() and dir.length() > 0.1:
		combat.cancel()
		_enter(State.MOVE, 0.0)
		_locomote(dir, delta)
		return
	var data := combat.current
	var steering := not combat.in_hitstop() and combat.clip_time() < data.turn_lock
	if steering:
		var aim := dir
		if aim.length() < 0.1:
			aim = _assist_direction()
		if aim.length() > 0.1:
			rotation.y = rotate_toward(rotation.y, atan2(-aim.x, -aim.z), deg_to_rad(data.turn_rate_deg) * delta)
	var t0 := combat.time
	var finished := combat.tick(delta)
	var advance := combat.advance_between(t0, combat.time)
	var forward := -global_transform.basis.z
	if combat.in_hitstop():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		# O momento de corrida é absorvido pela frenagem normal; o avanço do golpe vem por cima.
		var target := forward * (advance / delta)
		var h := MotionMath.approach_velocity(horizontal_velocity(), target, tuning.accel(), tuning.decel(), 1.0, delta)
		velocity.x = h.x
		velocity.z = h.z
	state_time += delta
	if finished or not combat.is_attacking():
		_enter(State.MOVE, 0.0)
