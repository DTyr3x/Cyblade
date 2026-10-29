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
	_setup_tree()
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
	_update_turn(delta, forward, dodging)
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
	armor.albedo_color = Color(0.20, 0.22, 0.28)
	armor.metallic = 0.35
	armor.roughness = 0.5
	# Brilho mínimo para o corpo se destacar do piso escuro na câmera alta (material provisório).
	armor.emission_enabled = true
	armor.emission = Color(0.10, 0.14, 0.2)
	armor.emission_energy_multiplier = 0.6
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = armor


func _setup_tree() -> void:
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
	root.connect_node("output", 0, "RunScale")

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
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
