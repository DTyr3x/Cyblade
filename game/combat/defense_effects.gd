class_name DefenseEffects
extends Node3D
## Feedback audiovisual da defesa (C1): parry perfeito, defesa normal, golpe recebido e o sinal do
## Instrutor. Só escuta sinais (`Player.attacked`, `TrainingInstructor.cue`); remover este nó não muda
## a lógica. Sem tremor de câmera: o parry é reconhecido pelo som e pelas faíscas direcionais.

var player: Player
var _parry_sparks: CPUParticles3D
var _block_sparks: CPUParticles3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_t := 0.0
var _light: OmniLight3D
var _light_t := 0.0
var _audio: AudioStreamPlayer3D
var _cue_audio: AudioStreamPlayer3D
var _parry_sound: AudioStreamWAV
var _block_sound: AudioStreamWAV
var _hit_sound: AudioStreamWAV
var _cue_sound: AudioStreamWAV
## Registro para testes e HUD.
var events: Array[String] = []

const RING_TIME := 0.12


func setup(p: Player) -> void:
	player = p
	top_level = true
	_build()
	player.attacked.connect(_on_attacked)


## Liga o sinal didático de um Instrutor ao som de "tic".
func watch_instructor(instructor: TrainingInstructor) -> void:
	instructor.cue.connect(func() -> void:
		events.append("sinal")
		_cue_audio.global_position = instructor.global_position + Vector3.UP * 1.5
		_cue_audio.play())


func _build() -> void:
	_parry_sparks = _make_sparks(36, Color(1.0, 0.92, 0.7), 0.32, 6.0, 11.0, 18.0)
	_block_sparks = _make_sparks(10, Color(1.0, 0.6, 0.25), 0.22, 2.5, 4.5, 50.0)

	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 0.78, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(0.85, 0.95, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_texture = tex
	quad.material = _ring_mat
	_ring.mesh = quad
	_ring.top_level = true
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.85, 0.93, 1.0)
	_light.omni_range = 4.0
	_light.light_energy = 0.0
	_light.top_level = true
	add_child(_light)

	_audio = AudioStreamPlayer3D.new()
	_audio.top_level = true
	_audio.volume_db = -1.0
	add_child(_audio)
	_cue_audio = AudioStreamPlayer3D.new()
	_cue_audio.top_level = true
	_cue_audio.volume_db = -6.0
	add_child(_cue_audio)
	_parry_sound = GeneratedSounds.parry_ring()
	_block_sound = GeneratedSounds.block_clank()
	_hit_sound = GeneratedSounds.body_hit()
	_cue_sound = GeneratedSounds.cue_tic()
	_cue_audio.stream = _cue_sound


func _make_sparks(amount: int, color: Color, life: float, vmin: float, vmax: float, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	mesh.material = m
	p.mesh = mesh
	p.top_level = true
	add_child(p)
	return p


func _on_attacked(info: Dictionary) -> void:
	var p: Vector3 = info.get("point", player.global_position + Vector3.UP * 1.2)
	var away: Vector3 = info.get("away", Vector3.FORWARD)
	# Lado do corte: as faíscas saem perpendiculares às lâminas (para o lado e para cima), nunca na câmera.
	var side := Vector3.UP.cross(away).normalized()
	match int(info.get("result", -1)):
		DefenseController.Result.PERFECT:
			events.append("parry")
			_burst(_parry_sparks, p, (side + Vector3.UP * 0.55).normalized())
			_ring.global_position = p
			_ring_t = RING_TIME
			_light.global_position = p
			_light_t = 0.1
			_play(_parry_sound, p)
			player.visual.flash_body(Color(0.8, 0.95, 1.0), 0.45)
		DefenseController.Result.BLOCK:
			events.append("defesa")
			_burst(_block_sparks, p, (side * 0.6 + Vector3.UP * 0.4 - away * 0.3).normalized())
			_play(_block_sound, p)
		DefenseController.Result.HIT:
			events.append("golpe")
			_play(_hit_sound, p)
			player.visual.flash_body(Color(1.0, 0.12, 0.08), 1.0)


func _burst(sparks: CPUParticles3D, at: Vector3, dir: Vector3) -> void:
	sparks.global_position = at
	sparks.direction = dir
	sparks.restart()
	sparks.emitting = true


func _play(stream: AudioStreamWAV, at: Vector3) -> void:
	_audio.global_position = at
	_audio.stream = stream
	_audio.play()


func _process(delta: float) -> void:
	if _ring_t > 0.0:
		_ring_t = maxf(_ring_t - delta, 0.0)
		var k := 1.0 - _ring_t / RING_TIME
		_ring.visible = true
		_ring.scale = Vector3.ONE * (0.25 + 0.75 * k)
		_ring_mat.albedo_color = Color(1, 1, 1, 1.0 - k)
	elif _ring.visible:
		_ring.visible = false
	if _light_t > 0.0:
		_light_t = maxf(_light_t - delta, 0.0)
		_light.light_energy = 5.0 * (_light_t / 0.1)
	elif _light.light_energy > 0.0:
		_light.light_energy = 0.0
