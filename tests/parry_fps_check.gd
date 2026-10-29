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
	print("== parry por FPS: %d falha(s) ==" % _fails)
	quit(1 if _fails > 0 else 0)
