class_name CameraRig
extends Node3D
## Câmera elevada de acompanhamento com presets de enquadramento.
##
## O rig fica no ponto de foco, inclinado para baixo; a Camera3D é filha dele,
## recuada `distance` metros. Tudo roda em _process com suavização exponencial
## (independente da taxa de quadros). Lê a posição interpolada do alvo, então
## não treme com a física a 120 Hz e o render em taxa diferente.

signal preset_changed(preset: CameraPreset)

const DEFAULT_PRESET_PATHS := [
	"res://game/data/camera_preset_combate.tres",
	"res://game/data/camera_preset_exploracao.tres",
	"res://game/data/camera_preset_chefe.tres",
]
## Velocidade em que a antecipação atinge o máximo, m/s.
const LOOK_AHEAD_REFERENCE_SPEED := 6.0

@export var target: Node3D
@export var presets: Array[CameraPreset] = []
@export var start_preset := 0
@export var allow_manual_yaw := true
@export var mouse_yaw_deg_per_pixel := 0.25
@export var stick_yaw_deg_per_second := 140.0

## Guinada atual (rad). Positivo = gira para a esquerda (anti-horário visto de cima).
var yaw := 0.0
var camera: Camera3D
var preset_index := 0

var _pitch := 45.0
var _distance := 20.0
var _fov := 34.0
var _focus_height := 1.0
var _framing_shift := 0.0
var _follow_tau := 0.1
var _look_ahead := 0.0
var _look_ahead_tau := 0.3
var _follow_pos := Vector3.ZERO
var _ahead := Vector3.ZERO
var _shake_amp := 0.0
var _shake_left := 0.0
var _shake_total := 0.01
var _shake_clock := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if presets.is_empty():
		for path: String in DEFAULT_PRESET_PATHS:
			presets.append(load(path) as CameraPreset)
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.near = 0.3
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	set_preset(start_preset, true)


func current_preset() -> CameraPreset:
	return presets[preset_index]


func set_target(new_target: Node3D) -> void:
	target = new_target
	snap()


## Posiciona a câmera já no alvo, sem suavização.
func snap() -> void:
	if target == null:
		return
	_follow_pos = _target_position()
	_ahead = Vector3.ZERO
	_apply()


func set_preset(index: int, instant := false) -> void:
	preset_index = posmod(index, presets.size())
	if instant:
		var p := presets[preset_index]
		_pitch = p.pitch_deg
		_distance = p.distance
		_fov = p.fov_deg
		_focus_height = p.focus_height
		_framing_shift = p.framing_shift
		_follow_tau = p.follow_tau
		_look_ahead = p.look_ahead
		_look_ahead_tau = p.look_ahead_tau
		_apply()
	preset_changed.emit(presets[preset_index])


## Tremor curto e discreto (amplitude em m, duração em s). Decai suavemente. Pedidos menores que o
## tremor em andamento não o reduzem.
func add_shake(amplitude: float, duration: float) -> void:
	if amplitude >= _shake_amp * (_shake_left / _shake_total):
		_shake_amp = amplitude
		_shake_left = duration
		_shake_total = maxf(duration, 0.01)


func reset_yaw() -> void:
	yaw = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if allow_manual_yaw and event is InputEventMouseMotion \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= deg_to_rad(mouse_yaw_deg_per_pixel) * (event as InputEventMouseMotion).relative.x


func _process(delta: float) -> void:
	_read_input(delta)
	if target != null:
		_update_follow(delta)
	_blend_preset(delta)
	_update_shake(delta)
	_apply()


func _read_input(delta: float) -> void:
	if allow_manual_yaw:
		var axis := Input.get_axis("camera_yaw_left", "camera_yaw_right")
		yaw -= deg_to_rad(stick_yaw_deg_per_second) * axis * delta
	if Input.is_action_just_pressed("camera_reset"):
		reset_yaw()
	if Input.is_action_just_pressed("camera_preset_1"):
		set_preset(0)
	elif Input.is_action_just_pressed("camera_preset_2"):
		set_preset(1)
	elif Input.is_action_just_pressed("camera_preset_3"):
		set_preset(2)
	elif Input.is_action_just_pressed("camera_preset_next"):
		set_preset(preset_index + 1)
	elif Input.is_action_just_pressed("camera_preset_prev"):
		set_preset(preset_index - 1)


func _target_position() -> Vector3:
	return target.get_global_transform_interpolated().origin


func _update_follow(delta: float) -> void:
	_follow_pos = _follow_pos.lerp(_target_position(), MotionMath.smooth_alpha(delta, _follow_tau))
	var desired := Vector3.ZERO
	if target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		desired = Vector3(v.x, 0.0, v.z) / LOOK_AHEAD_REFERENCE_SPEED * _look_ahead
		desired = desired.limit_length(_look_ahead)
	_ahead = _ahead.lerp(desired, MotionMath.smooth_alpha(delta, _look_ahead_tau))


func _blend_preset(delta: float) -> void:
	var p := presets[preset_index]
	var a := MotionMath.smooth_alpha(delta, p.blend_time / 4.0)
	_pitch = lerpf(_pitch, p.pitch_deg, a)
	_distance = lerpf(_distance, p.distance, a)
	_fov = lerpf(_fov, p.fov_deg, a)
	_focus_height = lerpf(_focus_height, p.focus_height, a)
	_framing_shift = lerpf(_framing_shift, p.framing_shift, a)
	_follow_tau = lerpf(_follow_tau, p.follow_tau, a)
	_look_ahead = lerpf(_look_ahead, p.look_ahead, a)
	_look_ahead_tau = lerpf(_look_ahead_tau, p.look_ahead_tau, a)


func _update_shake(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		_shake_clock += delta
	if _shake_left <= 0.0:
		_shake_amp = 0.0


func _apply() -> void:
	var ground_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	global_position = _follow_pos + _ahead \
		+ Vector3(0.0, _focus_height, 0.0) + ground_forward * _framing_shift
	rotation = Vector3(-deg_to_rad(_pitch), yaw, 0.0)
	if camera != null:
		camera.position = Vector3(0.0, 0.0, _distance)
		camera.fov = _fov
		var k := (_shake_left / _shake_total) if _shake_amp > 0.0 else 0.0
		camera.h_offset = sin(_shake_clock * 130.0) * _shake_amp * k * k
		camera.v_offset = sin(_shake_clock * 97.0 + 1.3) * _shake_amp * k * k


## Valores atuais (suavizados), para HUD e testes.
func state() -> Dictionary:
	return {
		"preset": current_preset().preset_name,
		"pitch_deg": _pitch,
		"distance": _distance,
		"fov_deg": _fov,
		"follow_tau": _follow_tau,
		"yaw_deg": rad_to_deg(yaw),
	}
