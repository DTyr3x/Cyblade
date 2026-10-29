class_name CombatEffects
extends Node3D
## Efeitos visuais e sonoros do combate: rastro da lâmina, faíscas, clarão, sons provisórios,
## hitstop visual do clipe e tremor discreto de câmera. Só escuta sinais: remover este nó deixa o
## combate funcionando (sem retorno visual/sonoro).

const TRAIL_LIFE := 0.13
const TRAIL_MAX_SAMPLES := 40
const TRAIL_FROM := 0.62   # trecho da lâmina que deixa rastro (m a partir do punho)
const TRAIL_TO := 1.00

var controller: CombatController
var visual: HumanoidVisual
var detector: HitDetector
var camera_rig: CameraRig
## Liga/desliga conjuntos de efeitos (para medir custo e para o modo de depuração).
var trail_enabled := true
var sparks_enabled := true
var sound_enabled := true

var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _samples: Array = []   # [base, ponta, instante]
var _trail_on := false
var _sparks: CPUParticles3D
var _flash_light: OmniLight3D
var _flash_quad: MeshInstance3D
var _flash_t := 0.0
var _swish: AudioStreamPlayer3D
var _hit_player: AudioStreamPlayer3D
var _swish_streams: Array[AudioStreamWAV] = []
var _hit_light: AudioStreamWAV
var _hit_heavy: AudioStreamWAV
var _shake_log: Array[float] = []


func setup(ctrl: CombatController, vis: HumanoidVisual, det: HitDetector, rig: CameraRig) -> void:
	controller = ctrl
	visual = vis
	detector = det
	camera_rig = rig
	top_level = true
	_build()
	controller.strike_started.connect(_on_strike_started)
	controller.strike_ended.connect(_on_strike_ended)
	detector.hit.connect(_on_hit)


func _build() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = tm
	add_child(_trail)

	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 20
	_sparks.lifetime = 0.4
	_sparks.explosiveness = 1.0
	_sparks.direction = Vector3.UP
	_sparks.spread = 80.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 7.0
	_sparks.gravity = Vector3(0, -12.0, 0)
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.015, 0.015, 0.12)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.75, 0.3)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.7, 0.25)
	sm.emission_energy_multiplier = 3.0
	spark_mesh.material = sm
	_sparks.mesh = spark_mesh
	_sparks.top_level = true
	add_child(_sparks)

	_flash_light = OmniLight3D.new()
	_flash_light.light_color = Color(1.0, 0.8, 0.55)
	_flash_light.omni_range = 4.5
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	_flash_light.top_level = true
	add_child(_flash_light)

	_flash_quad = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var glow := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.92, 0.75, 1), Color(1, 0.6, 0.25, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	glow.gradient = grad
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 128
	glow.height = 128
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = glow
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	quad.material = fm
	_flash_quad.mesh = quad
	_flash_quad.top_level = true
	_flash_quad.visible = false
	_flash_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flash_quad)

	_swish = AudioStreamPlayer3D.new()
	_swish.volume_db = -8.0
	_swish.top_level = true
	add_child(_swish)
	_hit_player = AudioStreamPlayer3D.new()
	_hit_player.volume_db = -3.0
	_hit_player.top_level = true
	add_child(_hit_player)
	for i in 3:
		_swish_streams.append(GeneratedSounds.swish(0.2 + 0.03 * i, 0.9 + 0.2 * i, 7 + i))
	_hit_light = GeneratedSounds.impact(false)
	_hit_heavy = GeneratedSounds.impact(true)


func _on_strike_started(data: StrikeData, index: int, _swing: int) -> void:
	_trail_on = true
	if sound_enabled:
		_swish.global_position = visual.global_position + Vector3.UP
		_swish.stream = _swish_streams[index % _swish_streams.size()]
		# O som do corte começa na preparação e acompanha o ritmo do golpe.
		_swish.pitch_scale = data.speed / 1.5
		_swish.play(0.0)


func _on_strike_ended(_data: StrikeData, _completed: bool) -> void:
	_trail_on = false


func _on_hit(info: Dictionary) -> void:
	var p: Vector3 = info["point"]
	var heavy: bool = int(info["reaction"]) == StrikeData.Reaction.HEAVY
	if sparks_enabled:
		var back: Vector3 = -(info["direction"] as Vector3)
		_sparks.global_position = p
		_sparks.direction = (back + Vector3.UP * 0.5).normalized()
		_sparks.amount = 34 if heavy else 18
		_sparks.restart()
		_sparks.emitting = true
		_flash_t = 0.11 if heavy else 0.08
		_flash_light.global_position = p + Vector3.UP * 0.2
		_flash_quad.global_position = p
	if sound_enabled:
		_hit_player.global_position = p
		_hit_player.stream = _hit_heavy if heavy else _hit_light
		_hit_player.play()
	var shake: float = info["camera_shake"]
	if shake > 0.0 and camera_rig != null:
		camera_rig.add_shake(shake, 0.14)
		_shake_log.append(shake)


## Quantos tremores de câmera foram pedidos (para testes).
func shake_count() -> int:
	return _shake_log.size()


func _process(delta: float) -> void:
	if controller == null:
		return
	visual.set_hit_freeze(controller.in_hitstop())
	_update_flash(delta)
	_update_trail()


func _update_flash(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
		var k := _flash_t / 0.11
		_flash_light.light_energy = 6.0 * k
		_flash_quad.visible = true
		_flash_quad.scale = Vector3.ONE * (0.10 + 0.32 * k)
	elif _flash_quad.visible:
		_flash_quad.visible = false
		_flash_light.light_energy = 0.0


func _update_trail() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Grava amostras da lâmina enquanto o golpe está na preparação final, contato e começo da recuperação.
	if trail_enabled and _trail_on and controller.phase != CombatController.Phase.NONE:
		var d := controller.current
		var ct := controller.clip_time()
		if ct >= d.active_start * 0.7 and ct <= d.active_end + 0.08:
			var seg := visual.blade_segment(TRAIL_FROM, TRAIL_TO)
			_samples.append([seg[0], seg[1], now])
			if _samples.size() > TRAIL_MAX_SAMPLES:
				_samples.pop_front()
	while not _samples.is_empty() and now - float(_samples[0][2]) > TRAIL_LIFE:
		_samples.pop_front()
	_trail_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for s: Array in _samples:
		var age := (now - float(s[2])) / TRAIL_LIFE
		var a := clampf(1.0 - age, 0.0, 1.0)
		_trail_mesh.surface_set_color(Color(0.35, 0.85, 1.0, a * 0.08))
		_trail_mesh.surface_add_vertex(s[0])
		_trail_mesh.surface_set_color(Color(0.75, 0.95, 1.0, a * 0.55))
		_trail_mesh.surface_add_vertex(s[1])
	_trail_mesh.surface_end()


## Número de amostras vivas do rastro (para testes).
func trail_samples() -> int:
	return _samples.size()
