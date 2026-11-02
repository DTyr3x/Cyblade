extends SceneTree
## Joga o confronto com o DuelBot: serve para o vídeo, para o smoke test em janela e para medir desempenho.
##   godot --path . --rendering-driver vulkan --windowed --resolution 1920x1080 -s res://tools/duel_demo.gd -- --style=parry --report=docs/vs/smoke.json
##   godot --path . --rendering-driver vulkan --write-movie saida.avi --fixed-fps 60 --resolution 1280x720 -s res://tools/duel_demo.gd
const LIMIT := 150.0

var _style := "parry"
var _skill := 0.85
var _seed := 11
var _report := ""
var _shots := ""
var _restart := false
var _taken := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--style="):
			_style = a.substr(8)
		elif a.begins_with("--skill="):
			_skill = float(a.substr(8))
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a.begins_with("--report="):
			_report = a.substr(9)
		elif a.begins_with("--shots="):
			_shots = a.substr(8)
		elif a == "--restart":
			_restart = true
	_run()


func _run() -> void:
	var duel: Node = (load("res://game/duel.tscn") as PackedScene).instantiate()
	root.add_child(duel)
	current_scene = duel
	for i in 10:
		await process_frame
	duel.set("save_best", false)
	var robot: RobotEnemy = duel.get("robot")
	robot.rng_seed = _seed
	robot._rng.seed = _seed
	var bot := DuelBot.new()
	bot.style = _style
	bot.skill = _skill
	bot.duel = duel
	bot.player = duel.get("player")
	bot.robot = robot
	root.add_child(bot)
	await _wait(1.5)
	await _shot("1_inicio")
	duel.call("start_fight")
	if _shots != "":
		_watch(robot)
	var t0 := CombatClock.time
	var stats: FrameStats = duel.get("stats")
	stats.reset()
	while duel.get("flow") == 1 and CombatClock.time - t0 < LIMIT:
		await process_frame
	var flow: int = duel.get("flow")
	var summary := {
		"resultado": ["INTRO", "EM LUTA", "VITORIA", "DERROTA"][flow], "estilo": _style, "tempo_s": CombatClock.time - t0,
		"parries": duel.get("parries"), "esquivas_justas": duel.get("evades"), "dano_recebido": duel.get("damage_taken"),
		"quebras": robot.posture.breaks, "cravadas": robot.posture.finishes, "vida_robo": robot.health,
		"vida_jogador": bot.player.vitals.health, "padroes": robot.pattern_counts, "golpes": bot.strikes_pressed,
		"quadros": stats.recent(100000),
	}
	print("[duel] ", JSON.stringify(summary))
	await _wait(3.0)
	await _shot("9_fim")
	if _report != "":
		var path := ProjectSettings.globalize_path("res://").path_join(_report)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	if _restart:
		Input.action_press("confirm")
		await process_frame
		await process_frame
		Input.action_release("confirm")
		for i in 90:
			await process_frame
	quit(0 if flow == 2 or flow == 3 else 1)


## Capturas dos momentos que importam, para conferir a leitura de cima (só com janela).
func _watch(robot: RobotEnemy) -> void:
	robot.phase_changed.connect(func(p: int) -> void:
		if p == TrainingInstructor.Phase.WINDUP:
			_later("2_preparacao_" + String(robot.attack.display_name).to_snake_case().replace(" ", "_"), 0.4))
	robot.posture.broken.connect(func(_precise: bool) -> void: _later("4_quebra", 0.3))
	robot.posture.pressure_applied.connect(func(e: Dictionary) -> void:
		if float(e["current"]) > 70.0:
			_later("3_pressao_alta", 0.05))
	robot.posture.finished.connect(func() -> void: _later("5_cravada", 0.02))


func _later(name: String, delay: float) -> void:
	if _taken.has(name):
		return
	_taken[name] = true
	await _wait(delay)
	await _shot(name)


func _shot(name: String) -> void:
	if _shots == "":
		return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://").path_join(_shots)
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _wait(seconds: float) -> void:
	var t := CombatClock.time
	while CombatClock.time < t + seconds:
		await process_frame
