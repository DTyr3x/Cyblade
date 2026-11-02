extends SceneTree
## Evidência do C2.0 no jogo real (entrada simulada, Instrutor real): pressão temporária, parry e contra-corte
## cravando, recuperação parando no piso, teto de 80% e os últimos 20% só com golpes que acertam.
## Grava a curva em CSV, capturas com o HUD F3 e, com --write-movie do Godot, vídeo.
##   godot --headless --path . --fixed-fps 120 -s res://tools/c20_demo.gd -- --csv=docs/c2-0/pressao.csv
##   godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/c20_demo.gd -- --shots=docs/c2-0/capturas
##   godot --path . --rendering-driver vulkan --write-movie saida.avi --fixed-fps 60 --resolution 960x540 -s res://tools/c20_demo.gd

var _main: Node
var _player: Player
var _ins: TrainingInstructor
var _p: PostureController
var _csv: PackedStringArray = ["t_s,atual,cravada,evento"]
var _events: PackedStringArray = []
var _csv_path := ""
var _note := ""
var _shots_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--csv="):
			_csv_path = "res://" + a.substr(6)
		elif a.begins_with("--shots="):
			_shots_dir = "res://" + a.substr(8)
	_run()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frame() -> void:
	await process_frame
	_p.update(CombatClock.time)
	_csv.append("%.3f,%.2f,%.2f,%s" % [CombatClock.time, _p.current, _p.locked, _note])
	_note = ""


func _wait(seconds: float) -> void:
	var t := CombatClock.time
	while CombatClock.time < t + seconds:
		await _frame()


func _log(text: String) -> void:
	_note = text
	var line := "%6.2f s  atual %5.1f  cravada %5.1f  %s" % [CombatClock.time, _p.current, _p.locked, text]
	_events.append(line)
	print("[c20] ", line)


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for i in 10:
		await process_frame
	_player = _main.get("player")
	_ins = _main.get("instructor")
	_p = _ins.posture
	_p.pressure_applied.connect(func(e: Dictionary) -> void:
		_log("+%.1f de %s" % [float(e["gain"]), ["golpe", "parry", "esquiva"][int(e["source"])]]))
	_p.full_reached.connect(func() -> void: _log("postura cheia (sem quebra no C2.0)"))
	_ins.interval = 0.6
	_ins.enabled = false
	await _place()
	await _wait(0.8)

	_log("A. cadeia sem precisão")
	await _chain(3)
	await _shot("c20_01_pressao_temporaria")
	await _idle()
	await _wait(2.2)
	await _shot("c20_02_sem_cravar_zerou")
	_log("sem cravar, a pressão some")

	_log("B. parry, contra-corte e golpes")
	_ins.enabled = true
	await _parry()
	await _wait(0.1)
	await _attack()
	await _end_of_strike()
	_ins.enabled = false
	await _wait(0.7)
	await _chain(2)
	await _idle()
	await _wait(1.7)
	await _shot("c20_03_piso_cravado")
	_log("recuperação parou no piso")

	_log("C. parries até o teto de 80%")
	_ins.enabled = true
	for i in 3:
		await _parry()
	_ins.enabled = false
	await _wait(0.4)
	await _shot("c20_04_teto_80")

	_log("D. últimos 20% só com golpes que acertam")
	await _wait(0.5)
	await _chain(6)
	await _shot("c20_05_cheia_sem_quebra")
	await _idle()
	await _wait(3.0)
	_log("sem novos golpes, voltou ao piso de 80")
	await _wait(5.2)
	_log("8 s sem pressão: confronto acabou, piso zerado")
	await _wait(4.0)
	_log("fim")
	if _csv_path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_csv_path.get_base_dir()))
		var f := FileAccess.open(_csv_path, FileAccess.WRITE)
		f.store_string("\n".join(_csv) + "\n")
		f.close()
		var g := FileAccess.open(_csv_path.get_basename() + "_eventos.txt", FileAccess.WRITE)
		g.store_string("\n".join(_events) + "\n")
		g.close()
	print("[c20] ok")
	quit()


## Captura com o HUD F3 (só com janela; no modo headless não há imagem).
func _shot(file_name: String) -> void:
	if _shots_dir == "":
		return
	await _wait(0.15)   # o HUD atualiza a cada 0,1 s
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_shots_dir).path_join(file_name + ".png"))


func _place() -> void:
	_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_player.reset_physics_interpolation()
	(_main.get("camera_rig") as CameraRig).snap()
	await _frame()


func _attack() -> void:
	var n := _ins.hits.size()
	_key(KEY_J, true)
	await _frame()
	_key(KEY_J, false)
	var t := CombatClock.time
	while _ins.hits.size() == n and CombatClock.time < t + 0.6:
		await _frame()


func _chain(count: int) -> void:
	var c := _player.combat
	for i in count:
		await _attack()
		if i < count - 1:
			while c.is_attacking() and c.clip_time() < c.current.chain_open:
				await _frame()


func _end_of_strike() -> void:
	while _player.combat.is_attacking():
		await _frame()


func _idle() -> void:
	await _end_of_strike()


func _parry() -> void:
	while not (_ins.phase == TrainingInstructor.Phase.WINDUP and _ins.next_contact_time > 0.0):
		await _frame()
	await _place()
	var tc := _ins.next_contact_time
	while CombatClock.time < tc - 0.07:
		await _frame()
	_key(KEY_K, true)
	await _frame()
	_key(KEY_K, false)
	while CombatClock.time < tc + 0.05:
		await _frame()
