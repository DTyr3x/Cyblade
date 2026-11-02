class_name PostureEffects
extends Node3D
## Leitura da postura no mundo: um anel no chão em volta do inimigo, sons de cravar e de quebrar e a letra de
## finalizar. Só escuta o PostureController; remover este nó não muda a lógica. O anel não entra no HUD, então
## funciona com qualquer número de inimigos.
##
##   sem pressão: invisível · pressão: arco magenta translúcido · cravada: mesmo arco, opaco
##   acima de 75%: pulso lento · quebrado: anel branco que esvazia durante a janela (é o cronômetro)

const RING_SIZE := 1.8
const PULSE_FROM := 0.75
const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float fill = 0.0;
uniform float locked = 0.0;
uniform float glow = 1.0;
uniform vec3 tint = vec3(1.0, 0.1, 0.7);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float band = smoothstep(0.79, 0.82, r) * (1.0 - smoothstep(0.95, 0.98, r));
	float a = fract(atan(p.x, -p.y) / TAU + 1.0);
	float strength = max(step(a, fill) * 0.5, step(a, locked));
	ALBEDO = tint;
	EMISSION = tint * (1.0 + 2.0 * strength) * glow;
	ALPHA = band * max(strength, 0.08);
}
"""

var enemy: TrainingInstructor
var player: Player
var _ring: MeshInstance3D
var _mat: ShaderMaterial
var _letter: Label3D
var _audio: AudioStreamPlayer3D
var _lock_sound: AudioStreamWAV
var _break_sound: AudioStreamWAV
var _finish_sound: AudioStreamWAV
var _break_len := 1.0
## Registro para testes.
var events: Array[String] = []


func setup(target_enemy: TrainingInstructor, target_player: Player) -> void:
	enemy = target_enemy
	player = target_player
	top_level = true
	_build()
	var p := enemy.posture
	p.pressure_applied.connect(_on_pressure)
	p.broken.connect(_on_broken)
	p.finished.connect(_on_finished)


func _build() -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * RING_SIZE
	var shader := Shader.new()
	shader.code = RING_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	quad.material = _mat
	_ring = MeshInstance3D.new()
	_ring.mesh = quad
	_ring.top_level = true
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_letter = Label3D.new()
	_letter.text = "F / Y"
	_letter.font_size = 96
	_letter.pixel_size = 0.008
	_letter.outline_size = 18
	_letter.modulate = Color(1, 1, 1)
	_letter.outline_modulate = Color(0.75, 0.05, 0.55)
	_letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_letter.no_depth_test = true
	_letter.top_level = true
	_letter.visible = false
	add_child(_letter)

	_audio = AudioStreamPlayer3D.new()
	_audio.top_level = true
	_audio.volume_db = -2.0
	add_child(_audio)
	_lock_sound = GeneratedSounds.posture_lock()
	_break_sound = GeneratedSounds.posture_break()
	_finish_sound = GeneratedSounds.finish_hit()


func _on_pressure(info: Dictionary) -> void:
	if info["locks"]:
		events.append("cravou")
		_play(_lock_sound)


func _on_broken(by_precision: bool) -> void:
	events.append("quebra_precisa" if by_precision else "quebra")
	_break_len = maxf(enemy.posture.broken_until - CombatClock.time, 0.01)
	_play(_break_sound)


func _on_finished() -> void:
	events.append("cravada")
	_play(_finish_sound)


func _play(stream: AudioStreamWAV) -> void:
	_audio.global_position = enemy.global_position + Vector3.UP
	_audio.stream = stream
	_audio.play()


func ring_visible() -> bool:
	return _ring.visible


func ring_fill() -> float:
	return float(_mat.get_shader_parameter("fill"))


func letter_visible() -> bool:
	return _letter.visible


func _process(_delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var p := enemy.posture
	var now := CombatClock.time
	_ring.global_position = enemy.global_position + Vector3(0, 0.04, 0)
	var breaking := p.state != PostureController.State.STABLE
	_ring.visible = p.enabled and (breaking or p.current > 0.01)
	if breaking:
		var left := 1.0 if p.state == PostureController.State.FINISHING else clampf((p.broken_until - now) / _break_len, 0.0, 1.0)
		_mat.set_shader_parameter("fill", left)
		_mat.set_shader_parameter("locked", left)
		_mat.set_shader_parameter("tint", Color(1, 1, 1))
		_mat.set_shader_parameter("glow", 1.0)
	else:
		_mat.set_shader_parameter("fill", p.current_ratio())
		_mat.set_shader_parameter("locked", p.locked_ratio())
		_mat.set_shader_parameter("tint", Color(1.0, 0.1, 0.7))
		var hot := p.current_ratio() >= PULSE_FROM
		_mat.set_shader_parameter("glow", 1.0 + (0.6 + 0.6 * sin(now * TAU * 1.5) if hot else 0.0))
	var near := player != null and p.state == PostureController.State.BROKEN and player.global_position.distance_to(enemy.global_position) <= p.data.finish_range + 0.1
	_letter.visible = near
	if near:
		_letter.global_position = enemy.global_position + Vector3(0, 2.2, 0)
