extends SceneTree
## Folhas de contato do COMBATE (janela real, entrada simulada por script): corrida -> 3 golpes ->
## esquiva -> corrida, e cada golpe isolado em câmera lateral. Evidência visual; não mede sensação.
##   godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/combat_sheet.gd -- --out=docs/h2/capturas
const TILE := Vector2i(540, 400)
var _main: Node
var _player: Player
var _cam: Camera3D
var _out := "res://docs/h2/capturas"
var _lookat := Vector3.ZERO


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
	_save(await _seq_full(), "h2_01_corrida_tres_golpes_esquiva_corrida.png")
	_save(await _seq_single(0), "h2_02_golpe1_corte_diagonal.png")
	_save(await _seq_single(1), "h2_03_golpe2_corte_reverso.png")
	_save(await _seq_single(2), "h2_04_golpe3_golpe_final.png")
	print("[combat_sheet] ok")
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
	_player.reset_physics_interpolation()


func _follow() -> void:
	var p := _player.global_position
	var mid := p + Vector3(0, 0, -0.6)
	_cam.global_position = mid + Vector3(5.2, 1.4, 0)
	_cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


## Captura `count` quadros, um a cada `step` ticks; `events` = {tick: Callable} executados na hora.
func _capture(total_ticks: int, step: int, events: Dictionary) -> Array:
	var tiles: Array = []
	for t in total_ticks:
		await physics_frame
		if events.has(t):
			(events[t] as Callable).call()
		_follow()
		if t % step == 0:
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var cx := img.get_width() / 2
			var cy := int(img.get_height() * 0.52)
			var crop := img.get_region(Rect2i(cx - TILE.x / 2, cy - TILE.y / 2, TILE.x, TILE.y))
			tiles.append({"img": crop})
	return tiles


func _reset_dummy_and_player(start: Vector3) -> void:
	_place(start, 0.0)
	await _ticks(30)


func _seq_full() -> Array:
	await _reset_dummy_and_player(Vector3(0, 0.05, 10.5))
	Input.action_press("move_up")
	var ev := {}
	# Corre ~0,55 s, bate 3 vezes (apertos em sequência, o buffer encadeia), esquiva, volta a correr.
	ev[66] = func(): Input.action_press("attack")
	ev[68] = func(): Input.action_release("attack")
	ev[100] = func(): Input.action_press("attack")
	ev[102] = func(): Input.action_release("attack")
	ev[132] = func(): Input.action_press("attack")
	ev[134] = func(): Input.action_release("attack")
	ev[196] = func(): Input.action_release("move_up"); Input.action_press("move_down"); Input.action_press("dodge")
	ev[199] = func(): Input.action_release("dodge")
	ev[232] = func(): Input.action_release("move_down"); Input.action_press("move_up")
	var tiles := await _capture(300, 7, ev)
	Input.action_release("move_up")
	return tiles


func _seq_single(index: int) -> Array:
	await _reset_dummy_and_player(Vector3(0, 0.05, 6.0))
	# Chega perto, executa os golpes anteriores sem captura, e captura só o golpe pedido.
	_player.global_position = Vector3(0, 0.05, 5.2)
	var ev := {}
	var presses := [0, 22, 46]
	for i in index + 1:
		var at: int = presses[i]
		ev[at] = func(): Input.action_press("attack")
		ev[at + 2] = func(): Input.action_release("attack")
	return await _capture(80 if index < 2 else 95, 3, ev)


func _save(tiles: Array, file_name: String) -> void:
	var cols := 4
	var rows := ceili(tiles.size() / float(cols))
	var sheet := Image.create(cols * TILE.x, rows * TILE.y, false, Image.FORMAT_RGB8)
	sheet.fill(Color.BLACK)
	for i in tiles.size():
		var img: Image = tiles[i]["img"]
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, TILE.x, TILE.y), Vector2i((i % cols) * TILE.x, (i / cols) * TILE.y))
	var path := ProjectSettings.globalize_path(_out).path_join(file_name)
	sheet.save_png(path)
	print("[combat_sheet] ", path)
