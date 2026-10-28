extends Node3D
## Cena principal do protótipo: monta arena, jogador, câmera e HUD.
##
## Linha de comando (depois de `--`):
##   --playtest        roda o playtest scriptado (tools/scripted_playtest.gd) e sai
##   --out=<pasta>     pasta de saída das capturas e do resultado do playtest

const PLAYTEST_SCRIPT := "res://tools/scripted_playtest.gd"

var stats := FrameStats.new()
var last_device := "nenhum"

var _last_frame_usec := 0

@onready var arena: TestArena = $Arena
@onready var player: Player = $Player
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: DebugHud = $DebugHud


func _ready() -> void:
	player.global_position = TestArena.SPAWN_POSITION
	camera_rig.set_target(player)
	hud.camera_rig = camera_rig
	hud.player = player
	hud.stats = stats
	if "--playtest" in OS.get_cmdline_user_args():
		var driver: Node = (load(PLAYTEST_SCRIPT) as GDScript).new()
		driver.set("main", self)
		add_child(driver)


func _physics_process(_delta: float) -> void:
	# Roda antes da física do jogador (pai antes dos filhos).
	player.move_yaw = camera_rig.yaw


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec != 0:
		stats.record((now - _last_frame_usec) / 1000000.0)
	_last_frame_usec = now
	hud.last_device = last_device
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_device = "teclado/mouse"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.3):
		last_device = "gamepad"
