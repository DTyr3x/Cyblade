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
