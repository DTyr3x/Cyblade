extends SceneTree
## Verifica o parry com o JOGO rodando em FPS diferentes (o FPS de render é fixado na linha de comando
## com --fixed-fps; a física fica em 120 Hz). Três casos contra o Instrutor:
##   aperto 0,07 s antes do contato -> PARRY; aperto 0,30 s antes e segurando -> DEFESA; aperto 0,05 s
##   depois -> GOLPE RECEBIDO. A entrada chega por quadro de render, como num jogo real.
##   godot --headless --path . --fixed-fps 30 -s res://tests/parry_fps_check.gd
var _main: Node
var _player: Player
var _ins: TrainingInstructor
var _fails := 0


func _initialize() -> void:
	_run()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for i in 10:
		await process_frame
	_player = _main.get("player")
	_ins = _main.get("instructor")
	_ins.interval = 0.4
	var cases := [[-0.07, false, DefenseController.Result.PERFECT, "parry"], [-0.30, true, DefenseController.Result.BLOCK, "defesa"], [0.05, false, DefenseController.Result.HIT, "tarde"]]
	for c: Array in cases:
		_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
		_player.velocity = Vector3.ZERO
		_player.rotation.y = 0.0
		for i in 30:
			await process_frame
		while not (_ins.phase == TrainingInstructor.Phase.WINDUP and _ins.next_contact_time > 0.0):
			await process_frame
		var tc := _ins.next_contact_time
		var press_at: float = tc + c[0]
		# A entrada só pode chegar a cada quadro de render: aperta no primeiro quadro a partir do alvo.
		while CombatClock.time < press_at:
			await process_frame
		var pressed_at := CombatClock.time
		_key(KEY_K, true)
		if not c[1]:
			await process_frame
			_key(KEY_K, false)
		var n0 := _ins.results.size()
		while _ins.results.size() == n0 or float(_ins.results.back().get("time", 0.0)) < tc - 0.001:
			await process_frame
		_key(KEY_K, false)
		var got: int = _ins.results.back().get("result", -9)
		var ok: bool = got == int(c[2])
		if not ok:
			_fails += 1
		print("  %s  %s: aperto %+.3f s do contato (pedido %+.3f), resultado %s" % ["PASS" if ok else "FAIL", c[3], pressed_at - tc, c[0], ["PARRY", "DEFESA", "GOLPE"][got] if got >= 0 else str(got)])
		for i in 60:
			await process_frame
	# Contra-ataque de oportunidade: J a +0,20 s do contato (dentro da janela) = contra-corte; J a +0,95 s
	# (fora da janela de 0,80 s) = cadeia normal. Mesmo resultado em qualquer FPS de render.
	for spec: Array in [[0.20, true, "contra-ataque dentro da janela"], [0.95, false, "J fora da janela"]]:
		_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
		_player.velocity = Vector3.ZERO
		_player.rotation.y = 0.0
		for i in 40:
			await process_frame
		while not (_ins.phase == TrainingInstructor.Phase.WINDUP and _ins.next_contact_time > 0.0):
			await process_frame
		var tc2 := _ins.next_contact_time
		while CombatClock.time < tc2 - 0.07:
			await process_frame
		_key(KEY_K, true)
		await process_frame
		_key(KEY_K, false)
		while CombatClock.time < tc2 + float(spec[0]):
			await process_frame
		var sw := _player.combat.swing_id
		_key(KEY_J, true)
		await process_frame
		_key(KEY_J, false)
		for i in 12:
			await process_frame
		var was_counter: bool = _player.combat.swing_id > sw and _player.combat.is_counter
		var ok2: bool = was_counter == bool(spec[1])
		if not ok2:
			_fails += 1
		print("  %s  %s (J a +%.2f s): %s" % ["PASS" if ok2 else "FAIL", spec[2], float(spec[0]), "contra-corte" if was_counter else "cadeia normal"])
		for i in 60:
			await process_frame
	await _check_posture()
	print("== parry por FPS: %d falha(s) ==" % _fails)
	quit(1 if _fails > 0 else 0)


## Núcleo de postura (C2.0): parry → contra-corte → Kesa → recuperação até o piso. Mesmos valores em qualquer
## FPS de render, com a entrada chegando por quadro.
func _check_posture() -> void:
	var p := _ins.posture
	while not (_ins.phase == TrainingInstructor.Phase.WINDUP and _ins.next_contact_time > 0.0 and _ins.phase_time < 0.05):
		await process_frame
	_player.global_position = _ins.global_position + Vector3(0, 0.05, 1.7)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	p.reset()
	var tc := _ins.next_contact_time
	while CombatClock.time < tc - 0.07:
		await process_frame
	_key(KEY_K, true)
	await process_frame
	_key(KEY_K, false)
	while CombatClock.time < tc + 0.20:
		await process_frame
	_report("parry", p.current, p.locked, 25.0, 25.0)
	var hits := _ins.hits.size()
	await _tap_attack()
	while _ins.hits.size() == hits and CombatClock.time < tc + 1.0:
		await process_frame
	_report("contra-corte", p.current, p.locked, 37.0, 37.0)
	while _player.combat.is_attacking():
		await process_frame
	_ins.enabled = false
	var t1 := CombatClock.time
	while CombatClock.time < t1 + 0.7:
		await process_frame
	hits = _ins.hits.size()
	await _tap_attack()
	while _ins.hits.size() == hits and CombatClock.time < t1 + 1.4:
		await process_frame
	_report("Kesa depois de cravar", p.current, p.locked, 40.0, 37.0)
	var last := CombatClock.time
	while CombatClock.time < last + 2.0:
		await process_frame
	_report("recuperação até o piso", p.current, p.locked, 37.0, 37.0)


func _tap_attack() -> void:
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)


func _report(label: String, current: float, locked: float, want_current: float, want_locked: float) -> void:
	var ok := absf(current - want_current) < 0.01 and absf(locked - want_locked) < 0.01
	if not ok:
		_fails += 1
	print("  %s  postura, %s: atual %.2f, cravada %.2f" % ["PASS" if ok else "FAIL", label, current, locked])
