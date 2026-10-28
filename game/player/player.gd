class_name Player
extends CharacterBody3D
## Ninja jogável: movimento relativo à câmera, giro, aceleração, frenagem e esquiva.
##
## Estados: MOVE -> DODGE (deslocamento) -> RECOVERY (sem controle) -> MOVE.
## Física em 120 Hz; a lógica usa só `delta`, nunca a taxa de quadros de render.

signal state_changed(new_state: int)
signal dodge_started(direction: Vector3)
signal dodge_finished

enum State { MOVE, DODGE, RECOVERY }

@export var tuning: PlayerTuning

## Guinada da câmera (rad). Quem monta a cena atualiza antes da física do jogador.
var move_yaw := 0.0
var state: State = State.MOVE
var state_time := 0.0
var dodge_direction := Vector3.ZERO

var _dodge_buffer := 0.0
var _visual: NinjaVisual


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	floor_snap_length = 0.4
	_visual = NinjaVisual.new()
	add_child(_visual)


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

	match state:
		State.MOVE:
			_tick_move(delta)
		State.DODGE:
			_tick_dodge(delta)
		State.RECOVERY:
			_tick_recovery(delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= tuning.gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	var forward := -global_transform.basis.z
	var ratio := horizontal_velocity().dot(forward) / tuning.max_speed
	_visual.animate(delta, ratio, state == State.DODGE)


func _input_direction() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, move_yaw)


func _tick_move(delta: float) -> void:
	var dir := _input_direction()
	if _dodge_buffer > 0.0:
		_start_dodge(dir)
		_tick_dodge(delta)
		return
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
	rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
	_dodge_buffer = 0.0
	_enter(State.DODGE, 0.0)
	dodge_started.emit(dodge_direction)


func _tick_dodge(delta: float) -> void:
	var t0 := state_time
	var t1 := minf(state_time + delta, tuning.dodge_duration)
	var d0 := MotionMath.dodge_distance_at(t0 / tuning.dodge_duration, tuning.dodge_distance)
	var d1 := MotionMath.dodge_distance_at(t1 / tuning.dodge_duration, tuning.dodge_distance)
	var v := dodge_direction * ((d1 - d0) / delta)
	velocity.x = v.x
	velocity.z = v.z
	state_time += delta
	if state_time >= tuning.dodge_duration:
		_enter(State.RECOVERY, state_time - tuning.dodge_duration)
		dodge_finished.emit()


func _tick_recovery(delta: float) -> void:
	var h := MotionMath.approach_velocity(horizontal_velocity(), Vector3.ZERO, tuning.accel(), tuning.decel(), 1.0, delta)
	velocity.x = h.x
	velocity.z = h.z
	state_time += delta
	if state_time >= tuning.dodge_recovery:
		_enter(State.MOVE, 0.0)


func _enter(new_state: State, carry: float) -> void:
	state = new_state
	state_time = carry
	state_changed.emit(new_state)
