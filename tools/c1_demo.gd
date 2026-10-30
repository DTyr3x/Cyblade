extends SceneTree
## Demonstração do C1 no jogo real (entrada simulada): o Instrutor ataca e o jogador (1) não defende,
## (2) defende segurando a guarda, (3) faz parry perfeito e contra-ataca o Instrutor desequilibrado.
## Com --sheet=<pasta> grava folhas de contato de cada cenário; com --write-movie do Godot vira vídeo.
##   godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/c1_demo.gd -- --cam=lado --sheet=docs/c1/capturas
##   godot --path . --rendering-driver vulkan --write-movie saida.avi --fixed-fps 60 --resolution 960x540 -s res://tools/c1_demo.gd -- --cam=jogo
const TILE := Vector2i(540, 400)

var _main: Node
var _player: Player
var _ins: TrainingInstructor
var _rig: CameraRig
var _cam: Camera3D
var _mode := "lado"
var _sheet_dir := ""
var _only_c11 := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam="):
			_mode = a.substr(6)
		elif a.begins_with("--sheet="):
			_sheet_dir = "res://" + a.substr(8)
		elif a == "--c11":
			_only_c11 = true
	if _sheet_dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_sheet_dir))
	_run()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
		_follow()


func _follow() -> void:
	if _mode != "lado" or _cam == null:
		return
	var mid := (_player.global_position + _ins.global_position) * 0.5
	_cam.global_position = mid + Vector3(4.6, 1.5, 0.0)
	_cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(10)
	_player = _main.get("player")
	_ins = _main.get("instructor")
	_rig = _main.get("camera_rig")
	(_main.get_node("DebugHud") as CanvasLayer).visible = _mode == "jogo"
	_ins.interval = 0.6
	if _mode == "lado":
		_rig.set_process(false)
		_cam = Camera3D.new()
		_cam.fov = 40.0
		var fill := OmniLight3D.new()
		fill.light_energy = 3.0
		fill.omni_range = 14.0
		_cam.add_child(fill)
		root.add_child(_cam)
		_cam.make_current()
	_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	_rig.snap()
	await _frames(20)
	if _only_c11:
		await _scenario("c11_01_parry_deflexao_contra_ataque", -0.07, false, "counter")
		await _scenario("c11_02_parry_esquiva_corrida", -0.07, false, "dodge")
	else:
		await _scenario("c1_01_sem_defesa", 99.0, false)
		await _scenario("c1_02_defesa_normal", -0.30, true)
		await _scenario("c1_03_parry_perfeito", -0.07, false)
	await _frames(30)
	print("[c1_demo] ok")
	quit()


## Espera a próxima preparação e aperta K em (contato + offset). offset 99 = não defende.
## `counter`: depois do parry, ataca o Instrutor desequilibrado (Kesa → Kiriage).
func _scenario(name: String, offset: float, hold: bool, kind := "") -> void:
	while not (_ins.phase == TrainingInstructor.Phase.WINDUP and _ins.next_contact_time > 0.0):
		await _frames(1)
	var tc := _ins.next_contact_time
	var tiles: Array = []
	var start := tc - 0.40
	while CombatClock.time < start:
		await _frames(1)
	var pressed := false
	var released := false
	var frame := 0
	var attacked := 0
	while CombatClock.time < tc + (1.3 if kind != "" else 0.75):
		if not pressed and offset < 50.0 and CombatClock.time >= tc + offset:
			_key(KEY_K, true)
			pressed = true
		elif pressed and not released and (not hold or CombatClock.time >= tc + 0.35):
			_key(KEY_K, false)
			released = true
		if kind == "counter" and attacked < 1 and CombatClock.time >= tc + 0.16:
			_key(KEY_J, true)
			await _frames(1)
			_key(KEY_J, false)
			attacked += 1
		if kind == "dodge" and attacked < 1 and CombatClock.time >= tc + 0.16:
			_key(KEY_S, true)
			_key(KEY_SPACE, true)
			await _frames(1)
			_key(KEY_SPACE, false)
			attacked += 1
		await _frames(1)
		frame += 1
		if _sheet_dir != "" and frame % 3 == 0:
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var c := Vector2i(img.get_width() / 2, int(img.get_height() * 0.55))
			if _mode == "jogo":
				var p := _rig.camera.unproject_position((_player.global_position + _ins.global_position) * 0.5 + Vector3(0, 0.9, 0))
				p *= float(img.get_width()) / root.get_visible_rect().size.x
				c = Vector2i(int(p.x), int(p.y))
				var crop := img.get_region(Rect2i(c.x - 135, c.y - 100, 270, 200))
				crop.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
				tiles.append(crop)
			else:
				tiles.append(img.get_region(Rect2i(c.x - TILE.x / 2, c.y - TILE.y / 2, TILE.x, TILE.y)))
	_key(KEY_K, false)
	_key(KEY_S, false)
	if _sheet_dir != "":
		_save(tiles, "%s_%s.png" % [name, _mode])
	await _frames(40)
	_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.reset_physics_interpolation()
	await _frames(20)


func _save(tiles: Array, file_name: String) -> void:
	var cols := 5
	var rows := ceili(tiles.size() / float(cols))
	var sheet := Image.create(cols * TILE.x, rows * TILE.y, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		var img: Image = tiles[i]
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(img, Rect2i(0, 0, TILE.x, TILE.y), Vector2i((i % cols) * TILE.x, (i / cols) * TILE.y))
	sheet.save_png(ProjectSettings.globalize_path(_sheet_dir).path_join(file_name))
	print("[c1_demo] ", file_name)
