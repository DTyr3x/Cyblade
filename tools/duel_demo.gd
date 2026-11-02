extends SceneTree
## Joga o confronto com o DuelBot: serve para o vídeo, para o smoke test em janela e para medir desempenho.
##   godot --path . --rendering-driver vulkan --windowed --resolution 1920x1080 -s res://tools/duel_demo.gd -- --style=parry --report=docs/vs/smoke.json
##   godot --path . --rendering-driver vulkan --write-movie saida.avi --fixed-fps 60 --resolution 1280x720 -s res://tools/duel_demo.gd
const LIMIT := 150.0

var _style := "parry"
var _skill := 0.85
var _seed := 11
var _report := ""


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
	_run()


func _run() -> void:
	var duel: Node = (load("res://game/duel.tscn") as PackedScene).instantiate()
	root.add_child(duel)
	current_scene = duel
	for i in 10:
		await process_frame
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
	duel.call("start_fight")
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
	if _report != "":
		var path := ProjectSettings.globalize_path("res://").path_join(_report)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	quit(0 if flow == 2 or flow == 3 else 1)


func _wait(seconds: float) -> void:
	var t := CombatClock.time
	while CombatClock.time < t + seconds:
		await process_frame
