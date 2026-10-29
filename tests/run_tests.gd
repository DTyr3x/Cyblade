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
	_check(sway < sway_clip * 0.5, "braço da katana mais firme que o clipe cru", "%.3f m" % sway)
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
