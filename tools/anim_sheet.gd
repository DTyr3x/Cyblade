extends SceneTree
## Gera folhas de contato (sequências de capturas reais, câmera lateral próxima) da locomoção
## do humanoide com ENTRADA SIMULADA. Evidência visual para o PO; não mede sensação de jogo.
##
## Uso: tools\anim_sheet.ps1  (janela real; precisa de GPU)
##   godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/anim_sheet.gd -- --out=docs/h1/capturas

const DT := 1.0 / 120.0
const TILE := Vector2i(360, 420)

var _main: Node
var _player: Player
var _cam: Camera3D
var _out := "res://docs/h1/capturas"
var _side := Vector3(0, 0, 1)   # direção da câmera relativa ao jogador (lado)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = "res://" + a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_run()


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _ticks(10)
	_player = _main.get_node("Player") as Player
	(_main.get_node("DebugHud") as CanvasLayer).visible = false
	_cam = Camera3D.new()
	_cam.fov = 38.0
	root.add_child(_cam)
	_cam.make_current()
	_main.get_node("CameraRig").set_process(false)

	var sheets := {}
	sheets["01_idle_andar_correr_parar"] = await _seq_loco()
	sheets["02_giro_90_e_180"] = await _seq_turns()
	sheets["03_esquiva_correndo"] = await _seq_dodge(Vector2.RIGHT)
	sheets["04_esquiva_parado"] = await _seq_dodge(Vector2.ZERO)
	sheets["05_andar_analogico"] = await _seq_walk()
	for k: String in sheets:
		_save_sheet(sheets[k], "h1_%s.png" % k)
	print("[anim_sheet] ok")
	quit()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _place(pos: Vector3, yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	_player.state = Player.State.MOVE
	_player.state_time = 0.0


func _follow_cam() -> void:
	var p := _player.global_position
	_cam.global_position = p + Vector3(0, 1.0, 0) + _side * 5.2
	_cam.look_at(p + Vector3(0, 0.95, 0), Vector3.UP)


## Captura `count` quadros, um a cada `step` ticks de física, chamando `tick` a cada tick.
func _capture(count: int, step: int, label_fn: Callable) -> Array:
	var tiles: Array = []
	for i in count:
		for s in step:
			await physics_frame
			_follow_cam()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var cx := img.get_width() / 2
		var cy := int(img.get_height() * 0.5)
		var crop := img.get_region(Rect2i(cx - TILE.x / 2, cy - TILE.y / 2, TILE.x, TILE.y))
		tiles.append({"img": crop, "label": label_fn.call()})
	return tiles


func _hud_label() -> String:
	var states := ["MOVE", "DODGE", "RECOV"]
	return "%s v=%.1f" % [states[_player.state], _player.horizontal_velocity().length()]


func _seq_loco() -> Array:
	_side = Vector3(0, 0, 1)
	_place(Vector3(-20, 0.05, 15), -PI / 2.0 * -1.0)
	_player.rotation.y = -PI / 2.0   # frente = +X
	await _ticks(60)
	var tiles: Array = []
	tiles.append_array(await _capture(2, 24, _hud_label))
	Input.action_press("move_right")
	tiles.append_array(await _capture(6, 4, _hud_label))
	tiles.append_array(await _capture(6, 7, _hud_label))
	Input.action_release("move_right")
	tiles.append_array(await _capture(4, 4, _hud_label))
	return tiles


## Andar com o stick analógico (~1,5 m/s e ~3 m/s): mistura Idle, Walk e Jog.
func _seq_walk() -> Array:
	_side = Vector3(0, 0, 1)
	_place(Vector3(-20, 0.05, 15), -PI / 2.0)
	await _ticks(60)
	var tiles: Array = []
	Input.action_press("move_right", 0.4)
	await _ticks(40)
	tiles.append_array(await _capture(6, 10, _hud_label))
	Input.action_press("move_right", 0.65)
	await _ticks(40)
	tiles.append_array(await _capture(6, 6, _hud_label))
	Input.action_release("move_right")
	await _ticks(30)
	return tiles


func _seq_turns() -> Array:
	_side = Vector3(0, 0, 1)
	_place(Vector3(-20, 0.05, 15), 0.0)
	_player.rotation.y = -PI / 2.0
	Input.action_press("move_right")
	await _ticks(120)
	var tiles: Array = []
	tiles.append_array(await _capture(2, 8, _hud_label))
	Input.action_release("move_right")
	Input.action_press("move_up")  # 90°: de +X para -Z
	tiles.append_array(await _capture(6, 4, _hud_label))
	Input.action_release("move_up")
	Input.action_press("move_left")  # 180° em relação a +X
	await _ticks(60)
	tiles.append_array(await _capture(6, 4, _hud_label))
	Input.action_release("move_left")
	await _ticks(60)
	return tiles


func _seq_dodge(dir: Vector2) -> Array:
	_side = Vector3(0, 0, 1)
	_place(Vector3(-20, 0.05, 15), -PI / 2.0)
	if dir != Vector2.ZERO:
		Input.action_press("move_right")
	await _ticks(120)
	var tiles: Array = []
	tiles.append_array(await _capture(2, 6, _hud_label))
	Input.action_press("dodge")
	await physics_frame
	Input.action_release("dodge")
	tiles.append_array(await _capture(10, 3, _hud_label))
	tiles.append_array(await _capture(4, 6, _hud_label))
	Input.action_release("move_right")
	await _ticks(60)
	return tiles


func _save_sheet(tiles: Array, file_name: String) -> void:
	var cols := 6
	var rows := ceili(tiles.size() / float(cols))
	var sheet := Image.create(cols * TILE.x, rows * TILE.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color.BLACK)
	for i in tiles.size():
		var img: Image = tiles[i]["img"]
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, TILE.x, TILE.y), Vector2i((i % cols) * TILE.x, (i / cols) * TILE.y))
	var path := ProjectSettings.globalize_path(_out).path_join(file_name)
	sheet.save_png(path)
	print("[anim_sheet] ", path)
