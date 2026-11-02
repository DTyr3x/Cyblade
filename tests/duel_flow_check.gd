extends SceneTree
## Sequência completa do confronto, com o jogo real e entrada simulada: robô, vitória por Cravada, derrota,
## reinício e treino. Roda no FPS pedido (tools\run_duel_checks.ps1 repete em 30, 60 e 144).
##   godot --headless --path . --fixed-fps 60 -s res://tests/duel_flow_check.gd
var _passed := 0
var _failed := 0
var _bot: DuelBot


func _initialize() -> void:
	_run()


func _check(ok: bool, name: String, detail := "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("  %s  %s%s" % ["PASS" if ok else "FAIL", name, ("  (" + detail + ")") if detail != "" else ""])


func _wait(seconds: float) -> void:
	var t := CombatClock.time
	while CombatClock.time < t + seconds:
		await process_frame


func _wait_for(cond: Callable, limit: float) -> bool:
	var t := CombatClock.time
	while CombatClock.time < t + limit:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _open_duel() -> Node:
	var duel: Node = (load("res://game/duel.tscn") as PackedScene).instantiate()
	root.add_child(duel)
	current_scene = duel
	for i in 10:
		await process_frame
	return duel


func _close(duel: Node) -> void:
	if _bot != null:
		_bot.queue_free()
		_bot = null
	duel.queue_free()
	await process_frame
	await process_frame


func _attach_bot(duel: Node, style: String, skill: float) -> void:
	_bot = DuelBot.new()
	_bot.style = style
	_bot.skill = skill
	_bot.duel = duel
	_bot.player = duel.get("player")
	_bot.robot = duel.get("robot")
	root.add_child(_bot)


func _run() -> void:
	print("== CYBLADE · sequência do confronto ==")
	await _test_intro_and_robot()
	await _test_victory()
	await _test_defeat()
	await _test_restart()
	print("== confronto: %d ok, %d falha(s) ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_intro_and_robot() -> void:
	var duel: Node = await _open_duel()
	var robot: RobotEnemy = duel.get("robot")
	var player: Player = duel.get("player")
	var hud: DuelHud = duel.get("duel_hud")
	_check(hud.message() == "CYBLADE" and duel.get("flow") == 0, "abre na tela inicial")
	_check(not player.vitals.training and player.vitals.regen_rate == 0.0, "no confronto a vida do jogador é de verdade")
	var start := robot.global_position
	await _wait(0.6)
	_check(robot.global_position.distance_to(start) < 0.01 and robot.phase == TrainingInstructor.Phase.WAIT, "antes de começar o robô espera")
	duel.call("start_fight")
	_check(hud.message() == "", "Enter tira a tela inicial")
	var d0 := player.global_position.distance_to(robot.global_position)
	await _wait(1.2)
	_check(robot.engaged and player.global_position.distance_to(robot.global_position) < d0 - 3.0, "detecta o jogador e se aproxima", "%.1f → %.1f m" % [d0, player.global_position.distance_to(robot.global_position)])
	# Longe, ele usa a investida, com a faixa no chão antes do contato.
	await _wait_for(func(): return robot.phase == TrainingInstructor.Phase.WINDUP, 4.0)
	var first := robot.attack
	_check(first.advance_distance > 0.0, "de longe usa a Investida", first.display_name)
	_check(robot._telegraph.visible and robot._telegraph.mesh == robot._lane_mesh, "a Investida mostra a faixa no chão durante a preparação")
	var before := robot.global_position
	await _wait_for(func(): return robot.phase == TrainingInstructor.Phase.RECOVERY or player.state == Player.State.STAGGER, 1.5)
	_check(robot.global_position.distance_to(before) > 1.5, "a Investida avança de verdade", "%.1f m" % robot.global_position.distance_to(before))
	_check(player.vitals.health < player.vitals.max_health, "golpe do robô tira vida de verdade")
	await _wait(0.4)
	# Perto, mantém distância e alterna cortes e varredura.
	var seen := {}
	var too_near := false
	var t := CombatClock.time
	while CombatClock.time < t + 22.0 and seen.size() < 2:
		if robot.phase == TrainingInstructor.Phase.WINDUP:
			seen[robot.attack.parryable] = true
		player.vitals.health = player.vitals.max_health
		await process_frame
	_check(seen.has(true) and seen.has(false), "alterna golpes defensáveis e a Varredura vermelha")
	var dist := player.global_position.distance_to(robot.global_position)
	_check(dist > 1.0 and dist < 4.0 and not too_near, "mantém distância de combate", "%.1f m" % dist)
	await _close(duel)


func _test_victory() -> void:
	var duel: Node = await _open_duel()
	var robot: RobotEnemy = duel.get("robot")
	var player: Player = duel.get("player")
	var hud: DuelHud = duel.get("duel_hud")
	robot._rng.seed = 11
	_attach_bot(duel, "parry", 0.9)
	duel.call("start_fight")
	var ok := await _wait_for(func(): return duel.get("flow") != 1, 150.0)
	_check(ok and duel.get("flow") == 2, "parry, contra-corte e cadeia: vitória", "%.1f s, %d quebras, %d Cravadas" % [duel.get("fight_time"), robot.posture.breaks, robot.posture.finishes])
	_check(robot.dead and robot.health == 0.0 and robot.posture.finishes >= 2, "o robô só cai numa Cravada")
	_check(duel.get("parries") >= 1 and robot.pattern_counts.size() >= 2, "a luta usou parry e pelo menos dois padrões", str(robot.pattern_counts))
	_check(hud.message() == "VITÓRIA", "tela de vitória")
	var hp := player.vitals.health
	await _wait(1.0)
	_check(robot.dead and not robot.enabled and player.vitals.health == hp, "depois da vitória o robô não age")
	await _close(duel)

	duel = await _open_duel()
	robot = duel.get("robot")
	robot._rng.seed = 21
	_attach_bot(duel, "esquiva", 0.9)
	duel.call("start_fight")
	ok = await _wait_for(func(): return duel.get("flow") != 1, 150.0)
	_check(ok and duel.get("flow") == 2 and duel.get("parries") == 0 and duel.get("evades") >= 2, "esquiva e cadeia, sem nenhum parry: vitória", "%.1f s, %d esquivas justas" % [duel.get("fight_time"), duel.get("evades")])
	await _close(duel)


func _test_defeat() -> void:
	var duel: Node = await _open_duel()
	var robot: RobotEnemy = duel.get("robot")
	var player: Player = duel.get("player")
	var hud: DuelHud = duel.get("duel_hud")
	_attach_bot(duel, "passivo", 1.0)
	duel.call("start_fight")
	var ok := await _wait_for(func(): return duel.get("flow") != 1, 90.0)
	_check(ok and duel.get("flow") == 3 and player.state == Player.State.DOWN and player.vitals.health <= 0.0, "sem reagir: derrota", "%.1f s" % duel.get("fight_time"))
	_check(hud.message() == "DERROTA" and not robot.enabled, "tela de derrota e o robô para")
	await _wait(0.5)
	_check(player.state == Player.State.DOWN, "derrotado, o jogador não volta sozinho")
	await _close(duel)


func _test_restart() -> void:
	var duel: Node = await _open_duel()
	var robot: RobotEnemy = duel.get("robot")
	duel.call("start_fight")
	robot.posture.force_break(CombatClock.time)
	duel.call("_on_robot_defeated")
	await process_frame
	var old_id := duel.get_instance_id()
	Input.action_press("confirm")
	await process_frame
	await process_frame
	Input.action_release("confirm")
	for i in 20:
		await process_frame
	duel = current_scene
	_check(duel != null and duel.get_instance_id() != old_id and duel.get("flow") == 0, "Enter reinicia o confronto do zero")
	var fresh: RobotEnemy = duel.get("robot")
	_check(fresh.health == fresh.max_health and fresh.posture.current == 0.0 and (duel.get("player") as Player).vitals.health == 120.0, "vida e postura cheias de novo")
	Input.action_press("training")
	await process_frame
	await process_frame
	Input.action_release("training")
	for i in 20:
		await process_frame
	_check(current_scene != null and current_scene.get("instructor") is TrainingInstructor and not current_scene.get("instructor") is RobotEnemy, "T abre o treino")
