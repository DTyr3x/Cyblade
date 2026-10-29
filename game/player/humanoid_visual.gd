class_name HumanoidVisual
extends Node3D
## Visual humanoide do jogador: esqueleto (Skeleton3D) animado por um AnimationTree.
##
## REGRA CENTRAL: a cápsula (Player) comanda o movimento. Este nó só LÊ a velocidade e o
## estado e escolhe a pose. Nunca altera posição, velocidade nem estado do jogador, então
## nenhuma animação pode atrasar a entrada nem recriar a frenagem pós-esquiva.
##
## Animações: Universal Animation Library, Quaternius, CC0 (ver docs/ativos/registro.md).
## Frente do modelo = -Z local do nó (convenção do jogo).

const MODEL_PATH := "res://assets/characters/ual/UAL1_Standard.glb"

## Ponto do eixo de locomoção = velocidade de AUTORIA do clipe (m/s). Walk e Jog foram calibrados
## medindo a velocidade do pé em apoio em relação ao corpo (0,77 e 5,46 m/s); o Sprint (8,25) vem do
## deslocamento do root do clipe e só é usado na investida da esquiva (a corrida usa Jog acelerado).
const LOCO_POINTS := [
	["Idle", 0.0],
	["Walk", 0.77],
	["Jog_Fwd", 5.46],
	["Sprint", 8.25],
]

## Pico de velocidade de autoria (Sprint). Na esquiva, o ciclo de corrida vai a esse ponto.
const DASH_BLEND_POINT := 8.25
## O ciclo de Jog pode tocar até 25% mais rápido antes de entrar mistura com Sprint (a corrida
## de 6 m/s fica em Jog a 1,10x, sem misturar passadas de ritmos diferentes).
const JOG_SPEED := 5.46
const MAX_JOG_SCALE := 1.25

## Giros: o quadril visual acompanha a frente da cápsula com esta constante de tempo (s) em vez de
## girar junto, e o tronco lidera (ver HumanoidPoseModifier.torso_lead). Só o visual: a cápsula,
## a velocidade e a direção do movimento não esperam por isto. Na esquiva o desvio é zerado.
## Mistura do golpe sobre a locomoção (s): entrada rápida (o golpe responde), saída um pouco mais longa.
const STRIKE_FADE_IN := 0.06
const STRIKE_FADE_OUT := 0.12
## Troca de clipe num encadeamento contínuo: mistura mínima (s) e máxima quando o encadeamento é tardio.
const SEAMLESS_BLEND := 0.03
const SEAMLESS_BLEND_MAX := 0.12
## Guarda (C1): clipe autoral e tempos de entrada e saída da mistura (s).
const GUARD_CLIP_PATH := "res://assets/animations/katana/katana_guarda.res"
const GUARD_CLIP_NAME := &"Katana_Guarda"
const GUARD_IN := 0.035
const GUARD_OUT := 0.08

## Empunhadura nos golpes autorais: a lâmina sai pelo lado do polegar (+Z local da mão), como numa
## pegada real, em vez de continuar o antebraço (+Y, usado na corrida aprovada).
const STRIKE_GRIP := Basis(Vector3.RIGHT, PI / 2.0)

const TURN_LAG_TAU := 0.05
## Desvio visual máximo atrás da cápsula (graus), para giros de 180° não torcerem demais.
const TURN_LAG_MAX_DEG := 60.0

signal skeleton_ready

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var pose_modifier: HumanoidPoseModifier
var katana: Node3D

var _player: Player
var _blend_pos := 0.0
var _run_scale := 1.0
var _strike_clips: Array[StringName] = []
var _strike_active := false
var _strike_speed := 1.0
var _hit_freeze := false
var _strike_blend := 0.0
var _strike_authored_grip := false
var _grip: Node3D
var _sel_node: AnimationNodeTransition
## Guarda (C1): mistura da pose de guarda no tronco e nos braços; as pernas seguem a locomoção.
var _guard_target := 0.0
var _guard_blend := 0.0
var _has_guard := false
var _freeze_left := 0.0
var _armor: StandardMaterial3D
var _body_flash := 0.0
var _body_flash_color := Color(1, 0.1, 0.1)
var _visual_yaw := 0.0
var _yaw_ready := false


func _ready() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	var model := packed.instantiate() as Node3D
	# O glTF aponta para +Z; o jogo usa -Z como frente.
	model.rotation.y = PI
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_setup_materials(model)
	_setup_tree(null)
	_setup_pose_modifier()
	_setup_katana()
	skeleton_ready.emit()


## Liga o visual ao jogador. Chamado por Player._ready.
func bind(player: Player) -> void:
	_player = player


## Chamado a cada quadro de render pelo jogador.
func update_pose(delta: float, velocity: Vector3, forward: Vector3, max_speed: float, dodging: bool) -> void:
	if anim_tree == null:
		return
	pose_modifier.set_motion(delta, velocity, forward, max_speed, dodging)
	_update_turn(delta, forward, dodging or _strike_active)
	var blend_target := 1.0 if _strike_active else 0.0
	var tau := STRIKE_FADE_IN * 0.5 if _strike_active else STRIKE_FADE_OUT * 0.5
	_strike_blend = lerpf(_strike_blend, blend_target, MotionMath.smooth_alpha(delta, tau))
	_guard_blend = lerpf(_guard_blend, _guard_target, MotionMath.smooth_alpha(delta, GUARD_IN if _guard_target > _guard_blend else GUARD_OUT))
	if _has_guard:
		anim_tree["parameters/Guard/blend_amount"] = _guard_blend
	pose_modifier.set_strike_blend(maxf(_strike_blend, _guard_blend))
	if _grip != null:
		var grip_w := maxf(_strike_blend if _strike_authored_grip else 0.0, _guard_blend)
		_grip.basis = Basis.IDENTITY.slerp(STRIKE_GRIP, grip_w)
	_update_freeze_and_flash(delta)
	if not _strike_clips.is_empty():
		anim_tree["parameters/StrikeScale/scale"] = 0.02 if _hit_freeze else _strike_speed
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	# Posição de mistura e velocidade de reprodução: o ciclo acelera até MAX_JOG_SCALE antes de
	# passar ao Sprint. Assim os pés acompanham o chão sem misturar ritmos de passada.
	var gait := speed
	var scale := 1.0
	if speed > JOG_SPEED:
		scale = minf(speed / JOG_SPEED, MAX_JOG_SCALE)
		var over := speed - JOG_SPEED * MAX_JOG_SCALE
		gait = JOG_SPEED if over <= 0.0 else JOG_SPEED + over * (DASH_BLEND_POINT - JOG_SPEED) / (DASH_BLEND_POINT - JOG_SPEED * MAX_JOG_SCALE)
		scale = 1.0 if over > 0.0 else scale
	var dash := pose_modifier.dash_amount()
	# Na esquiva o ciclo vai ao ponto de sprint (investida); a mistura é suave.
	_blend_pos = lerpf(minf(gait, DASH_BLEND_POINT), DASH_BLEND_POINT, dash)
	anim_tree["parameters/Loco/blend_position"] = _blend_pos
	anim_tree["parameters/RunScale/scale"] = lerpf(scale, 1.0, dash)
	_run_scale = scale


## Quadril visual atrás da frente da cápsula (rad, com sinal): 0 = alinhado.
func turn_offset() -> float:
	return rotation.y


func _update_turn(delta: float, forward: Vector3, dodging: bool) -> void:
	var body_yaw := atan2(-forward.x, -forward.z)
	if not _yaw_ready or dodging:
		_visual_yaw = body_yaw
		_yaw_ready = true
	else:
		_visual_yaw = lerp_angle(_visual_yaw, body_yaw, MotionMath.smooth_alpha(delta, TURN_LAG_TAU))
	var lag := clampf(angle_difference(_visual_yaw, body_yaw), -deg_to_rad(TURN_LAG_MAX_DEG), deg_to_rad(TURN_LAG_MAX_DEG))
	_visual_yaw = body_yaw - lag
	rotation.y = -lag
	pose_modifier.set_turn_offset(rotation.y)


func blend_position() -> float:
	return _blend_pos


func run_scale() -> float:
	return _run_scale


## Velocidade que a animação "cobre": posição de mistura x velocidade de reprodução.
## Em corrida normal é igual à velocidade da cápsula (pés acompanham o chão).
func effective_speed() -> float:
	return _blend_pos * _run_scale


func _setup_materials(model: Node) -> void:
	var armor := StandardMaterial3D.new()
	_armor = armor
	armor.albedo_color = Color(0.20, 0.22, 0.28)
	armor.metallic = 0.35
	armor.roughness = 0.5
	# Brilho mínimo para o corpo se destacar do piso escuro na câmera alta (material provisório).
	armor.emission_enabled = true
	armor.emission = Color(0.10, 0.14, 0.2)
	armor.emission_energy_multiplier = 0.6
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = armor


func _setup_tree(combo: ComboSet) -> void:
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 8.25
	blend.sync = true
	for p: Array in LOCO_POINTS:
		var node := AnimationNodeAnimation.new()
		node.animation = p[0]
		blend.add_blend_point(node, p[1], -1, StringName(p[0]))

	var root := AnimationNodeBlendTree.new()
	root.add_node("Loco", blend)
	root.add_node("RunScale", AnimationNodeTimeScale.new())
	root.connect_node("RunScale", 0, "Loco")
	# Guarda: Blend2 com filtro (só coluna, cabeça e braços) entre a locomoção e a pose de guarda.
	var base_out := "RunScale"
	if _has_guard:
		var guard_clip := AnimationNodeAnimation.new()
		guard_clip.animation = GUARD_CLIP_NAME
		root.add_node("GuardClip", guard_clip)
		var guard := AnimationNodeBlend2.new()
		guard.filter_enabled = true
		for path: NodePath in _upper_body_paths():
			guard.set_filter_path(path, true)
		root.add_node("Guard", guard)
		root.connect_node("Guard", 0, "RunScale")
		root.connect_node("Guard", 1, "GuardClip")
		base_out = "Guard"
	if combo != null and not combo.strikes.is_empty():
		# Golpes: seletor de clipe -> escala de velocidade -> OneShot sobre a locomoção.
		var sel := AnimationNodeTransition.new()
		_sel_node = sel
		sel.input_count = combo.strikes.size()
		sel.xfade_time = 0.0
		for i in combo.strikes.size():
			sel.set_input_name(i, "s%d" % i)
			var clip := AnimationNodeAnimation.new()
			clip.animation = _strike_clips[i]
			root.add_node("Clip%d" % i, clip)
		root.add_node("Sel", sel)
		for i in combo.strikes.size():
			root.connect_node("Sel", i, "Clip%d" % i)
		root.add_node("StrikeScale", AnimationNodeTimeScale.new())
		root.connect_node("StrikeScale", 0, "Sel")
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = STRIKE_FADE_IN
		shot.fadeout_time = STRIKE_FADE_OUT
		root.add_node("Strike", shot)
		root.connect_node("Strike", 0, base_out)
		root.connect_node("Strike", 1, "StrikeScale")
		root.connect_node("output", 0, "Strike")
	else:
		root.connect_node("output", 0, base_out)

	if anim_tree == null:
		anim_tree = AnimationTree.new()
		anim_tree.name = "AnimationTree"
		add_child(anim_tree)
		anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.active = false
	anim_tree.tree_root = root
	anim_tree.active = true


func _setup_pose_modifier() -> void:
	pose_modifier = HumanoidPoseModifier.new()
	pose_modifier.name = "PoseModifier"
	skeleton.add_child(pose_modifier)


func _setup_katana() -> void:
	var attach := BoneAttachment3D.new()
	attach.name = "KatanaAttachment"
	attach.bone_name = "hand_r"
	skeleton.add_child(attach)
	katana = Katana.build()
	attach.add_child(katana)
	# Empunhadura: identidade na locomoção (aprovada); gira para STRIKE_GRIP nos golpes autorais.
	_grip = katana


# --- Golpes -------------------------------------------------------------------------

## Cria os clipes de golpe (derivados de `Sword_Attack`) e reconstrói a árvore com o OneShot.
## Chamado pelo Player depois de montar o ComboSet.
func setup_strikes(combo: ComboSet) -> void:
	var lib := anim_player.get_animation_library("")
	var src := anim_player.get_animation(KatanaClips.SOURCE_CLIP)
	_strike_clips.clear()
	for i in combo.strikes.size():
		var s := combo.strikes[i]
		var source := s.clip_resource if s.clip_resource != null else src
		var clip := KatanaClips.derive(source, s.clip_from, s.clip_to, KatanaClips.Mirror.YZ_FLIP if s.mirrored else KatanaClips.Mirror.NONE)
		var clip_name := StringName("Katana_%d" % i)
		if lib.has_animation(clip_name):
			lib.remove_animation(clip_name)
		lib.add_animation(clip_name, clip)
		_strike_clips.append(clip_name)
	# Pose de guarda (C1), autoral: tools/blender/katana_guard_keys.py.
	if ResourceLoader.exists(GUARD_CLIP_PATH):
		var guard := load(GUARD_CLIP_PATH) as Animation
		guard.loop_mode = Animation.LOOP_LINEAR
		if lib.has_animation(GUARD_CLIP_NAME):
			lib.remove_animation(GUARD_CLIP_NAME)
		lib.add_animation(GUARD_CLIP_NAME, guard)
		_has_guard = true
	_setup_tree(combo)


## Inicia o clipe do golpe `index` (reinicia se já estava tocando outro).
func play_strike(data: StrikeData, index: int, from_data: StrikeData = null, from_clip_time := 0.0) -> void:
	if anim_tree == null or _strike_clips.is_empty():
		return
	# Encadeamento contínuo: os dois golpes são autorais e o corpo ainda está no golpe anterior.
	# Troca o clipe dentro do mesmo OneShot (sem voltar à locomoção); o primeiro quadro do novo clipe
	# é a pose do anterior no quadro de encadeamento, e o resíduo (encadeamento tardio) é suavizado.
	var seamless := data.seamless_chain and from_data != null and from_data.authored_grip \
			and _strike_active and bool(anim_tree["parameters/Strike/active"])
	_strike_active = true
	_strike_speed = data.speed
	_strike_authored_grip = data.authored_grip
	_hit_freeze = false
	anim_tree["parameters/StrikeScale/scale"] = data.speed
	if seamless:
		var late := maxf(from_clip_time - from_data.chain_open, 0.0)
		_sel_node.xfade_time = clampf(SEAMLESS_BLEND + late * 0.8, SEAMLESS_BLEND, SEAMLESS_BLEND_MAX)
		anim_tree["parameters/Sel/transition_request"] = "s%d" % index
		return
	anim_tree["parameters/Sel/transition_request"] = "s%d" % index
	anim_tree["parameters/Strike/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	anim_tree["parameters/Strike/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE


## Encerra o golpe: o OneShot some com a mistura de saída e a locomoção reassume.
func end_strike() -> void:
	if anim_tree == null or _strike_clips.is_empty():
		return
	_strike_active = false
	_hit_freeze = false
	anim_tree["parameters/Strike/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT


## Congela só o clipe do golpe (hitstop). A locomoção e o resto do jogo continuam.
func set_hit_freeze(on: bool) -> void:
	_hit_freeze = on


func is_striking() -> bool:
	return _strike_active


## Peso do golpe sobre o corpo (0 = locomoção, 1 = golpe), suavizado como a mistura do OneShot.
func strike_blend() -> float:
	return _strike_blend


## Segmento da lâmina da katana no mundo: [base, ponta] entre `from` e `to` metros do punho.
func blade_segment(from := Katana.BLADE_START, to := Katana.BLADE_END) -> Array[Vector3]:
	var t := katana.global_transform
	var axis := t.basis.y.normalized()
	var scale := t.basis.y.length()
	return [t.origin + axis * from * scale, t.origin + axis * to * scale]


# --- Defesa (C1) -----------------------------------------------------------------------------

## Pose de guarda ligada/desligada (a mistura é suave e rápida).
func set_guard(on: bool) -> void:
	_guard_target = 1.0 if on else 0.0


func guard_blend() -> float:
	return _guard_blend


## Congela toda a animação do corpo por `duration` s (hitstop local do parry e da defesa).
func freeze(duration: float) -> void:
	_freeze_left = maxf(_freeze_left, duration)


func is_frozen() -> bool:
	return _freeze_left > 0.0


## Clarão curto no corpo (golpe recebido em vermelho; parry em branco).
func flash_body(color: Color, strength := 1.0) -> void:
	_body_flash_color = color
	_body_flash = strength


func _update_freeze_and_flash(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left = maxf(_freeze_left - delta, 0.0)
		anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	elif anim_tree.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
		anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if _armor != null:
		_body_flash = maxf(_body_flash - delta * 7.0, 0.0)
		if _body_flash > 0.0:
			_armor.emission = Color(0.10, 0.14, 0.2).lerp(_body_flash_color, minf(_body_flash, 1.0))
			_armor.emission_energy_multiplier = 0.6 + 1.6 * _body_flash
		else:
			_armor.emission = Color(0.10, 0.14, 0.2)
			_armor.emission_energy_multiplier = 0.6


## Caminhos dos ossos da coluna para cima (inclui cabeça e braços): a guarda só mexe nesses.
func _upper_body_paths() -> Array[NodePath]:
	var out: Array[NodePath] = []
	var root_bone := skeleton.find_bone("spine_01")
	for i in skeleton.get_bone_count():
		var b := i
		while b >= 0 and b != root_bone:
			b = skeleton.get_bone_parent(b)
		if b == root_bone:
			out.append(NodePath("Armature/Skeleton3D:" + skeleton.get_bone_name(i)))
	return out
