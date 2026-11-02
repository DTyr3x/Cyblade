extends "res://game/main.gd"
## Confronto do vertical slice: ENTRAR ─► ENFRENTAR ─► VENCER OU PERDER ─► REINICIAR.
## A base (jogador, câmera, efeitos, relógio de combate) é a mesma do treino; aqui entram o robô, a vida de
## verdade e o fluxo da luta.

enum Flow { INTRO, FIGHT, VICTORY, DEFEAT }

const TRAINING_SCENE := "res://game/main.tscn"
const BEST_FILE := "user://melhor_tempo.cfg"
const PLAYER_MAX_HEALTH := 120.0
## A Cravada devolve vida: a recompensa tática de quem finaliza em vez de só bater.
const FINISH_HEAL := 25.0

var flow := Flow.INTRO
var robot: RobotEnemy
var duel_hud: DuelHud
var fight_time := 0.0
var parries := 0
var evades := 0
var damage_taken := 0.0


func _ready() -> void:
	super._ready()
	hud.set_panel_visible(false)
	player.global_position = DuelArena.PLAYER_START
	camera_rig.snap()
	var v := player.vitals
	v.training = false
	v.regen_rate = 0.0
	v.max_health = PLAYER_MAX_HEALTH
	v.health = PLAYER_MAX_HEALTH
	v.defeated.connect(_on_player_defeated)
	v.changed.connect(_on_player_health)
	player.attacked.connect(_on_attacked)
	player.finish_landed.connect(func(_target: Node3D) -> void: v.heal(FINISH_HEAL))
	duel_hud = DuelHud.new()
	duel_hud.name = "HudConfronto"
	add_child(duel_hud)
	robot.health_changed.connect(func(h: float) -> void: duel_hud.set_robot_health(h / robot.max_health))
	robot.evade_credited.connect(func() -> void: evades += 1)
	robot.defeated.connect(_on_robot_defeated)
	duel_hud.show_message("CYBLADE", "Enter ou Start: lutar   ·   T: treino\nWASD mover · J atacar · K defesa e parry · Espaço esquiva · F Cravada no inimigo quebrado")


func _spawn_opponents() -> void:
	robot = RobotEnemy.new()
	robot.name = "Robo"
	robot.enabled = false
	add_child(robot)
	robot.global_position = DuelArena.ROBOT_START
	robot.rotation.y = 0.0
	robot.target = player
	instructor = robot


func _process(delta: float) -> void:
	super._process(delta)
	if flow == Flow.FIGHT:
		fight_time += delta
	elif Input.is_action_just_pressed("confirm"):
		if flow == Flow.INTRO:
			start_fight()
		else:
			get_tree().reload_current_scene()
	elif Input.is_action_just_pressed("training"):
		get_tree().change_scene_to_file(TRAINING_SCENE)


func start_fight() -> void:
	flow = Flow.FIGHT
	robot.enabled = true
	duel_hud.show_message("")


func _on_player_health() -> void:
	duel_hud.set_player_health(player.vitals.health / player.vitals.max_health)


func _on_attacked(info: Dictionary) -> void:
	if int(info.get("result", -1)) == DefenseController.Result.PERFECT:
		parries += 1
	else:
		damage_taken += float(info.get("damage", 0.0))


func _on_player_defeated() -> void:
	flow = Flow.DEFEAT
	robot.enabled = false
	duel_hud.show_message("DERROTA", "Enter ou Start: tentar de novo   ·   T: treino")


func _on_robot_defeated() -> void:
	flow = Flow.VICTORY
	var best := _save_best(fight_time)
	var line := "Tempo %s   ·   Parries %d   ·   Esquivas justas %d   ·   Cravadas %d   ·   Dano recebido %.0f" % [_clock(fight_time), parries, evades, robot.posture.finishes, damage_taken]
	duel_hud.show_message("VITÓRIA", "%s\nMelhor tempo %s\n\nEnter ou Start: lutar de novo   ·   T: treino" % [line, _clock(best)])


func _clock(seconds: float) -> String:
	return "%d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60.0)]


## Grava o melhor tempo e devolve o valor em vigor.
func _save_best(seconds: float) -> float:
	var cfg := ConfigFile.new()
	cfg.load(BEST_FILE)
	var best := minf(float(cfg.get_value("confronto", "melhor_tempo", INF)), seconds)
	cfg.set_value("confronto", "melhor_tempo", best)
	cfg.save(BEST_FILE)
	return best
