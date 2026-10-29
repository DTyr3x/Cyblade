extends Node
## Playtest scriptado: joga o protótipo por conta própria com ENTRADA SIMULADA, mede FPS
## por trecho, mede as esquivas reais, tira capturas e grava o resultado em JSON.
##
## Executado por game/main.gd quando o jogo roda com `--playtest` (depois de `--`).
## Não substitui playtest humano: valida estabilidade, desempenho e consistência.

var main: Node

var _player: Player
var _rig: CameraRig
var _stats: FrameStats
var _out_dir := ""
var _results := {"segments": {}, "dodges": [], "shots": []}
var _dodge_started_usec := 0
var _dodge_finished_usec := 0
var _dodge_start_pos := Vector3.ZERO
var _dodge_end_pos := Vector3.ZERO
var _pending_dodge := false
var _shot_ranges: Array[Vector2i] = []

## Vigia contra travamento: uma thread confere se o laço principal segue processando quadros.
## Se ficar WATCHDOG_SECONDS sem avançar, registra onde parou (trecho e quadro) e encerra o
## processo, para o travamento virar um diagnóstico em vez de uma janela presa.
const WATCHDOG_SECONDS := 20
var _watch_thread: Thread
var _watch_stop := false
var _watch_frame := 0
var _watch_segment := "(início)"


func _ready() -> void:
	_player = main.get("player")
	_rig = main.get("camera_rig")
	_stats = main.get("stats")
	_out_dir = ProjectSettings.globalize_path("user://")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = ProjectSettings.globalize_path("res://").path_join(arg.substr(6))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_player.dodge_started.connect(_on_dodge_started)
	_player.dodge_finished.connect(_on_dodge_finished)
	_player.state_changed.connect(_on_state_changed)
	_start_watchdog()
	_run()


func _run() -> void:
	await _segment("aquecimento", 5.0, _warmup, false)
	await _segment("andar_teclado", 4.0, _walk_right)
	await _segment("circulo_teclado", 8.0, _walk_circle.bind(8.0, "circulo"))
	await _segment("esquivas", 7.0, _dodges)
	await _segment("gamepad_simulado", 5.0, _gamepad)
	await _segment("rampa_e_plataforma", 5.0, _ramp)
	await _segment("combate_katana", 14.0, _combat)
	await _segment("defesa_parry", 8.0, _defense)
	for i in 3:
		var names := ["combate", "exploracao", "chefe"]
		await _segment("camera_" + names[i], 4.0, _preset_run.bind(i, names[i]))
	_finish()


func _segment(seg_name: String, _seconds: float, body: Callable, report := true) -> void:
	_watch_segment = seg_name
	_stats.reset()
	_shot_ranges.clear()
	var t0 := Time.get_ticks_usec()
	await body.call()
	if report:
		_results["segments"][seg_name] = _segment_summary((Time.get_ticks_usec() - t0) / 1000000.0)
	print("[playtest] trecho '%s' concluído" % seg_name)


## Resume o trecho SEM os quadros afetados pela gravação de capturas (salvar PNG 1080p custa
## dezenas de ms e não é custo de jogo). Lista também os quadros acima de 25 ms que sobraram.
func _segment_summary(seconds: float) -> Dictionary:
	var kept := PackedFloat32Array()
	var hitches: Array = []
	var clock := 0.0
	for i in _stats.samples.size():
		var ft := _stats.samples[i]
		clock += ft
		var excluded := false
		for r: Vector2i in _shot_ranges:
			if i >= r.x and i <= r.y:
				excluded = true
		if excluded:
			continue
		kept.append(ft)
		if ft > 0.025:
			hitches.append({"at_s": snappedf(clock, 0.01), "ms": snappedf(ft * 1000.0, 0.1)})
	var s := FrameStats.compute(kept)
	s["seconds"] = seconds
	s["frames_excluded_for_captures"] = _stats.samples.size() - kept.size()
	s["hitches_over_25ms"] = hitches
	s.merge(_stats.render_summary())
	return s


## Visita as áreas da arena e os três enquadramentos, para compilar shaders e pipelines
## antes da medição (a primeira vez que algo aparece custa mais).
func _warmup() -> void:
	var stops := [
		[Vector3(-15, 0.05, 15), 0],
		[Vector3(20, 0.05, 6), 1],
		[Vector3(20, 4.05, -17), 2],
		[Vector3(-22, 0.05, 0), 0],
		[Vector3(8, 0.05, -10), 1],
	]
	for s: Array in stops:
		_teleport(s[0], 0.0)
		_rig.set_preset(s[1], true)
		await _wait(0.8)
	_rig.set_preset(0, true)


func _walk_right() -> void:
	_teleport(Vector3(-15, 0.05, 15), -PI / 2.0)
	await _wait(0.3)
	_move(Vector2.RIGHT)
	await _wait(3.2)
	await _shot("m1_01_andar.png")
	_move(Vector2.ZERO)
	await _wait(0.5)


func _walk_circle(seconds: float, shot_name: String) -> void:
	_teleport(Vector3(-5, 0.05, 6), 0.0)
	await _wait(0.2)
	var t := 0.0
	var shot_done := false
	while t < seconds:
		var dt := get_process_delta_time()
		t += dt
		_move(Vector2(cos(t * 1.0), sin(t * 1.0)))
		if not shot_done and t > seconds * 0.5:
			shot_done = true
			await _shot("m1_02_%s.png" % shot_name)
		await get_tree().process_frame
	_move(Vector2.ZERO)


func _dodges() -> void:
	_teleport(Vector3(-15, 0.05, 15), -PI / 2.0)
	await _wait(0.5)
	var dirs :=[Vector2.ZERO, Vector2.RIGHT, Vector2(0, -1), Vector2(-1, 1).normalized()]
	for i in dirs.size():
		_move(dirs[i])
		await _wait(0.4)
		_pending_dodge = true
		Input.action_press("dodge")
		await get_tree().create_timer(0.05).timeout
		Input.action_release("dodge")
		if i == 1:
			await _wait(0.12)
			await _shot("m1_03_esquiva.png")
		await _wait(0.8)
		_move(Vector2.ZERO)
		await _wait(0.3)
		if _player.global_position.distance_to(Vector3(-15, 0, 15)) > 14.0:
			_teleport(Vector3(-15, 0.05, 15), -PI / 2.0)
			await _wait(0.3)


func _gamepad() -> void:
	_teleport(Vector3(-15, 0.05, 8), 0.0)
	await _wait(0.3)
	var t := 0.0
	var dodged := false
	while t < 4.0:
		t += get_process_delta_time()
		var a := t * 1.2
		_pad_axis(JOY_AXIS_LEFT_X, cos(a))
		_pad_axis(JOY_AXIS_LEFT_Y, sin(a))
		if not dodged and t > 2.0:
			dodged = true
			_pad_button(JOY_BUTTON_B, true)
			_pad_button(JOY_BUTTON_B, false)
		if t > 3.0 and t < 3.05:
			_pad_axis(JOY_AXIS_RIGHT_X, 0.8)
		if t > 3.05 and t < 3.1:
			await _shot("m1_04_gamepad.png")
			_pad_axis(JOY_AXIS_RIGHT_X, 0.0)
		await get_tree().process_frame
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	_rig.reset_yaw()


func _ramp() -> void:
	_teleport(Vector3(20, 0.05, 6), 0.0)
	await _wait(0.4)
	_move(Vector2(0, -1))
	var max_y := 0.0
	var t := 0.0
	var shot_done := false
	while t < 5.5:
		t += get_process_delta_time()
		max_y = maxf(max_y, _player.global_position.y)
		if not shot_done and t > 2.2:
			shot_done = true
			await _shot("m1_05_rampa.png")
		await get_tree().process_frame
	_move(Vector2.ZERO)
	_results["ramp_max_height_m"] = max_y


## Combate: corrida até o boneco, cadeia de 3 golpes, esquiva, corrida, repetido 3 vezes.
func _combat() -> void:
	var dummy := main.get("dummy") as TrainingDummy
	var hits0 := dummy.hits.size()
	var dmg0 := dummy.total_damage
	_teleport(Vector3(0, 0.05, 7.4), 0.0)
	await _wait(0.3)
	_move(Vector2(0, -1))
	await _wait(0.55)
	var shot := false
	for round_i in 3:
		for i in 3:
			Input.action_press("attack")
			await _wait(0.05)
			Input.action_release("attack")
			await _wait(0.30)
			if round_i == 0 and i == 1 and not shot:
				shot = true
				await _shot("h2_01_combate_golpe.png")
		await _wait(0.6)
		_move(Vector2(0, 1))
		_pending_dodge = true
		Input.action_press("dodge")
		await _wait(0.05)
		Input.action_release("dodge")
		await _wait(0.3)
		_move(Vector2(0, -1))
		await _wait(0.7)
	_move(Vector2.ZERO)
	await _wait(0.5)
	_results["combate"] = {
		"acertos": dummy.hits.size() - hits0,
		"dano_total": dummy.total_damage - dmg0,
		"erros": _player.hit_detector.total_misses,
	}


## C1: diante do Instrutor, alterna parry perfeito (aperto 0,07 s antes do contato) e defesa normal.
func _defense() -> void:
	var ins := main.get("instructor") as TrainingInstructor
	ins.interval = 0.5
	_teleport(ins.global_position + Vector3(0, 0.05, 1.7), 0.0)
	var counts := {}
	for i in 4:
		while not (ins.phase == TrainingInstructor.Phase.WINDUP and ins.next_contact_time > 0.0):
			await get_tree().process_frame
		var tc := ins.next_contact_time
		var perfect := i % 2 == 0
		var press_at := tc - (0.07 if perfect else 0.3)
		while CombatClock.time < press_at:
			await get_tree().process_frame
		Input.action_press("defend")
		var n0 := ins.results.size()
		while ins.results.size() == n0:
			await get_tree().process_frame
		if i == 0:
			await _shot("c1_01_parry.png")
		Input.action_release("defend")
		var r := str(ins.results.back().get("result", -1))
		counts[r] = counts.get(r, 0) + 1
		_teleport(ins.global_position + Vector3(0, 0.05, 1.7), 0.0)
	ins.enabled = false
	_results["defesa"] = counts


func _preset_run(index: int, label: String) -> void:
	_teleport(Vector3(-5, 0.05, 6), 0.0)
	var call_start := Time.get_ticks_usec()
	_rig.set_preset(index)
	_results["preset_switch_call_ms_" + label] = (Time.get_ticks_usec() - call_start) / 1000.0
	await _wait(0.2)
	var t := 0.0
	while t < 3.4:
		t += get_process_delta_time()
		_move(Vector2(cos(t * 0.8), sin(t * 0.8)))
		await get_tree().process_frame
	_move(Vector2.ZERO)
	await _wait(0.4)
	await _shot("m1_06_camera_%s.png" % label)
	_results["player_screen_height_pct_" + label] = (main.get("hud") as DebugHud).player_screen_height_percent()
	_rig.set_preset(0, true)


func _finish() -> void:
	_watch_stop = true
	_watch_thread.wait_to_finish()
	_results["godot"] = Engine.get_version_info()["string"]
	_results["renderer"] = RenderingServer.get_current_rendering_method()
	_results["driver"] = RenderingServer.get_current_rendering_driver_name()
	_results["gpu"] = RenderingServer.get_video_adapter_name()
	_results["window"] = [get_window().size.x, get_window().size.y]
	_results["vsync_mode"] = DisplayServer.window_get_vsync_mode()
	_results["physics_ticks"] = Engine.physics_ticks_per_second
	_results["input"] = "simulada por script (teclado e gamepad), não é humano"
	var f := FileAccess.open(_out_dir.path_join("m1_playtest_resultados.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_results, "\t"))
	f.close()
	print("[playtest] resultados em ", _out_dir)
	get_tree().quit()


# --- utilidades -----------------------------------------------------------------

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _teleport(pos: Vector3, facing_yaw: float) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = facing_yaw
	_player.reset_physics_interpolation()
	_rig.yaw = 0.0
	_rig.snap()


func _move(v: Vector2) -> void:
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_up", maxf(-v.y, 0.0))
	_set_action("move_down", maxf(v.y, 0.0))


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _shot(file_name: String) -> void:
	var first := _stats.samples.size()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out_dir.path_join(file_name))
	_results["shots"].append(file_name)
	_shot_ranges.append(Vector2i(first - 1, _stats.samples.size() + 3))


func _on_dodge_started(_dir: Vector3) -> void:
	_dodge_started_usec = Time.get_ticks_usec()
	_dodge_start_pos = _player.global_position


func _on_dodge_finished() -> void:
	_dodge_finished_usec = Time.get_ticks_usec()
	_dodge_end_pos = _player.global_position


func _on_state_changed(new_state: int) -> void:
	if new_state == Player.State.MOVE and _pending_dodge and _dodge_started_usec > 0:
		_pending_dodge = false
		(_results["dodges"] as Array).append({
			"distance_m": snappedf(_dodge_start_pos.distance_to(_dodge_end_pos), 0.01),
			"dodge_s": snappedf((_dodge_finished_usec - _dodge_started_usec) / 1000000.0, 0.001),
			"total_s": snappedf((Time.get_ticks_usec() - _dodge_started_usec) / 1000000.0, 0.001),
		})


func _process(_delta: float) -> void:
	_watch_frame = Engine.get_frames_drawn()


func _start_watchdog() -> void:
	_watch_thread = Thread.new()
	_watch_thread.start(_watch_loop)


func _watch_loop() -> void:
	var last := -1
	var still := 0.0
	while not _watch_stop:
		OS.delay_msec(500)
		if _watch_frame != last:
			last = _watch_frame
			still = 0.0
			continue
		still += 0.5
		if still >= WATCHDOG_SECONDS:
			print("[playtest] TRAVAMENTO: nenhum quadro há %d s (trecho '%s', quadro %d)" % [WATCHDOG_SECONDS, _watch_segment, last])
			OS.kill(OS.get_process_id())
