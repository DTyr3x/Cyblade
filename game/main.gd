extends Node3D
## Cena principal do protótipo: monta arena, jogador, câmera e HUD.
##
## Linha de comando (depois de `--`):
##   --playtest        roda o playtest scriptado (tools/scripted_playtest.gd) e sai
##   --out=<pasta>     pasta de saída das capturas e do resultado do playtest

const PLAYTEST_SCRIPT := "res://tools/scripted_playtest.gd"
## Posição do boneco de treino, de frente para o ponto de partida do jogador.
const DUMMY_POSITION := Vector3(0.0, 0.0, 3.5)

var stats := FrameStats.new()
var last_device := "nenhum"

## Boneco de treino (H2) e efeitos de combate.
var dummy: TrainingDummy
var effects: CombatEffects

var _last_frame_usec := 0

@onready var arena: TestArena = $Arena
@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: DebugHud = $DebugHud


func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	player.global_position = TestArena.SPAWN_POSITION
	camera_rig.set_target(player)
	hud.camera_rig = camera_rig
	hud.player = player
	hud.stats = stats
	_build_combat()
	if "--playtest" in OS.get_cmdline_user_args():
		var driver: Node = (load(PLAYTEST_SCRIPT) as GDScript).new()
		driver.set("main", self)
		add_child(driver)


func _build_combat() -> void:
	dummy = TrainingDummy.new()
	dummy.name = "BonecoDeTreino"
	add_child(dummy)
	dummy.global_position = DUMMY_POSITION
	effects = CombatEffects.new()
	effects.name = "CombateEfeitos"
	add_child(effects)
	effects.setup(player.combat, player.visual, player.hit_detector, camera_rig)


func _physics_process(_delta: float) -> void:
	# Roda antes da física do jogador (pai antes dos filhos).
	player.move_yaw = camera_rig.yaw


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		var rid := get_viewport().get_viewport_rid()
		stats.record(
			(now - _last_frame_usec) / 1000000.0,
			RenderingServer.viewport_get_measured_render_time_gpu(rid),
			RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_last_frame_usec = now
	hud.last_device = last_device
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_device = "teclado/mouse"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3):
		last_device = "gamepad"
