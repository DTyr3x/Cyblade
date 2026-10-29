class_name DebugHud
extends CanvasLayer
## HUD de depuração: FPS, tempos de quadro, parâmetros da câmera e do jogador.
## F3 (ou Back no gamepad) liga/desliga.

const REFRESH_SECONDS := 0.1
const RECENT_FRAMES := 240
const HINT_TEXT := "Teclado: WASD mover · J ou mouse esq. atacar · K defesa · Espaço esquiva · Q/E ou botão direito+mouse girar câmera · R centralizar · 1/2/3 enquadramento · F3 HUD · Esc sair\nGamepad: stick esq. mover · X atacar · LB defesa · B esquiva · stick dir. girar câmera · R3 centralizar · ←/→ enquadramento · Back HUD"

var camera_rig: CameraRig
var player: Player
var stats: FrameStats
var last_device := "nenhum"

var _panel: PanelContainer
var _label: Label
var _hint: Label
var _accum := REFRESH_SECONDS


func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "monospace"])

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.72)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_panel.add_child(_label)
	add_child(_panel)

	_hint = Label.new()
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.text = HINT_TEXT
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 12
	_hint.offset_top = -54
	add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_panel.visible = not _panel.visible


func _process(delta: float) -> void:
	_accum += delta
	if _accum < REFRESH_SECONDS or not _panel.visible:
		return
	_accum = 0.0
	_label.text = _build_text()


## Linhas do modo de depuração do combate: golpe, fase, relógio, buffer e últimos contatos.
func _combat_text() -> String:
	var c := player.combat
	var d := player.hit_detector
	var phase: String = CombatController.Phase.keys()[c.phase]
	var name_s := String(c.current.id) if c.current != null and c.is_attacking() else "-"
	var line := "Combate: %s [%s] t %.2f s  buffer %s  acertos %d  erros %d" % [name_s, phase, c.time, "sim" if c.has_buffered_attack() else "não", d.total_hits, d.total_misses]
	for e in d.event_log.slice(maxi(d.event_log.size() - 3, 0)):
		line += "\n  · %s %s golpe#%s%s" % [e.get("event"), e.get("strike"), e.get("swing"), (" dano %.0f" % e["damage"]) if e.has("damage") else ""]
	line += "\n" + _defense_text()
	return line


## Defesa (C1): estado, último resultado com o desvio em ms, vida de treino e contadores.
func _defense_text() -> String:
	var df := player.defense
	var now := CombatClock.time
	var names := ["PARRY", "DEFESA", "GOLPE RECEBIDO"]
	var last := "-"
	if df.last_result >= 0:
		last = "%s %+d ms" % [names[df.last_result], int(round(df.last_offset * 1000.0))]
		if df.last_result == DefenseController.Result.HIT and df.last_late_by >= 0.0:
			last += " (apertou %d ms tarde)" % int(round(df.last_late_by * 1000.0))
	var flags := ""
	if df.perfect_open(now):
		flags += " [janela]"
	if df.in_lockout(now):
		flags += " [parry bloqueado: em falso]"
	var v := player.vitals
	var ins_s := ""
	var main := get_parent()
	if main != null and main.get("instructor") != null:
		var ins: TrainingInstructor = main.get("instructor")
		ins_s = "  Instrutor: %s  pressão de postura %.0f" % [TrainingInstructor.Phase.keys()[ins.phase], ins.posture_pressure]
	return "Defesa: %s%s  último: %s  em falso: %d\nVida %.0f  Energia Neural %.0f%s" % ["GUARDA" if player.state == Player.State.GUARD else "-", flags, last, df.whiff_count, v.health, v.neural_energy, ins_s]


func player_screen_height_percent() -> float:
	if camera_rig == null or camera_rig.camera == null or player == null:
		return 0.0
	var cam := camera_rig.camera
	var feet := player.global_position
	var head := feet + Vector3.UP * 1.75
	var screen_h := get_viewport().get_visible_rect().size.y
	return absf(cam.unproject_position(head).y - cam.unproject_position(feet).y) / screen_h * 100.0


func _build_text() -> String:
	var lines: PackedStringArray = []
	lines.append("CYBLADE · Marco 1 (protótipo)")
	var s := stats.recent(RECENT_FRAMES) if stats != null else {}
	if not s.is_empty():
		lines.append("FPS %5.0f   quadro %.2f ms (pior %.2f ms)" % [s["avg_fps"], s["avg_ms"], s["max_ms"]])
		lines.append("1%% baixo %5.0f fps (últimos %d quadros)" % [s["low1_fps"], s["frames"]])
		var r := stats.render_summary()
		if r.has("gpu_avg_ms"):
			lines.append("Render GPU %.2f ms · CPU %.2f ms (médias da sessão)" % [r["gpu_avg_ms"], r["cpu_avg_ms"]])
	lines.append("Dispositivo: %s" % last_device)
	if camera_rig != null:
		var c := camera_rig.state()
		lines.append("Câmera [%s] incl. %.1f° dist %.1f m fov %.1f° tau %.2f s yaw %.0f°" % [c["preset"], c["pitch_deg"], c["distance"], c["fov_deg"], c["follow_tau"], c["yaw_deg"]])
	if player != null:
		lines.append("Jogador: %s  vel %.2f m/s  i-frames: %s" % [Player.State.keys()[player.state], player.horizontal_velocity().length(), "sim" if player.is_invulnerable() else "não"])
		lines.append("Altura na tela: %.1f %% (referência Dinghai ~9–11 %%)" % player_screen_height_percent())
		if player.combat != null:
			lines.append(_combat_text())
	return "\n".join(lines)
