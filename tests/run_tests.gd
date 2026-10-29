extends SceneTree
## Testes automatizados do Marco 1 (sem janela, sem GPU).
##
## Execução (a partir da raiz do projeto):
##   godot --headless --path . --fixed-fps 120 -s res://tests/run_tests.gd
## ou: tools\run_tests.ps1
##
## `--fixed-fps 120` faz cada quadro valer exatamente 1/120 s (1 tick de física),
## então as medições de tempo são determinísticas.
##
## Entradas de teclado e gamepad são SIMULADAS por eventos. Isto valida o mapeamento e
## a lógica, não o hardware real: o teste com controle físico fica no checklist humano.

const MAIN_SCENE := "res://game/main.tscn"
const DT := 1.0 / 120.0

var _passed := 0
var _failed := 0
var _main: Node
var _player: Player
var _rig: CameraRig


func _initialize() -> void:
	_run()


func _run() -> void:
	print("== CYBLADE · testes do Marco 1 ==")
	_test_motion_math()
	_test_frame_stats()
	await _setup_scene()
	_test_input_bindings()
	await _test_keyboard_movement()
	await _test_gamepad_movement()
	await _test_dodge()
	await _test_dodge_buffer_and_direction()
	await _test_dodge_flow()
	await _test_camera()
	await _test_camera_relative_movement()
	await _test_ramp()
	await _test_humanoid()
	await _test_h11()
	await _test_h2()
	await _test_h21()
	await _test_h22()
	await _test_h22_buffer_hitstop()
	print("== resultado: %d ok, %d falha(s) ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- infraestrutura -----------------------------------------------------------

func _check(cond: bool, name: String, detail := "") -> void:
	if cond:
		_passed += 1
		print("  PASS  ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		_failed += 1
		print("  FAIL  ", name, ("  (" + detail + ")") if detail != "" else "")


func _near(value: float, expected: float, tol: float, name: String) -> void:
	_check(absf(value - expected) <= tol, name, "obtido %.4f, esperado %.4f ±%.4f" % [value, expected, tol])


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(s: float) -> void:
	await _ticks(int(round(s / DT)))


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _reset_player(pos: Vector3, facing_yaw := 0.0) -> void:
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = facing_yaw
	_player.state = Player.State.MOVE
	_player.state_time = 0.0
	_rig.yaw = 0.0
	_rig.snap()
	await _seconds(0.3)


func _setup_scene() -> void:
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(_main)
	await _ticks(10)
	_player = _main.get_node("Player") as Player
	_rig = _main.get_node("CameraRig") as CameraRig
	_check(_player != null and _rig != null, "cena principal monta jogador e câmera")
	_check(Engine.physics_ticks_per_second == 120, "física em 120 Hz")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus", "renderizador configurado: Forward+")


# --- funções puras ------------------------------------------------------------

func _test_motion_math() -> void:
	print("-- MotionMath")
	var tuning := PlayerTuning.new()
	var v := Vector3.ZERO
	var t := 0.0
	while v.length() < tuning.max_speed - 0.001 and t < 1.0:
		v = MotionMath.approach_velocity(v, Vector3.RIGHT * tuning.max_speed, tuning.accel(), tuning.decel(), 1.5, DT)
		t += DT
	_near(t, tuning.accel_time, 0.02, "aceleração até a velocidade máxima (s)")

	v = Vector3.RIGHT * tuning.max_speed
	t = 0.0
	while v.length() > 0.001 and t < 1.0:
		v = MotionMath.approach_velocity(v, Vector3.ZERO, tuning.accel(), tuning.decel(), 1.5, DT)
		t += DT
	_near(t, tuning.decel_time, 0.02, "frenagem até parar (s)")

	v = Vector3.RIGHT * tuning.max_speed
	t = 0.0
	var target := Vector3.LEFT * tuning.max_speed
	while v.distance_to(target) > 0.001 and t < 1.0:
		v = MotionMath.approach_velocity(v, target, tuning.accel(), tuning.decel(), tuning.reverse_accel_multiplier, DT)
		t += DT
	# Freia com o multiplicador até cruzar zero e depois acelera na taxa normal.
	var expected_reverse := tuning.max_speed / (tuning.accel() * tuning.reverse_accel_multiplier) + tuning.max_speed / tuning.accel()
	_near(t, expected_reverse, 0.02, "inversão de sentido (s)")

	var sum := 0.0
	var steps := int(round(tuning.dodge_duration / DT))
	for i in steps:
		sum += MotionMath.dodge_distance_at(float(i + 1) / steps, tuning.dodge_distance) \
			- MotionMath.dodge_distance_at(float(i) / steps, tuning.dodge_distance)
	_near(sum, tuning.dodge_distance, 0.0001, "esquiva soma exatamente a distância configurada")
	_check(MotionMath.dodge_distance_at(0.5, 4.0) > 2.0, "esquiva sai rápido (mais da metade da distância em metade do tempo)")

	_check(MotionMath.smooth_alpha(1.0, 0.1) > 0.99, "suavização converge em 10·tau")
	_near(MotionMath.smooth_alpha(0.01, 0.1) + 0.0, 1.0 - exp(-0.1), 0.0001, "suavização exponencial")
	var a60 := 1.0
	var a120 := 1.0
	for i in 60:
		a60 *= 1.0 - MotionMath.smooth_alpha(1.0 / 60.0, 0.1)
	for i in 120:
		a120 *= 1.0 - MotionMath.smooth_alpha(1.0 / 120.0, 0.1)
	_near(a60, a120, 0.0001, "suavização independe da taxa de quadros")


func _test_frame_stats() -> void:
	print("-- FrameStats")
	var samples := PackedFloat32Array()
	for i in 99:
		samples.append(0.01)
	samples.append(0.1)
	var s := FrameStats.compute(samples)
	_near(s["avg_fps"], 1.0 / 0.0109, 0.5, "FPS médio")
	_near(s["max_ms"], 100.0, 0.01, "pior quadro (ms)")
	_near(s["low1_fps"], 100.0, 0.01, "1% baixo (FPS do percentil 99)")
	_check(FrameStats.compute(PackedFloat32Array()).is_empty(), "sem amostras devolve vazio")


func _test_input_bindings() -> void:
	print("-- Mapa de entrada")
	var needs_keyboard := ["move_left", "move_right", "move_up", "move_down", "dodge", "camera_yaw_left", "camera_yaw_right", "camera_reset", "debug_toggle"]
	var needs_pad := ["move_left", "move_right", "move_up", "move_down", "dodge", "camera_yaw_left", "camera_yaw_right", "camera_reset", "camera_preset_next", "camera_preset_prev", "debug_toggle"]
	for action: String in needs_keyboard:
		var has_key := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				has_key = true
		_check(InputMap.has_action(action) and has_key, "teclado mapeado: " + action)
	for action: String in needs_pad:
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		_check(InputMap.has_action(action) and has_pad, "gamepad mapeado: " + action)


# --- cena ---------------------------------------------------------------------

func _test_keyboard_movement() -> void:
	print("-- Movimento (teclado simulado)")
	await _reset_player(Vector3(-15, 0.05, 25))
	var start := _player.global_position
	_key(KEY_D, true)
	await _seconds(0.5)
	var speed := _player.horizontal_velocity().length()
	_near(speed, 6.0, 0.05, "velocidade de cruzeiro (m/s)")
	var expected := 6.0 * 0.5 - 6.0 * 0.12 * 0.5
	_near(_player.global_position.x - start.x, expected, 0.2, "deslocamento em 0,5 s (m)")
	_near(_player.global_position.z - start.z, 0.0, 0.05, "sem desvio lateral")
	_check(_player.global_position.y < 0.2, "permanece no chão")
	_key(KEY_D, false)
	await _seconds(0.15)
	_check(_player.horizontal_velocity().length() < 0.05, "para em 0,15 s após soltar", "vel %.3f" % _player.horizontal_velocity().length())


func _test_gamepad_movement() -> void:
	print("-- Movimento (gamepad simulado)")
	await _reset_player(Vector3(-15, 0.05, 25))
	var start := _player.global_position
	_pad_axis(JOY_AXIS_LEFT_X, 1.0)
	await _seconds(0.5)
	_near(_player.horizontal_velocity().length(), 6.0, 0.05, "stick a 100%: velocidade máxima")
	_check(_player.global_position.x - start.x > 2.0, "stick direito do jogador anda para +X")
	_pad_axis(JOY_AXIS_LEFT_X, 0.5)
	await _seconds(0.5)
	# O Godot reescala a zona morta: (0,5 - 0,2) / (1 - 0,2) = 37,5% da velocidade máxima.
	_near(_player.horizontal_velocity().length(), 6.0 * 0.375, 0.1, "stick a 50%: velocidade analógica com zona morta reescalada")
	_pad_axis(JOY_AXIS_LEFT_X, 0.1)
	await _seconds(0.3)
	_check(_player.horizontal_velocity().length() < 0.05, "zona morta de 20% ignora o stick fraco")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)


func _test_dodge() -> void:
	print("-- Esquiva")
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	var start := _player.global_position
	var dodge_ticks := 0
	var recovery_ticks := 0
	var iframe_ticks := 0
	var pos_after_dodge := Vector3.ZERO
	var recorded_end := false
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	for i in 120:
		await physics_frame
		match _player.state:
			Player.State.DODGE:
				dodge_ticks += 1
				if _player.is_invulnerable():
					iframe_ticks += 1
			Player.State.RECOVERY:
				if not recorded_end:
					pos_after_dodge = _player.global_position
					recorded_end = true
				recovery_ticks += 1
		if _player.state == Player.State.MOVE and recorded_end:
			break
	_near(dodge_ticks * DT, 0.25, 0.03, "duração do deslocamento (s)")
	_near(recovery_ticks * DT, 0.18, 0.03, "duração da recuperação (s)")
	_near(pos_after_dodge.distance_to(start), 4.0, 0.15, "distância da esquiva (m)")
	_near(iframe_ticks * DT, 0.15, 0.03, "janela de invulnerabilidade (s)")
	_check(_player.state == Player.State.MOVE, "volta ao estado MOVE")
	_check(not _player.is_invulnerable(), "sem invulnerabilidade fora da esquiva")


func _test_dodge_buffer_and_direction() -> void:
	print("-- Esquiva: buffer e direção")
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	await _seconds(0.35)
	_check(_player.state == Player.State.RECOVERY, "no meio da recuperação")
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	await _seconds(0.1)
	_check(_player.state == Player.State.DODGE, "esquiva pedida na recuperação dispara ao terminar (buffer)")
	await _seconds(0.6)
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	var start := _player.global_position
	_key(KEY_W, true)
	await _seconds(0.3)
	_key(KEY_SPACE, true)
	await physics_frame
	_key(KEY_SPACE, false)
	await _seconds(0.45)
	_key(KEY_W, false)
	_check(_player.global_position.z < start.z - 4.0, "esquiva segue a direção do movimento (para frente da câmera)")
	await _seconds(0.3)
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_pad_button(JOY_BUTTON_B, true)
	await physics_frame
	_pad_button(JOY_BUTTON_B, false)
	await _seconds(0.1)
	_check(_player.state == Player.State.DODGE, "botão B do gamepad dispara a esquiva")
	await _seconds(0.5)
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_SHIFT, true)
	await physics_frame
	_key(KEY_SHIFT, false)
	await _seconds(0.1)
	_check(_player.state == Player.State.DODGE, "Shift dispara a esquiva")
	await _seconds(0.5)


func _test_camera() -> void:
	print("-- Câmera")
	_rig.set_preset(0, true)
	await _reset_player(Vector3(-15, 0.05, 25))
	await _seconds(1.0)
	var cam := _rig.camera
	_near(rad_to_deg(cam.global_rotation.x), -45.0, 0.5, "inclinação do preset combate (°)")
	_near(cam.fov, 34.0, 0.1, "FOV vertical do preset combate (°)")
	var hud := _main.get_node("DebugHud") as DebugHud
	var pct := hud.player_screen_height_percent()
	_check(pct > 8.0 and pct < 13.0, "jogador ocupa ~9–11% da altura da tela", "%.1f %%" % pct)

	_key(KEY_D, true)
	await _seconds(1.5)
	var lag := _rig.global_position.x - _player.global_position.x
	_check(lag < 0.1 and lag > -1.0, "câmera acompanha com atraso curto em movimento", "defasagem %.2f m" % lag)
	_key(KEY_D, false)
	await _seconds(1.5)
	_near(_rig.global_position.x, _player.global_position.x, 0.05, "câmera recentraliza após parar (m)")

	_rig.set_preset(2)
	await _seconds(1.5)
	_near(rad_to_deg(cam.global_rotation.x), -20.0, 0.5, "preset chefe: inclinação (°)")
	_near(cam.position.z, 26.0, 0.2, "preset chefe: distância (m)")
	var boss_pct := hud.player_screen_height_percent()
	var feet := cam.unproject_position(_player.global_position)
	var screen_h := root.get_visible_rect().size.y
	_check(feet.y / screen_h > 0.75 and feet.y / screen_h < 0.92, "preset chefe: jogador no terço inferior da tela, sem cortar", "pés em %.0f %% da altura" % (feet.y / screen_h * 100.0))
	_check(boss_pct > 0.0, "preset chefe: jogador visível", "%.1f %%" % boss_pct)

	_rig.set_preset(0)
	await _seconds(1.5)
	_near(rad_to_deg(cam.global_rotation.x), -45.0, 0.5, "volta ao preset combate (°)")

	Input.action_press("camera_yaw_right", 1.0)
	await _seconds(0.5)
	Input.action_release("camera_yaw_right")
	_near(rad_to_deg(_rig.yaw), -70.0, 3.0, "stick direito gira a câmera 140°/s (°)")
	_rig.reset_yaw()
	_check(_rig.yaw == 0.0, "centralizar câmera zera a guinada")


func _test_ramp() -> void:
	print("-- Rampa e plataforma")
	await _reset_player(Vector3(20, 0.05, 6))
	_key(KEY_W, true)
	await _seconds(4.0)
	_key(KEY_W, false)
	_check(_player.global_position.y > 3.95, "sobe a rampa até a plataforma de 4 m", "altura %.2f m" % _player.global_position.y)
	_check(_player.is_on_floor(), "termina apoiado na plataforma")
	await _seconds(0.3)
	await _reset_player(Vector3(20, 4.05, -17), 0.0)
	_key(KEY_S, true)
	await _seconds(3.5)
	_key(KEY_S, false)
	_check(_player.global_position.y < 0.3, "desce a rampa de volta ao piso", "altura %.2f m" % _player.global_position.y)


func _test_camera_relative_movement() -> void:
	print("-- Movimento relativo à câmera")
	await _reset_player(Vector3(-15, 0.05, 25))
	_rig.yaw = PI / 2.0
	var start := _player.global_position
	_key(KEY_W, true)
	await _seconds(0.5)
	_key(KEY_W, false)
	_check(_player.global_position.x < start.x - 2.0, "com a câmera girada 90°, 'frente' vai para -X")
	_near(_player.global_position.z - start.z, 0.0, 0.1, "sem desvio em Z")
	await _seconds(0.3)
	_rig.yaw = 0.0


# --- fluidez pós-esquiva ------------------------------------------------------

## Velocidade horizontal mínima observada em `seconds` a partir de agora, e a final.
func _speed_trace(seconds: float) -> Dictionary:
	var min_v := INF
	var last := 0.0
	for i in int(round(seconds / DT)):
		await physics_frame
		last = _player.horizontal_velocity().length()
		min_v = minf(min_v, last)
	return {"min": min_v, "last": last}


func _tap(code: Key) -> void:
	_key(code, true)
	await physics_frame
	_key(code, false)


func _wait_state(s: Player.State, timeout := 1.0) -> bool:
	var n := int(round(timeout / DT))
	while _player.state != s and n > 0:
		await physics_frame
		n -= 1
	return _player.state == s


func _test_dodge_flow() -> void:
	print("-- Esquiva: fluidez (sem queda artificial de velocidade)")
	var cruise := _player.tuning.max_speed

	# 1. Corrida -> esquiva -> corrida contínua (Espaço).
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SPACE)
	_check(await _wait_state(Player.State.RECOVERY), "1. esquiva termina em RECOVERY")
	var v_end := _player.horizontal_velocity().length()
	_check(v_end >= cruise * 0.9, "1. sai da esquiva em velocidade de corrida", "%.2f m/s" % v_end)
	var tr := await _speed_trace(0.6)
	_check(tr.min >= cruise * 0.95, "1. sem queda de velocidade depois da esquiva (mínimo)", "mín %.2f m/s, cruzeiro %.2f" % [tr.min, cruise])
	_key(KEY_W, false)
	await _seconds(0.3)

	# 2. Esquiva parada -> segurar direção logo depois: acelera já na recuperação.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	await _tap(KEY_SPACE)
	await _seconds(0.1)
	_key(KEY_W, true)
	_check(await _wait_state(Player.State.RECOVERY), "2. esquiva parada chega a RECOVERY")
	await _seconds(0.1)
	_check(_player.horizontal_velocity().length() > cruise * 0.6, "2. recuperação não trava a locomoção (já está acelerando)", "%.2f m/s" % _player.horizontal_velocity().length())
	await _seconds(0.3)
	_near(_player.horizontal_velocity().length(), cruise, 0.1, "2. chega à velocidade de corrida")
	_key(KEY_W, false)
	await _seconds(0.3)

	# 3. Esquiva -> nenhuma direção: desacelera naturalmente e para.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SPACE)
	_key(KEY_W, false)
	await _seconds(0.6)
	_check(_player.horizontal_velocity().length() < 0.05, "3. sem direção, para depois da esquiva")
	_check(_player.state == Player.State.MOVE, "3. volta a MOVE")

	# 4. Esquiva -> mudança de direção (D, perpendicular): responde sem pausa.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SPACE)
	_key(KEY_W, false)
	_key(KEY_D, true)
	_check(await _wait_state(Player.State.RECOVERY), "4. esquiva termina com a direção trocada")
	await _seconds(0.1)
	var vel := _player.horizontal_velocity()
	_check(vel.x > 1.5, "4. já acelera para a nova direção na recuperação", "vx %.2f" % vel.x)
	await _seconds(0.4)
	_near(_player.horizontal_velocity().length(), cruise, 0.15, "4. velocidade de corrida na nova direção")
	_key(KEY_D, false)
	await _seconds(0.3)

	# 5. Esquiva contra obstáculo (caixa em (10,0.6,10), 2x2): para na parede, sem atravessar.
	await _reset_player(Vector3(5.0, 0.05, 10.0), -PI / 2.0)
	_rig.snap()
	_key(KEY_D, true)
	await _seconds(0.4)
	await _tap(KEY_SPACE)
	await _seconds(0.5)
	_check(_player.global_position.x < 9.0, "5. esquiva contra obstáculo não atravessa a caixa", "x %.2f" % _player.global_position.x)
	_check(_player.state != Player.State.DODGE, "5. sai do estado de esquiva")
	_key(KEY_D, false)
	await _seconds(0.3)

	# 6. Esquivas repetidas: a recuperação ainda impede esquiva nova; o pedido antecipado vale.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SPACE)
	_check(await _wait_state(Player.State.RECOVERY), "6. primeira esquiva termina")
	await _seconds(0.05)
	await _tap(KEY_SPACE)
	_check(_player.state == Player.State.RECOVERY, "6. durante a recuperação não esquiva de imediato (recarga)")
	_check(await _wait_state(Player.State.DODGE, 0.3), "6. pedido antecipado dispara ao fim da recuperação")
	var starts := 0
	_player.dodge_started.connect(func(_d): starts += 1)
	await _seconds(0.8)
	_key(KEY_W, false)
	_check(starts == 0, "6. nenhuma esquiva fantasma extra")
	await _seconds(0.3)

	# 7. Shift e gamepad (B + stick) também mantêm o fluxo.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SHIFT)
	_check(await _wait_state(Player.State.RECOVERY), "7. Shift: esquiva termina")
	tr = await _speed_trace(0.6)
	_check(tr.min >= cruise * 0.95, "7. Shift: sem queda de velocidade", "mín %.2f" % tr.min)
	_key(KEY_W, false)
	await _seconds(0.3)

	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_pad_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _seconds(0.5)
	_pad_button(JOY_BUTTON_B, true)
	await physics_frame
	_pad_button(JOY_BUTTON_B, false)
	_check(await _wait_state(Player.State.RECOVERY), "7. gamepad: esquiva termina")
	tr = await _speed_trace(0.6)
	_check(tr.min >= cruise * 0.95, "7. gamepad: sem queda de velocidade", "mín %.2f" % tr.min)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _seconds(0.3)

	# Distância preservada com a nova saída em velocidade de corrida.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	var p0 := _player.global_position
	await _tap(KEY_SPACE)
	_check(await _wait_state(Player.State.RECOVERY), "8. esquiva em corrida termina")
	var moved := _player.global_position.distance_to(p0)
	_key(KEY_W, false)
	_near(moved, 4.0, 0.3, "8. deslocamento da esquiva em corrida (m)")
	await _seconds(0.5)


# --- H1: humanoide animado -----------------------------------------------------

const REQUIRED_BONES := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "ball_l", "thigh_r", "calf_r", "foot_r", "ball_r"]


func _foot_world(bone: int) -> Vector3:
	var sk := _player.visual.skeleton
	return sk.global_transform * sk.get_bone_global_pose(bone).origin


## Escorregamento dos pés: velocidade horizontal (m/s, no mundo) do pé enquanto apoiado.
## Pé parado no chão = 0. Devolve média, p95 e quantidade de ticks de apoio.
func _foot_slide(seconds: float) -> Dictionary:
	var sk := _player.visual.skeleton
	var bones := [sk.find_bone("foot_l"), sk.find_bone("foot_r")]
	var prev := [_foot_world(bones[0]), _foot_world(bones[1])]
	var samples := [[], []]
	var min_y := [INF, INF]
	for i in int(round(seconds / DT)):
		await physics_frame
		for f in 2:
			var p := _foot_world(bones[f])
			var v := Vector2(p.x - prev[f].x, p.z - prev[f].z).length() / DT
			samples[f].append([p.y, v])
			min_y[f] = minf(min_y[f], p.y)
			prev[f] = p
	var slides: Array = []
	for f in 2:
		for s: Array in samples[f]:
			if s[0] < min_y[f] + 0.03:
				slides.append(s[1])
	slides.sort()
	var total := 0.0
	for s: float in slides:
		total += s
	return {"mean": total / maxf(slides.size(), 1), "p95": slides[int(slides.size() * 0.95)] if slides.size() > 0 else 0.0, "n": slides.size()}


func _test_humanoid() -> void:
	print("-- H1: humanoide, esqueleto e animação")
	var vis: HumanoidVisual = _player.visual
	var cruise := _player.tuning.max_speed

	# Consistência do esqueleto e dos ativos.
	_check(vis.skeleton != null and vis.skeleton.get_bone_count() == 65, "esqueleto com 65 ossos", "%d" % (vis.skeleton.get_bone_count() if vis.skeleton else -1))
	var missing: Array = []
	for b in REQUIRED_BONES:
		if vis.skeleton.find_bone(b) < 0:
			missing.append(b)
	_check(missing.is_empty(), "ossos humanoides obrigatórios presentes", str(missing))
	var clips_ok := true
	for p: Array in HumanoidVisual.LOCO_POINTS:
		clips_ok = clips_ok and vis.anim_player.has_animation(p[0])
	_check(clips_ok, "clipes de locomoção existem no pacote (Idle, Walk, Jog_Fwd, Sprint)")
	_check(vis.anim_tree != null and vis.anim_tree.active, "AnimationTree ativo")
	_check(vis.pose_modifier != null and vis.pose_modifier.get_parent() == vis.skeleton, "modificador de pose ligado ao esqueleto")
	var hand_attach := vis.katana.get_parent() as BoneAttachment3D
	_check(hand_attach != null and hand_attach.bone_name == "hand_r" and hand_attach.get_parent() == vis.skeleton, "katana presa ao osso hand_r")
	_check(_foot_world(vis.skeleton.find_bone("foot_l")).y > -0.1, "pés acima do piso no repouso")

	# Parado: animação em idle.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	await _seconds(0.3)
	_near(vis.blend_position(), 0.0, 0.01, "parado: animação em Idle (ponto 0)")

	# Corrida -> parada: a animação acompanha a velocidade REAL, sem atraso.
	_key(KEY_W, true)
	await _seconds(0.6)
	var follow_err := 0.0
	for i in 30:
		await physics_frame
		follow_err = maxf(follow_err, absf(vis.effective_speed() - _player.horizontal_velocity().length()))
	_near(vis.effective_speed(), cruise, 0.05, "correndo: velocidade coberta pela animação = velocidade da cápsula (m/s)")
	_near(vis.blend_position(), HumanoidVisual.JOG_SPEED, 0.01, "correndo a 6 m/s: ciclo de Jog puro (sem misturar com Sprint)")
	_check(vis.run_scale() > 1.0 and vis.run_scale() <= HumanoidVisual.MAX_JOG_SCALE, "Jog acelerado em %.2fx para casar com o chão" % vis.run_scale())
	_check(follow_err < 0.05, "em regime a animação lê a velocidade real", "erro máx %.3f m/s" % follow_err)
	_check(vis.pose_modifier.run_amount() > 0.95, "postura de espadachim na corrida (katana para trás)", "%.2f" % vis.pose_modifier.run_amount())
	_key(KEY_W, false)
	var max_step := 0.0
	var prev_blend := vis.blend_position()
	var settle := -1.0
	for i in int(0.5 / DT):
		await physics_frame
		max_step = maxf(max_step, absf(vis.blend_position() - prev_blend))
		prev_blend = vis.blend_position()
		if settle < 0.0 and vis.blend_position() < 0.05:
			settle = i * DT
	_check(settle >= 0.0 and settle < 0.2, "corrida → parada: animação chega a Idle em < 0,2 s", "%.3f s" % settle)
	_check(max_step < 1.2, "parada sem salto brusco no ponto de mistura (por tick)", "%.2f m/s por tick" % max_step)
	_check(vis.pose_modifier.run_amount() < 0.2, "postura de corrida se desfaz ao parar", "%.2f" % vis.pose_modifier.run_amount())

	# Corrida -> giro -> corrida (45° e 90° mantendo a corrida).
	var turns := [
		["45°", KEY_W, KEY_D, 45.0],
		["90°", KEY_W, KEY_A, 90.0],
	]
	for t: Array in turns:
		await _reset_player(Vector3(-15, 0.05, 25), 0.0)
		_key(t[1], true)
		await _seconds(0.5)
		var yaw0 := _player.rotation.y
		_key(t[2], true)
		if t[3] == 90.0:
			_key(t[1], false)
		var t_turn := -1.0
		var min_speed := INF
		var min_blend := INF
		for i in int(0.6 / DT):
			await physics_frame
			var dy := absf(angle_difference(_player.rotation.y, yaw0))
			if t_turn < 0.0 and rad_to_deg(dy) >= t[3] - 3.0:
				t_turn = i * DT
			min_speed = minf(min_speed, _player.horizontal_velocity().length())
			min_blend = minf(min_blend, vis.effective_speed())
		_check(t_turn >= 0.0 and t_turn < 0.2, "giro de %s completa em < 0,2 s (corpo)" % t[0], "%.3f s" % t_turn)
		_check(min_speed > cruise * 0.6, "giro de %s sem parar a corrida" % t[0], "mín %.2f m/s" % min_speed)
		_check(min_blend > cruise * 0.6, "giro de %s: animação segue em corrida" % t[0], "mín %.2f" % min_blend)
		_near(_player.horizontal_velocity().length(), cruise, 0.15, "giro de %s: volta à velocidade de corrida" % t[0])
		_key(t[1], false)
		_key(t[2], false)
		await _seconds(0.3)

	# 180°: a inversão passa por velocidade baixa por regra de controle (~0,2 s), já aprovada.
	await _reset_player(Vector3(-15, 0.05, 25), 0.0)
	_key(KEY_D, true)
	await _seconds(0.5)
	var yaw180 := _player.rotation.y
	_key(KEY_D, false)
	_key(KEY_A, true)
	var t180 := -1.0
	for i in int(0.6 / DT):
		await physics_frame
		if t180 < 0.0 and rad_to_deg(absf(angle_difference(_player.rotation.y, yaw180))) >= 177.0:
			t180 = i * DT
	_check(t180 >= 0.0 and t180 < 0.25, "giro de 180° completa em < 0,25 s (corpo)", "%.3f s" % t180)
	_near(_player.horizontal_velocity().length(), cruise, 0.15, "giro de 180°: volta à velocidade de corrida")
	_key(KEY_A, false)
	await _seconds(0.3)

	# Corrida -> esquiva -> corrida: investida visual e retorno sem queda.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _tap(KEY_SPACE)
	var max_dash := 0.0
	var max_blend := 0.0
	for i in int(0.2 / DT):
		await physics_frame
		max_dash = maxf(max_dash, vis.pose_modifier.dash_amount())
		max_blend = maxf(max_blend, vis.blend_position())
	_check(max_dash > 0.8, "esquiva: pose de investida aparece", "%.2f" % max_dash)
	_near(max_blend, HumanoidVisual.DASH_BLEND_POINT, 0.5, "esquiva: ciclo de sprint na investida")
	var after := await _speed_trace(0.5)
	var min_after_blend := INF
	for i in int(0.4 / DT):
		await physics_frame
		min_after_blend = minf(min_after_blend, vis.effective_speed())
	_check(after.min >= cruise * 0.95, "esquiva → corrida: velocidade da cápsula não cai", "mín %.2f" % after.min)
	_check(min_after_blend > cruise * 0.9, "esquiva → corrida: animação segue em corrida", "mín %.2f" % min_after_blend)
	_check(vis.pose_modifier.dash_amount() < 0.05, "esquiva: pose de investida se desfaz", "%.2f" % vis.pose_modifier.dash_amount())
	_key(KEY_W, false)
	await _seconds(0.3)

	# Esquiva sem direção pressionada.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	await _tap(KEY_SPACE)
	await _seconds(0.25)
	_check(vis.pose_modifier.dash_amount() > 0.6, "esquiva parado: pose de investida", "%.2f" % vis.pose_modifier.dash_amount())
	await _seconds(0.6)
	_near(vis.blend_position(), 0.0, 0.05, "esquiva parado: volta ao Idle")
	_check(_player.state == Player.State.MOVE, "esquiva parado: volta a MOVE")

	# Rampa: animação segue a velocidade horizontal e o corpo sobe.
	await _reset_player(Vector3(20, 0.05, 2.0), 0.0)
	_key(KEY_W, true)
	await _seconds(1.5)
	var on_ramp_y := _player.global_position.y
	var vh := _player.horizontal_velocity().length()
	_check(on_ramp_y > 0.8, "rampa: o corpo sobe", "altura %.2f m" % on_ramp_y)
	_check(vh > cruise * 0.7 and absf(vis.effective_speed() - vh) < 0.1, "rampa: animação segue a velocidade horizontal", "v %.2f, animação %.2f" % [vh, vis.effective_speed()])
	_key(KEY_W, false)
	await _seconds(0.3)

	# Deslize dos pés em corrida constante (medição; limite conservador, ver docs/h1-locomocao.md).
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.6)
	var slide := await _foot_slide(1.5)
	_key(KEY_W, false)
	print("  [medição] deslize dos pés na corrida: média %.2f m/s, p95 %.2f m/s, %d ticks de apoio" % [slide.mean, slide.p95, slide.n])
	_check(slide.n >= 20, "deslize: houve ticks de apoio medidos", "%d" % slide.n)
	_check(slide.mean < 1.0, "deslize médio dos pés em apoio na corrida < 1,0 m/s", "%.2f m/s" % slide.mean)
	await _seconds(0.3)


# --- H1.1: refinamento da locomoção ---------------------------------------------

## Balanço do braço da katana: amplitude (pico a pico, m) da mão direita no referencial do
## peito (spine_03) durante `seconds` de corrida. Menor = braço mais firme junto ao corpo.
func _arm_sway(seconds: float) -> float:
	var sk := _player.visual.skeleton
	var hand := sk.find_bone("hand_r")
	var chest := sk.find_bone("spine_03")
	var acc := {"lo": Vector3(INF, INF, INF), "hi": Vector3(-INF, -INF, -INF)}
	# `skeleton_updated` sai depois dos modificadores: é a pose que vai para a tela.
	var sample := func() -> void:
		var p := sk.get_bone_global_pose(chest).affine_inverse() * sk.get_bone_global_pose(hand).origin
		acc.lo = Vector3(minf(acc.lo.x, p.x), minf(acc.lo.y, p.y), minf(acc.lo.z, p.z))
		acc.hi = Vector3(maxf(acc.hi.x, p.x), maxf(acc.hi.y, p.y), maxf(acc.hi.z, p.z))
	sk.skeleton_updated.connect(sample)
	await _seconds(seconds)
	sk.skeleton_updated.disconnect(sample)
	return (acc.hi - acc.lo).length()


func _test_h11() -> void:
	print("-- H1.1: refinamento (braço da katana, postura por arma, giros)")
	var vis: HumanoidVisual = _player.visual
	var mod := vis.pose_modifier
	var cruise := _player.tuning.max_speed

	# Balanço do braço: a medição é a pose final (depois do modificador). H1 media 0,48 m
	# (pior que o clipe cru, 0,29 m, porque o alvo fixo no modelo brigava com o tronco).
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.8)
	var sway := await _arm_sway(1.2)
	mod.active = false
	var sway_clip := await _arm_sway(1.2)
	mod.active = true
	_key(KEY_W, false)
	print("  [medição] mão da katana na corrida: %.3f m (H1: 0.482 m; clipe cru: %.3f m)" % [sway, sway_clip])
	_check(sway < 0.482 * 0.5, "balanço da mão da katana pelo menos 50%% menor que no H1", "%.3f m" % sway)
	_check(sway < sway_clip * 0.8, "braço da katana mais firme que o clipe cru", "%.3f m" % sway)
	_check(sway > 0.02, "braço ainda tem movimento (não fica travado como um robô)", "%.3f m" % sway)
	await _seconds(0.3)

	# Postura por família de arma.
	_check(mod.stance != null and mod.stance.family == WeaponStance.KATANA, "postura ativa é a da katana")
	_check(WeaponStance.for_family(&"katana").family == WeaponStance.KATANA, "família katana resolve a própria postura")
	var all_resolve := true
	for f: StringName in WeaponStance.PLANNED:
		all_resolve = all_resolve and WeaponStance.for_family(f) != null
	_check(all_resolve, "famílias planejadas ainda sem postura própria caem na katana (sem quebrar)")
	_check(mod.stance.arm_swing_keep > 0.0 and mod.stance.arm_swing_keep < 0.5, "postura define balanço conservado do braço", "%.2f" % mod.stance.arm_swing_keep)

	# Giros: o quadril visual acompanha com atraso curto, o tronco lidera, a cápsula não espera.
	for t: Array in [["45°", KEY_D, 45.0], ["90°", KEY_A, 90.0]]:
		await _reset_player(Vector3(-15, 0.05, 25), 0.0)
		_key(KEY_W, true)
		await _seconds(0.5)
		var yaw0 := _player.rotation.y
		_key(t[1], true)
		if t[2] == 90.0:
			_key(KEY_W, false)
		var max_off := 0.0
		var t_body := -1.0
		var min_speed := INF
		for i in int(0.6 / DT):
			await physics_frame
			max_off = maxf(max_off, absf(mod._turn_offset))
			min_speed = minf(min_speed, _player.horizontal_velocity().length())
			if t_body < 0.0 and rad_to_deg(absf(angle_difference(_player.rotation.y, yaw0))) >= t[2] - 3.0:
				t_body = i * DT
		_check(rad_to_deg(max_off) > 3.0, "giro de %s: o quadril visual acompanha com suavização" % t[0], "desvio máx %.1f°" % rad_to_deg(max_off))
		_check(rad_to_deg(max_off) <= HumanoidVisual.TURN_LAG_MAX_DEG + 0.5, "giro de %s: desvio visual limitado" % t[0], "%.1f°" % rad_to_deg(max_off))
		_check(t_body >= 0.0 and t_body < 0.2, "giro de %s: o corpo da cápsula continua girando em < 0,2 s" % t[0], "%.3f s" % t_body)
		_check(min_speed > cruise * 0.6, "giro de %s: suavização visual não reduz a velocidade" % t[0], "mín %.2f" % min_speed)
		_check(rad_to_deg(absf(mod._turn_offset)) < 3.0, "giro de %s: quadril alinhado de novo ao fim" % t[0], "%.1f°" % rad_to_deg(mod._turn_offset))
		_key(t[1], false)
		_key(KEY_W, false)
		await _seconds(0.3)

	# Giro de 180° parado e sentido do tronco: o peito lidera (gira menos atrás da cápsula que o quadril).
	await _reset_player(Vector3(-15, 0.05, 25), 0.0)
	await _seconds(0.3)
	_key(KEY_D, true)
	var lead_ok := false
	var hip_lag := 0.0
	for i in int(0.4 / DT):
		await physics_frame
		hip_lag = maxf(hip_lag, absf(vis.rotation.y))
		var chest_world := vis.global_rotation.y - mod._turn_offset * mod.torso_lead
		var body := _player.global_rotation.y
		if absf(vis.rotation.y) > deg_to_rad(5.0) and absf(angle_difference(chest_world, body)) < absf(angle_difference(vis.global_rotation.y, body)):
			lead_ok = true
	_key(KEY_D, false)
	_check(lead_ok, "giro: o tronco fica mais perto da direção nova que o quadril", "atraso máx do quadril %.1f°" % rad_to_deg(hip_lag))
	await _seconds(0.4)

	# Esquiva preservada: perfil intocado e visual sem atraso de giro.
	await _reset_player(Vector3(-15, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	var p0 := _player.global_position
	await _tap(KEY_SPACE)
	var t_d := 0.0
	var off_dash := 0.0
	while _player.state != Player.State.MOVE and t_d < 0.8:
		await physics_frame
		t_d += DT
		if _player.state == Player.State.DODGE:
			off_dash = maxf(off_dash, absf(mod._turn_offset))
	_check(rad_to_deg(off_dash) < 1.0, "esquiva: visual sem atraso de giro", "%.2f°" % rad_to_deg(off_dash))
	_key(KEY_W, false)
	await _seconds(0.3)


# --- H2: combate de katana ------------------------------------------------------

func _attack_tap() -> void:
	_key(KEY_J, true)
	await physics_frame
	_key(KEY_J, false)
	await physics_frame


## Espera até `cond` ficar verdadeira (máx. `limit` s). Devolve o tempo gasto, ou -1.
func _wait_until(cond: Callable, limit := 2.0) -> float:
	var t := 0.0
	while t < limit:
		if cond.call():
			return t
		await physics_frame
		t += DT
	return -1.0


func _angle_to_dummy() -> float:
	var d := _main.get("dummy") as Node3D
	var to := d.global_position - _player.global_position
	to.y = 0.0
	return rad_to_deg((-_player.global_transform.basis.z).angle_to(to.normalized()))


func _test_h2() -> void:
	print("-- H2: combate de katana")
	var c := _player.combat
	var vis: HumanoidVisual = _player.visual
	var cruise := _player.tuning.max_speed
	var dummy := _main.get("dummy") as TrainingDummy
	var fx := _main.get("effects") as CombatEffects
	var s1 := c.combo.strikes[0]

	# Dados dos golpes: ordem das janelas e arquivo editável.
	_check(c.combo.strikes.size() == 3, "combo da katana tem 3 golpes")
	_check(ResourceLoader.exists(ComboSet.DEFAULT_PATH), "dados dos golpes em arquivo editável (.tres)")
	var windows_ok := true
	for s: StrikeData in c.combo.strikes:
		windows_ok = windows_ok and s.active_start < s.active_end and s.active_end <= s.chain_open \
			and s.chain_open < s.clip_length() and s.dodge_cancel_from < s.move_cancel_from \
			and s.move_cancel_from < s.clip_length() and s.speed > 0.0
	_check(windows_ok, "janelas de cada golpe em ordem (contato < encadeamento < cancelamento < fim)")
	_check(c.combo.strikes[2].camera_shake > 0.0 and c.combo.strikes[0].camera_shake == 0.0 and c.combo.strikes[1].camera_shake == 0.0, "tremor de câmera só no golpe final")
	# H2.2: o golpe 2 deixou de ser o espelho do 1 (agora é o Kiriage autoral). Teste adaptado: antes exigia
	# `mirrored` diferente entre os golpes 1 e 2; agora exige que o 2 tenha clipe próprio e não seja espelhado.
	_check(c.combo.strikes[1].clip_resource != null and not c.combo.strikes[1].mirrored and c.combo.strikes[1].clip_resource != c.combo.strikes[0].clip_resource, "golpe 2 tem clipe autoral próprio (não é o espelho do golpe 1)")

	# Golpe individual sem combo e sem alvo: fases, duração, volta a MOVE, erro registrado.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	var misses0 := _player.hit_detector.total_misses
	var phases: Array = []
	var on_phase := func(p: int) -> void: phases.append(p)
	c.strike_phase_changed.connect(on_phase)
	await _attack_tap()
	_check(c.is_attacking() and _player.state == Player.State.ATTACK, "ataque: entra em ATTACK imediatamente")
	_check(c.index == 0, "primeiro ataque é o golpe 1")
	var took := await _wait_until(func(): return not c.is_attacking(), 1.5)
	c.strike_phase_changed.disconnect(on_phase)
	_near(took, s1.total_real(), 0.05, "golpe 1: duração real = trecho / velocidade (s)")
	_check(phases == [CombatController.Phase.WINDUP, CombatController.Phase.ACTIVE, CombatController.Phase.RECOVERY, CombatController.Phase.NONE], "fases em ordem: preparação, contato, recuperação, fim", str(phases))
	await physics_frame
	_check(_player.state == Player.State.MOVE, "depois do golpe volta a MOVE (não fica travado)")
	_check(_player.hit_detector.total_misses == misses0 + 1, "golpe no vazio registra erro")
	await _seconds(0.8)
	await _attack_tap()
	_check(c.index == 0, "depois do tempo de reinício o ataque recomeça no golpe 1", "índice %d" % c.index)
	await _wait_until(func(): return not c.is_attacking(), 1.5)

	# Encadeamento de 3 golpes com buffer: apertos logo no início de cada golpe.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)   # deixa a cadeia reiniciar no golpe 1
	var started: Array = []
	var on_start := func(_d: StrikeData, i: int, _s: int) -> void: started.append(i)
	c.strike_started.connect(on_start)
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()   # guardado no buffer; o golpe 2 só entra quando a janela abre
	var t2 := await _wait_until(func(): return started.size() >= 2, 1.0)
	_check(started.size() >= 2 and started[1] == 1, "buffer: segundo aperto encadeia o golpe 2")
	_near(t2, s1.to_real(s1.chain_open) - 4 * DT, 0.04, "golpe 2 só entra quando a janela de encadeamento abre (s)")
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return started.size() >= 3, 1.0)
	_check(started.size() >= 3 and started[2] == 2, "terceiro aperto encadeia o golpe 3 (cadeia de 3 golpes)")
	await _wait_until(func(): return c.clip_time() >= c.current.chain_open - 0.15)   # o golpe final tem janela mais tardia
	await _attack_tap()
	await _wait_until(func(): return started.size() >= 4, 1.5)
	_check(started.size() >= 4 and started[3] == 0, "depois do golpe 3 a cadeia recomeça no golpe 1")
	c.strike_started.disconnect(on_start)
	await _wait_until(func(): return not c.is_attacking(), 2.0)
	await _seconds(0.7)

	# Sem novo aperto não há encadeamento.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	var n_before := c.swing_id
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	_check(c.swing_id == n_before + 1, "sem novo aperto não há encadeamento", "golpes %d" % (c.swing_id - n_before))
	await _seconds(0.7)

	# Cancelamento por esquiva e golpe → esquiva → corrida (parâmetros da esquiva intactos).
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _attack_tap()
	await _ticks(int(round(s1.to_real(s1.dodge_cancel_from) / DT)) + 2)
	await _tap(KEY_SPACE)
	var to_dodge := await _wait_until(func(): return _player.state == Player.State.DODGE, 0.3)
	_check(to_dodge >= 0.0 and not c.is_attacking(), "esquiva cancela o golpe quando a janela abre", "%.3f s" % to_dodge)
	var dodge_start := _player.global_position
	await _wait_until(func(): return _player.state != Player.State.DODGE, 0.5)
	var dodged := dodge_start.distance_to(_player.global_position)
	_near(dodged, _player.tuning.dodge_distance, 0.3, "esquiva depois de golpe: distância preservada (m)")
	var after := await _speed_trace(0.5)
	_check(after.min >= cruise * 0.9, "golpe → esquiva → corrida: velocidade da cápsula não cai", "mín %.2f" % after.min)
	_key(KEY_W, false)
	await _seconds(0.5)

	# Esquiva apertada logo depois do ataque sai assim que a janela abre.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _attack_tap()
	await _tap(KEY_SPACE)
	var quick := await _wait_until(func(): return _player.state == Player.State.DODGE, 0.3)
	_check(quick >= 0.0 and quick <= s1.to_real(s1.dodge_cancel_from) + 0.05, "esquiva apertada logo após o ataque sai assim que a janela abre", "%.3f s" % quick)
	await _seconds(0.8)

	# Acerto no boneco: um acerto por golpe e dano correto.
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	var dmg0 := dummy.total_damage
	var hits0 := dummy.hits.size()
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	_check(dummy.hits.size() == hits0 + 1, "golpe 1 acerta o boneco exatamente uma vez", "acertos %d" % (dummy.hits.size() - hits0))
	_near(dummy.total_damage - dmg0, s1.damage, 0.001, "dano do golpe 1")
	_check(dummy.hits.size() > hits0 and String(dummy.hits.back()["strike"]) == String(s1.id), "contato registrado com o nome do golpe")

	# Cadeia completa no boneco: sem dano duplicado.
	await _seconds(0.8)
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.5)
	hits0 = dummy.hits.size()
	var shakes0 := fx.shake_count()
	for i in 3:
		await _attack_tap()
		await _ticks(2)
		await _attack_tap()
		await _wait_until(func(): return c.index == (i + 1) % 3 or not c.is_attacking(), 1.0)
	await _wait_until(func(): return not c.is_attacking(), 2.0)
	var got := dummy.hits.size() - hits0
	_check(got >= 3, "cadeia de golpes no boneco: um acerto por golpe", "acertos %d" % got)
	var seen := {}
	var dup := false
	for h: Dictionary in dummy.hits.slice(hits0):
		if seen.has(h["swing"]):
			dup = true
		seen[h["swing"]] = true
	_check(not dup, "nenhum golpe acertou o mesmo alvo duas vezes (sem dano duplicado)")
	_check(fx.shake_count() - shakes0 >= 1, "o golpe final pede tremor discreto de câmera", "%d" % (fx.shake_count() - shakes0))
	var total_swings := c.swing_id
	_check(fx.shake_count() <= total_swings / 3 + 1, "tremor só nos golpes finais, não em todos")

	# Erro: de costas para o boneco (fora do cone de assistência) não acerta.
	await _seconds(0.8)
	await _reset_player(Vector3(0, 0.05, 5.4), PI)
	hits0 = dummy.hits.size()
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	_check(dummy.hits.size() == hits0, "golpe de costas para o boneco erra (sem dano)")
	await _seconds(0.8)

	# Assistência de mira: 50° fora, o corpo gira para o boneco.
	await _reset_player(Vector3(0, 0.05, 5.4), deg_to_rad(50.0))
	var off_before := _angle_to_dummy()
	await _attack_tap()
	await _ticks(int(0.15 / DT))
	var off_after := _angle_to_dummy()
	_check(off_after < off_before - 20.0, "assistência de mira gira o corpo para o boneco", "%.0f° → %.0f°" % [off_before, off_after])
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.8)

	# Orientação responsiva: a direção pressionada manda sobre a assistência.
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	_key(KEY_D, true)
	await _attack_tap()
	await _ticks(int(0.12 / DT))
	_key(KEY_D, false)
	var yaw_err := rad_to_deg(absf(angle_difference(_player.rotation.y, -PI / 2.0)))
	_check(yaw_err < 20.0, "direção pressionada orienta o golpe", "erro %.0f°" % yaw_err)
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.8)

	# Hitstop: o relógio do golpe congela no acerto; o jogo segue.
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _attack_tap()
	var froze := await _wait_until(func(): return c.in_hitstop(), 1.0)
	_check(froze >= 0.0, "acerto aciona o hitstop")
	var t_a := c.time
	var frame_a := Engine.get_physics_frames()
	await _ticks(3)
	_check(absf(c.time - t_a) < 0.0001 and Engine.get_physics_frames() > frame_a, "hitstop congela só o golpe (o jogo segue rodando)")
	var hs := 0.0
	while c.in_hitstop() and hs < 0.5:
		await physics_frame
		hs += DT
	_near(hs + 3 * DT, s1.hitstop, 0.03, "duração do hitstop do golpe 1 (s)")
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.8)

	# AnimationTree: OneShot ativo, mistura sobe e desce.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _attack_tap()
	await _ticks(6)
	_check(vis.is_striking() and bool(vis.anim_tree["parameters/Strike/active"]), "AnimationTree: OneShot do golpe ativo")
	_check(vis.strike_blend() > 0.5, "mistura do golpe sobre o corpo sobe", "%.2f" % vis.strike_blend())
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.4)
	_check(not vis.is_striking() and vis.strike_blend() < 0.05, "depois do golpe a mistura volta à locomoção", "%.2f" % vis.strike_blend())
	_check(not bool(vis.anim_tree["parameters/Strike/active"]), "OneShot encerrado depois do golpe")
	_near(vis.blend_position(), 0.0, 0.05, "parado depois do golpe: locomoção em Idle")

	# Recuperação cancelável por movimento: não fica preso depois de atacar.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _attack_tap()
	await _wait_until(func(): return c.move_cancel_open(), 1.0)
	_key(KEY_W, true)
	await _ticks(2)
	_check(_player.state == Player.State.MOVE and not c.is_attacking(), "direção cancela a recuperação e volta a MOVE")
	var run_trace := await _speed_trace(0.5)
	_check(run_trace.last >= cruise * 0.9, "depois de atacar a corrida retoma a velocidade", "%.2f" % run_trace.last)
	_key(KEY_W, false)
	await _seconds(0.4)

	# Obstáculo: o avanço do golpe não atravessa uma parede.
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 0.5)
	ws.shape = box
	wall.add_child(ws)
	_main.add_child(wall)
	wall.global_position = Vector3(-25, 1.5, 20)
	await _reset_player(Vector3(-25, 0.05, 21.6), 0.0)
	var min_z := 99.0
	for i in 3:
		await _attack_tap()
		await _ticks(2)
		await _attack_tap()
		for k in int(0.5 / DT):
			await physics_frame
			min_z = minf(min_z, _player.global_position.z)
	await _wait_until(func(): return not c.is_attacking(), 2.0)
	_check(min_z > 20.25 + 0.2, "golpes contra a parede não a atravessam", "z mín %.2f (face da parede 20.25)" % min_z)
	_check(is_finite(_player.global_position.z), "posição finita depois de golpes na parede")
	wall.queue_free()
	await _seconds(0.5)

	# Rastro e sons existem.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _attack_tap()
	var trail_max := 0
	for i in int(0.6 / DT):
		await physics_frame
		trail_max = maxi(trail_max, fx.trail_samples())
	_check(trail_max >= 2, "rastro da katana é gerado durante o golpe", "%d amostras" % trail_max)
	_check(fx._swish_streams.size() == 3 and fx._hit_heavy != null, "sons provisórios sintetizados prontos")
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.5)


# --- H2.1: golpe autoral "Kesa avançado" ------------------------------------------------

## Posição de um osso no mundo (pose final, depois dos modificadores).
func _bone_world(bone_name: String) -> Vector3:
	var sk := _player.visual.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone_name)).origin


func _test_h21() -> void:
	print("-- H2.1: golpe autoral Kesa avançado")
	var c := _player.combat
	var vis: HumanoidVisual = _player.visual
	var sk := vis.skeleton
	var s1 := c.combo.strikes[0]
	_check(s1.clip_resource != null and s1.authored_grip, "golpe 1 usa clipe autoral próprio com empunhadura de duas mãos")
	_check(vis.anim_player.has_animation(&"Katana_0") and absf(vis.anim_player.get_animation(&"Katana_0").length - s1.clip_length()) < 0.02, "clipe do golpe 1 carregado no AnimationPlayer", "%.3f s" % vis.anim_player.get_animation(&"Katana_0").length)
	_check(absf(s1.advance_distance - 0.9) < 0.001 and absf(s1.advance_start - 3.0 / 60.0) < 0.001 and absf(s1.advance_end - 15.0 / 60.0) < 0.001, "avanço do golpe 1 igual ao autorado no Blender (0,9 m, quadros 3 a 15)")

	# Medições durante o golpe (pose final da tela via skeleton_updated).
	await _seconds(0.7)
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	var samples: Array = []
	var record := func() -> void:
		if not c.is_attacking():
			return
		var inv := _player.global_transform.affine_inverse()
		var seg := vis.blade_segment()
		samples.append({
			"t": c.time, "phase": c.phase,
			"tip": inv * seg[1],
			"pelvis_y": (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("pelvis")).origin).y,
			"hands": _bone_world("hand_r").distance_to(_bone_world("hand_l")),
			"foot_r": _bone_world("foot_r"),
			"grip": vis.katana.basis.get_rotation_quaternion().angle_to(Quaternion(HumanoidVisual.STRIKE_GRIP)),
		})
	sk.skeleton_updated.connect(record)
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	sk.skeleton_updated.disconnect(record)
	_check(samples.size() > 20, "amostras do golpe 1", "%d" % samples.size())
	var active := samples.filter(func(s): return s["phase"] == CombatController.Phase.ACTIVE)
	_check(active.size() >= 3, "fase de contato amostrada", "%d" % active.size())
	if active.size() >= 3:
		var a0: Vector3 = active.front()["tip"]
		var a1: Vector3 = active.back()["tip"]
		# Espaço local do jogador: frente = -Z, esquerda = -X, cima = +Y.
		_check(a0.y - a1.y > 0.4, "corte descendente: a ponta desce no contato", "%.2f m" % (a0.y - a1.y))
		_check(a0.x - a1.x > 0.3, "corte diagonal: a ponta vai da direita para a esquerda", "%.2f m" % (a0.x - a1.x))
		var max_gap := 0.0
		for s: Dictionary in active:
			max_gap = maxf(max_gap, s["hands"])
		_check(max_gap < 0.2, "duas mãos no cabo durante o contato", "distância máx %.2f m" % max_gap)
		var grip_err := 0.0
		for s: Dictionary in active:
			grip_err = maxf(grip_err, s["grip"])
		_check(rad_to_deg(grip_err) < 10.0, "empunhadura de golpe ativa no contato", "%.1f°" % rad_to_deg(grip_err))
	var start_pelvis: float = samples.front()["pelvis_y"]
	var low_pelvis := INF
	for s: Dictionary in samples:
		low_pelvis = minf(low_pelvis, s["pelvis_y"])
	_check(start_pelvis - low_pelvis > 0.05, "transferência de peso: o quadril desce no corte", "%.2f m" % (start_pelvis - low_pelvis))
	# Pé da frente plantado depois do passo (quadros 10 a 20): não escorrega com o avanço da cápsula.
	var planted := samples.filter(func(s): return s["t"] >= 10.0 / 60.0 and s["t"] <= 20.0 / 60.0)
	var drift := 0.0
	if planted.size() >= 2:
		var p0: Vector3 = planted.front()["foot_r"]
		for s: Dictionary in planted:
			var p: Vector3 = s["foot_r"]
			drift = maxf(drift, Vector2(p.x - p0.x, p.z - p0.z).length())
	_check(planted.size() >= 2 and drift < 0.08, "pé da frente plantado durante o avanço (sem escorregar)", "deriva %.3f m" % drift)
	await _seconds(0.3)
	_check(vis.katana.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY) < deg_to_rad(3.0), "depois do golpe a katana volta à empunhadura de corrida aprovada")

	# Resposta: do aperto ao contato no boneco.
	await _seconds(0.5)
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.5)
	var hits0 := (_main.get("dummy") as TrainingDummy).hits.size()
	await _attack_tap()
	var to_hit := await _wait_until(func(): return (_main.get("dummy") as TrainingDummy).hits.size() > hits0, 0.6)
	_check(to_hit >= 0.0 and to_hit + 2 * DT <= 0.20, "resposta: aperto → contato em até 0,20 s", "%.3f s" % (to_hit + 2 * DT))
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.5)


# --- H2.2: Kiriage de retorno (segundo golpe autoral) ----------------------------------------

const KESA_APPROVED_SHA256 := "2a7cb0b2da3d2a9360e6b951dabd394ffd8124f3bf592790a5f87d33d0ae8e45"
const TRACK_BONES := ["pelvis", "spine_03", "hand_r", "hand_l", "foot_r", "foot_l", "upperarm_r", "upperarm_l"]


## Grava, a cada atualização final do esqueleto, a pose no espaço da cápsula (sem o avanço dela).
## Devolve a lista de amostras; chame `stop.call()` para parar de gravar.
func _start_pose_log(samples: Array) -> Callable:
	var vis: HumanoidVisual = _player.visual
	var sk := vis.skeleton
	var rec := func() -> void:
		var inv := _player.global_transform.affine_inverse()
		var s := {"swing": _player.combat.swing_id, "t": _player.combat.time, "striking": _player.combat.is_attacking(),
			"blend": vis.strike_blend(), "oneshot": bool(vis.anim_tree["parameters/Strike/active"]),
			"tip": inv * vis.blade_segment()[1],
			"grip": vis.katana.basis.get_rotation_quaternion().angle_to(Quaternion(HumanoidVisual.STRIKE_GRIP))}
		for b: String in TRACK_BONES:
			s[b] = inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(b)).origin)
		samples.append(s)
	sk.skeleton_updated.connect(rec)
	return func() -> void: sk.skeleton_updated.disconnect(rec)


## Maior deslocamento entre amostras consecutivas (m) de `key` no intervalo de índices [a, b].
func _max_step(samples: Array, key: String, a: int, b: int) -> float:
	var m := 0.0
	for i in range(maxi(a, 1), mini(b, samples.size() - 1) + 1):
		m = maxf(m, (samples[i][key] as Vector3).distance_to(samples[i - 1][key] as Vector3))
	return m


func _first_swing_change(samples: Array, swing_from: int) -> int:
	for i in range(1, samples.size()):
		if samples[i]["swing"] != swing_from and samples[i]["striking"]:
			return i
	return -1


func _test_h22() -> void:
	print("-- H2.2: Kiriage de retorno")
	var c := _player.combat
	var vis: HumanoidVisual = _player.visual
	var cruise := _player.tuning.max_speed
	var dummy := _main.get("dummy") as TrainingDummy
	var kesa := c.combo.strikes[0]
	var kiri := c.combo.strikes[1]

	# 1. Kesa isolado igual ao aprovado: clipe idêntico (hash) e dados idênticos.
	_check(FileAccess.get_sha256("res://assets/animations/katana/katana_kesa.res") == KESA_APPROVED_SHA256, "Kesa: clipe idêntico ao aprovado pelo PO (SHA-256)")
	var kesa_ok := absf(kesa.speed - 1.0) < 0.0001 and absf(kesa.active_start - 7.0 / 60.0) < 0.0001 and absf(kesa.active_end - 13.0 / 60.0) < 0.0001 \
		and absf(kesa.chain_open - 17.0 / 60.0) < 0.0001 and absf(kesa.dodge_cancel_from - 3.0 / 60.0) < 0.0001 and absf(kesa.move_cancel_from - 21.0 / 60.0) < 0.0001 \
		and absf(kesa.advance_distance - 0.9) < 0.0001 and absf(kesa.advance_start - 3.0 / 60.0) < 0.0001 and absf(kesa.advance_end - 15.0 / 60.0) < 0.0001 \
		and absf(kesa.hitstop - 0.06) < 0.0001 and not kesa.seamless_chain and not kesa.sync_swish
	_check(kesa_ok, "Kesa: tempos, avanço, hitstop e regras iguais aos aprovados")

	# Kiriage: dados coerentes e identidade própria.
	_check(String(kiri.id) == "kiriage_de_retorno" and kiri.authored_grip and kiri.seamless_chain and not kiri.mirrored, "Kiriage: clipe autoral próprio, não espelhado, encadeamento contínuo")
	_check(kiri.active_start < kiri.active_end and kiri.active_end <= kiri.chain_open and kiri.chain_open < kiri.clip_length() and kiri.dodge_cancel_from < kiri.move_cancel_from and kiri.move_cancel_from < kiri.clip_length(), "Kiriage: janelas em ordem")
	_check(kiri.clip_resource != null and kiri.clip_resource != kesa.clip_resource and absf(vis.anim_player.get_animation(&"Katana_1").length - kiri.clip_length()) < 0.02, "Kiriage: clipe próprio carregado", "%.3f s" % vis.anim_player.get_animation(&"Katana_1").length)

	# 2. Kiriage isolado (regra de execução: é o 2º golpe; sozinho sai se apertado logo depois do Kesa, já sem encadeamento contínuo).
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)
	var started: Array = []
	var on_start := func(_d: StrikeData, i: int, _s: int) -> void: started.append(i)
	c.strike_started.connect(on_start)
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.1)
	await _attack_tap()
	_check(started == [0, 1], "Kiriage isolado: apertado depois do Kesa terminar, sai como 2º golpe", str(started))
	var t_iso := await _wait_until(func(): return not c.is_attacking(), 1.5)
	c.strike_started.disconnect(on_start)
	_near(t_iso, kiri.total_real(), 0.05, "Kiriage isolado: duração real (s)")
	await physics_frame
	_check(_player.state == Player.State.MOVE, "Kiriage isolado: volta a MOVE")
	await _seconds(0.8)

	# 3-7. Kesa → Kiriage encadeado: tempo, buffer, continuidade.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)
	var log: Array = []
	var stop_log := _start_pose_log(log)
	started.clear()
	c.strike_started.connect(on_start)
	await _attack_tap()
	var swing_kesa := c.swing_id
	await _ticks(3)
	await _attack_tap()   # guardado no buffer; o Kiriage entra quando a janela do Kesa abre
	var t_chain := await _wait_until(func(): return started.size() >= 2, 1.0)
	_check(started.size() >= 2 and started[1] == 1, "Kesa → Kiriage: o segundo aperto encadeia o Kiriage")
	_near(t_chain, kesa.to_real(kesa.chain_open) - 4 * DT, 0.04, "Kesa → Kiriage: entra quando a janela de encadeamento abre (s)")
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	c.strike_started.disconnect(on_start)
	stop_log.call()
	await _seconds(0.3)
	var sw := _first_swing_change(log, swing_kesa)
	_check(sw > 12, "Kesa → Kiriage: troca de golpe registrada", "amostra %d de %d" % [sw, log.size()])
	if sw > 12:
		# Mistura: o OneShot nunca solta o corpo na troca.
		var min_blend := 1.0
		var always_active := true
		for i in range(sw - 4, mini(sw + 12, log.size())):
			min_blend = minf(min_blend, log[i]["blend"])
			always_active = always_active and log[i]["oneshot"]
		_check(always_active and min_blend > 0.9, "continuidade: o corpo não volta à locomoção na troca", "mistura mín %.2f" % min_blend)
		# 4. Empunhadura contínua.
		var grip_err := 0.0
		for i in range(sw - 6, mini(sw + 20, log.size())):
			grip_err = maxf(grip_err, log[i]["grip"])
		_check(rad_to_deg(grip_err) < 3.0, "continuidade de empunhadura: duas mãos o tempo todo (sem troca de pegada)", "%.2f°" % rad_to_deg(grip_err))
		# 5. Postura corporal: nenhum osso salta na troca.
		var worst := 0.0
		var worst_bone := ""
		for b: String in TRACK_BONES:
			var before := _max_step(log, b, sw - 14, sw - 2)
			var at := _max_step(log, b, sw - 1, sw + 3)
			var excess := at - maxf(before * 1.6, 0.012)
			if excess > worst:
				worst = excess
				worst_bone = b
		_check(worst <= 0.0, "continuidade de postura: nenhum osso salta na troca do golpe", "pior %s, excesso %.3f m" % [worst_bone, worst])
		# 6. Lâmina: sem teletransporte.
		var tip_before := _max_step(log, "tip", sw - 14, sw - 2)
		var tip_at := _max_step(log, "tip", sw - 1, sw + 3)
		_check(tip_at <= maxf(tip_before * 1.6, 0.03), "lâmina sem salto abrupto na troca do golpe", "passo na troca %.3f m, antes %.3f m" % [tip_at, tip_before])
		# (A mudança de empunhadura no início do Kesa é do golpe aprovado e fica fora desta janela.)
		var tip_cap := _max_step(log, "tip", sw - 10, sw + 25)
		_check(tip_cap < 0.30, "lâmina nunca anda mais de 0,30 m entre dois quadros em torno da troca", "%.3f m" % tip_cap)

	# 7b. Encadeamento tardio (apertado no fim da recuperação do Kesa): troca suavizada, sem estalo.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)
	log.clear()
	stop_log = _start_pose_log(log)
	await _attack_tap()
	var swing2 := c.swing_id
	await _wait_until(func(): return c.clip_time() >= 24.0 / 60.0, 1.0)
	await _attack_tap()
	await _wait_until(func(): return c.swing_id != swing2 and c.is_attacking(), 0.5)
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	stop_log.call()
	var swl := _first_swing_change(log, swing2)
	_check(swl > 12, "encadeamento tardio: Kiriage entra", "amostra %d" % swl)
	if swl > 12:
		var late_tip := _max_step(log, "tip", swl - 1, swl + 8)
		var late_bone := 0.0
		for b: String in TRACK_BONES:
			late_bone = maxf(late_bone, _max_step(log, b, swl - 1, swl + 8))
		_check(late_tip < 0.30 and late_bone < 0.20, "encadeamento tardio: troca suavizada (sem teletransporte)", "lâmina %.3f m, osso %.3f m" % [late_tip, late_bone])
	await _seconds(0.7)

	# 8-9. Acerto e erro do Kiriage; um acerto por golpe; dano e reação.
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.7)
	var hits0 := dummy.hits.size()
	var dmg0 := dummy.total_damage
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	var new_hits := dummy.hits.slice(hits0)
	_check(new_hits.size() == 2, "Kesa → Kiriage no boneco: exatamente 2 acertos (um por golpe)", "%d" % new_hits.size())
	if new_hits.size() == 2:
		_check(String(new_hits[0]["strike"]) == "kesa_avancado" and String(new_hits[1]["strike"]) == "kiriage_de_retorno", "acertos registrados com o nome de cada golpe")
		_check(new_hits[0]["swing"] != new_hits[1]["swing"], "um acerto por alvo por golpe (sem dano duplicado)")
	_near(dummy.total_damage - dmg0, kesa.damage + kiri.damage, 0.001, "dano total Kesa + Kiriage")
	await _seconds(0.8)
	await _reset_player(Vector3(0, 0.05, 5.4), PI)
	await _seconds(0.7)
	hits0 = dummy.hits.size()
	var misses0 := _player.hit_detector.total_misses
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	_check(dummy.hits.size() == hits0 and _player.hit_detector.total_misses >= misses0 + 2, "Kesa → Kiriage de costas para o boneco: dois erros, sem dano")
	await _seconds(0.8)

	# Resposta do Kiriage no boneco: do aperto (já na cadeia) ao contato.
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.7)
	hits0 = dummy.hits.size()
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	var t_contact := await _wait_until(func(): return dummy.hits.size() >= hits0 + 2, 1.0)
	_check(t_contact >= 0.0, "Kiriage acerta o boneco dentro da cadeia", "%.3f s depois do aperto" % t_contact)
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.8)

	# Tempo do comando ao INÍCIO PERCEPTÍVEL da animação (mão ou quadril mexe > 2 cm), medição.
	for idx in [0, 1]:
		await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
		await _seconds(0.7)
		if idx == 1:
			await _attack_tap()
			await _wait_until(func(): return not c.is_attacking(), 1.5)
			await _seconds(0.1)
		var pre: Array = []
		var stop_pre := _start_pose_log(pre)
		await _ticks(6)
		var base_hand: Vector3 = pre.back()["hand_r"]
		var base_pelvis: Vector3 = pre.back()["pelvis"]
		var n0 := pre.size()
		await _attack_tap()
		await _ticks(24)
		stop_pre.call()
		var perceptible := -1.0
		for i in range(n0, pre.size()):
			var moved := maxf((pre[i]["hand_r"] as Vector3).distance_to(base_hand), (pre[i]["pelvis"] as Vector3).distance_to(base_pelvis))
			if moved > 0.02:
				perceptible = (i - n0 + 1) * DT
				break
		print("  [medição] %s: aperto → início perceptível da animação: %.3f s" % ["Kesa" if idx == 0 else "Kiriage (isolado)", perceptible])
		_check(perceptible >= 0.0 and perceptible <= 0.05, "%s: aperto → início perceptível em até 0,05 s" % ("Kesa" if idx == 0 else "Kiriage isolado"), "%.3f s" % perceptible)
		await _wait_until(func(): return not c.is_attacking(), 1.5)
		await _seconds(0.7)

	# 10. Kiriage → esquiva → corrida; mira, direção e corrida depois de atacar.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)
	_key(KEY_W, true)
	await _seconds(0.5)
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return c.index == 1 and c.clip_time() >= kiri.dodge_cancel_from + 2.0 / 60.0, 1.0)
	await _tap(KEY_SPACE)
	var to_dodge := await _wait_until(func(): return _player.state == Player.State.DODGE, 0.3)
	_check(to_dodge >= 0.0 and not c.is_attacking(), "Kiriage → esquiva: cancela quando a janela abre", "%.3f s" % to_dodge)
	var dstart := _player.global_position
	await _wait_until(func(): return _player.state != Player.State.DODGE, 0.5)
	_near(dstart.distance_to(_player.global_position), _player.tuning.dodge_distance, 0.3, "Kiriage → esquiva: distância preservada (m)")
	var after_dodge := await _speed_trace(0.5)
	_check(after_dodge.min >= cruise * 0.9, "Kiriage → esquiva → corrida: velocidade da cápsula não cai", "mín %.2f" % after_dodge.min)
	_key(KEY_W, false)
	await _seconds(0.4)
	_check(vis.katana.basis.get_rotation_quaternion().angle_to(Quaternion.IDENTITY) < deg_to_rad(3.0), "depois do Kiriage + esquiva a katana volta à empunhadura de corrida")
	await _seconds(0.3)

	# Cancelamento da recuperação do Kiriage por movimento: sem travar a locomoção.
	await _reset_player(Vector3(-25, 0.05, 25), -PI / 2.0)
	await _seconds(0.7)
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return c.index == 1 and c.move_cancel_open(), 1.0)
	_key(KEY_W, true)
	await _ticks(2)
	_check(_player.state == Player.State.MOVE and not c.is_attacking(), "direção cancela a recuperação do Kiriage")
	var run2 := await _speed_trace(0.5)
	_check(run2.last >= cruise * 0.9, "corrida retomada depois do Kiriage", "%.2f" % run2.last)
	_key(KEY_W, false)
	await _seconds(0.4)

	# 11. Obstáculo: Kesa → Kiriage contra a parede.
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 0.5)
	ws.shape = box
	wall.add_child(ws)
	_main.add_child(wall)
	wall.global_position = Vector3(-25, 1.5, 20)
	await _reset_player(Vector3(-25, 0.05, 21.8), 0.0)
	await _seconds(0.7)
	var min_z := 99.0
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	for k in int(0.9 / DT):
		await physics_frame
		min_z = minf(min_z, _player.global_position.z)
	await _wait_until(func(): return not c.is_attacking(), 2.0)
	_check(min_z > 20.25 + 0.2, "Kesa → Kiriage contra a parede: não atravessa", "z mín %.2f (face da parede 20.25)" % min_z)
	wall.queue_free()
	await _seconds(0.5)

	# Direção pressionada orienta o Kiriage também (corpo vira para onde o jogador indica).
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.7)
	await _attack_tap()
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.1)
	_key(KEY_D, true)
	await _attack_tap()
	await _ticks(int(0.1 / DT))
	_key(KEY_D, false)
	var yaw_err := rad_to_deg(absf(angle_difference(_player.rotation.y, -PI / 2.0)))
	_check(c.index == 1 and yaw_err < 20.0, "direção pressionada orienta o Kiriage", "erro %.0f°" % yaw_err)
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	await _seconds(0.8)


## O hitstop não pode gastar o buffer de um aperto: o encadeamento tem de sobreviver a um acerto.
func _test_h22_buffer_hitstop() -> void:
	print("-- H2.2: buffer durante o hitstop")
	var c := _player.combat
	var dummy := _main.get("dummy") as TrainingDummy
	await _reset_player(Vector3(0, 0.05, 5.4), 0.0)
	await _seconds(0.7)
	var hits0 := dummy.hits.size()
	var started: Array = []
	var on_start := func(_d: StrikeData, i: int, _s: int) -> void: started.append(i)
	c.strike_started.connect(on_start)
	await _attack_tap()
	await _ticks(3)
	await _attack_tap()
	await _wait_until(func(): return started.size() >= 2, 1.0)
	c.strike_started.disconnect(on_start)
	_check(dummy.hits.size() >= hits0 + 1, "Kesa acerta (com hitstop) antes do encadeamento")
	_check(started.size() >= 2 and started[1] == 1, "aperto guardado sobrevive ao hitstop e encadeia o Kiriage", str(started))
	await _wait_until(func(): return not c.is_attacking(), 1.5)
	var hit_names: Array = dummy.hits.slice(hits0).map(func(h): return String(h["strike"]))
	_check(hit_names == ["kesa_avancado", "kiriage_de_retorno"], "Kesa → Kiriage no boneco: um acerto de cada golpe", str(hit_names))
	await _seconds(0.8)
