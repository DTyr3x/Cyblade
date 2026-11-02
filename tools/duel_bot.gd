class_name DuelBot
extends Node
## Jogador simulado para os testes e o vídeo do confronto. Usa as MESMAS ações de entrada de um humano e
## reage ao que o robô mostra (preparação e instante do contato). Não é parte do jogo.
##
## Estilos: "parry" (parry, contra-corte e cadeia), "esquiva" (esquiva justa e cadeia), "passivo" (só apanha),
## "martelo" (ataca sem defender).

@export var style := "parry"
## Chance de acertar o tempo da defesa (1 = sempre).
@export_range(0.0, 1.0) var skill := 1.0

var duel: Node
var player: Player
var robot: RobotEnemy
var strikes_pressed := 0
var finishes_pressed := 0
var _pulses: Array[String] = []
var _answered_swing := -1
var _next_attack_t := 0.0
var _next_finish_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Antes do jogador: uma ação apertada depois dele no mesmo passo seria perdida.
	process_physics_priority = -100
	_rng.seed = 77


func _physics_process(_delta: float) -> void:
	for a in _pulses:
		Input.action_release(a)
	_pulses.clear()
	if duel == null or duel.get("flow") != 1:
		_steer(Vector3.ZERO)
		return
	var now := CombatClock.time
	var to := robot.global_position - player.global_position
	to.y = 0.0
	var d := to.length()
	if style == "passivo":
		_steer(Vector3.ZERO)
		return
	# Finalização: é um botão, e só com o robô quebrado ao alcance.
	var p := robot.posture
	if p.state == PostureController.State.BROKEN:
		if d <= p.data.finish_range:
			_steer(Vector3.ZERO)
			if now >= _next_finish_t:
				_pulse("finish")
				finishes_pressed += 1
				_next_finish_t = now + 0.25
		else:
			_steer(to.normalized())
		return
	if style != "martelo" and _answer_attack(now, to):
		return
	if player.defense.opportunity_open(now) and not player.combat.is_attacking():
		_pulse("attack")
		strikes_pressed += 1
		return
	if d > 1.9:
		_steer(to.normalized())
	else:
		_steer(Vector3.ZERO)
		if now >= _next_attack_t:
			_pulse("attack")
			strikes_pressed += 1
			_next_attack_t = now + 0.3


## Responde ao golpe em preparação. Devolve true enquanto a luta está no compasso de defesa.
func _answer_attack(now: float, to: Vector3) -> bool:
	if robot.phase != TrainingInstructor.Phase.WINDUP and robot.phase != TrainingInstructor.Phase.STRIKE:
		return false
	if robot.next_contact_time <= 0.0 or now > robot.next_contact_time + 0.05:
		return false
	var ahead := robot.next_contact_time - now
	var use_dodge := style == "esquiva" or not robot.attack.parryable
	if ahead > (0.10 if use_dodge else 0.07):
		return ahead < 0.32
	if _answered_swing != robot.swing:
		_answered_swing = robot.swing
		if _rng.randf() <= skill:
			if use_dodge:
				_steer(to.normalized().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0))
				_pulse("dodge")
			else:
				_pulse("defend")
	return true


func _pulse(action: String) -> void:
	Input.action_press(action)
	_pulses.append(action)


func _steer(dir: Vector3) -> void:
	_axis("move_right", "move_left", dir.x)
	_axis("move_down", "move_up", dir.z)


func _axis(positive: String, negative: String, v: float) -> void:
	if v > 0.02:
		Input.action_press(positive, v)
		Input.action_release(negative)
	elif v < -0.02:
		Input.action_press(negative, -v)
		Input.action_release(positive)
	else:
		Input.action_release(positive)
		Input.action_release(negative)
