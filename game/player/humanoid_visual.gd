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

signal skeleton_ready

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var pose_modifier: HumanoidPoseModifier
var katana: Node3D

var _player: Player
var _blend_pos := 0.0
var _run_scale := 1.0


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
	armor.albedo_color = Color(0.07, 0.075, 0.09)
	armor.metallic = 0.6
	armor.roughness = 0.45
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
