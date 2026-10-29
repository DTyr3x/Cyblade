extends SceneTree
## Demonstração em vídeo REAL do combate (gameplay renderizado quadro a quadro pelo Movie Maker do
## Godot, entrada simulada por script): corrida → Kesa → Kiriage → Tsuki → esquiva → corrida.
##   godot --path . --rendering-driver vulkan --write-movie <saida.avi> --fixed-fps 60 --resolution 960x540 \
##         -s res://tools/video_demo.gd -- --cam=lado   (ou --cam=jogo, a câmera alta do jogo)
const TICKS_PER_SECOND := 120

var _main: Node
var _player: Player
var _cam: Camera3D
var _mode := "lado"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			_mode = a.substr(6)
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await _ticks(2)
	Input.action_release(action)


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _ticks(10)
	_player = _main.get_node("Player") as Player
	var rig := _main.get_node("CameraRig") as CameraRig
	(_main.get_node("DebugHud") as CanvasLayer).visible = false
	if _mode == "lado":
		rig.set_process(false)
		_cam = Camera3D.new()
		_cam.fov = 38.0
		root.add_child(_cam)
		_cam.make_current()
	_player.global_position = Vector3(0, 0.05, 8.2)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	rig.snap()
	var follow := func() -> void:
		if _mode == "lado":
			var p := _player.global_position
			var mid := p + Vector3(0, 0, -0.9)
			_cam.global_position = mid + Vector3(5.0, 1.5, 0)
			_cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)
	# Linha do tempo em ticks de física (120 por segundo).
	var events := {
		24: func(): Input.action_press("move_up"),
		90: func(): _tap("attack"),            # Kesa
		96: func(): _tap("attack"),            # Kiriage (buffer; entra quando a janela abre)
		136: func(): _tap("attack"),           # Tsuki
		330: func(): Input.action_release("move_up"); Input.action_press("move_down"); _tap("dodge"),
		420: func(): Input.action_release("move_down"); Input.action_press("move_up"),
		560: func(): Input.action_release("move_up"),
	}
	var total := 640
	for t in total:
		await physics_frame
		follow.call()
		if events.has(t):
			(events[t] as Callable).call()
	await _ticks(10)
	quit()
