extends SceneTree
## Alcance real dos golpes contra o Instrutor, com o JOGO rodando no FPS pedido (--fixed-fps; física em 120 Hz).
## Imprime uma linha "[alcance]" por golpe: A = acertou, e = errou, em cada distância ao centro do alvo.
## tools\run_hit_reach.ps1 compara as linhas entre 30, 60, 120 e 144 FPS.
##   godot --headless --path . --fixed-fps 30 -s res://tests/hit_reach_check.gd
const DISTANCES: Array[float] = [1.4, 1.7, 1.9, 2.0, 2.05, 2.1, 2.15, 2.2, 2.25, 2.3]
var _main: Node
var _player: Player
var _ins: TrainingInstructor


func _initialize() -> void:
	_run()


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _shot(d: float, counter: bool) -> bool:
	_player.global_position = _ins.global_position + Vector3(0, 0.05, d)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	var t := CombatClock.time
	while CombatClock.time < t + 0.75:
		await process_frame
	var n := _ins.hits.size()
	if counter:
		_player.defense.grant_opportunity(CombatClock.time, DefenseController.Result.PERFECT, _ins)
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)
	t = CombatClock.time
	while CombatClock.time < t + 0.75:
		await process_frame
	return _ins.hits.size() > n


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for i in 10:
		await process_frame
	_player = _main.get("player")
	_ins = _main.get("instructor")
	_ins.enabled = false
	for spec: Array in [["kesa", false], ["contra", true]]:
		var line := "%s:" % spec[0]
		for d in DISTANCES:
			var hit: bool = await _shot(d, spec[1])
			line += " %.2f=%s" % [d, "A" if hit else "e"]
		print("[alcance] ", line)
	quit()
