class_name Player
extends CharacterBody3D
## Ninja jogável: movimento relativo à câmera, giro, aceleração, frenagem e esquiva.
##
## Estados: MOVE -> DODGE (deslocamento) -> RECOVERY (sem controle) -> MOVE; MOVE -> ATTACK (cadeia
## de golpes, ver CombatController) -> MOVE ou DODGE (cancelamento); MOVE -> GUARD (defesa e parry, ver
## DefenseController) -> MOVE; golpe inimigo recebido -> STAGGER (reação curta, a esquiva cancela).
## Prioridade no mesmo passo: esquiva > defesa > ataque.
## Física em 120 Hz; a lógica usa só `delta`, nunca a taxa de quadros de render.

signal state_changed(new_state: int)
signal dodge_started(direction: Vector3)
signal dodge_finished
## Golpe inimigo resolvido contra o jogador (parry, defesa ou golpe recebido). `info` traz resultado,
## dano, desvio de tempo, ponto de contato e a origem.
signal attacked(info: Dictionary)

enum State { MOVE, DODGE, RECOVERY, ATTACK, GUARD, STAGGER }

@export var tuning: PlayerTuning

## Guinada da câmera (rad). Quem monta a cena atualiza antes da física do jogador.
var move_yaw := 0.0
var state: State = State.MOVE
var state_time := 0.0
var dodge_direction := Vector3.ZERO

var _dodge_buffer := 0.0
var _dodge_exit_fraction := 0.0
var visual: HumanoidVisual
var combat: CombatController
var hit_detector: HitDetector
var defense: DefenseController
var vitals: CombatVitals

var _defend_buffer := 0.0
## Aperto de defesa recebido pelo evento de entrada, consumido no próximo passo de física. Mais confiável
## que `is_action_just_pressed` na física, que pode perder um toque curto entre dois passos.
var _defend_pending := false
var _defend_was_held := false
## Ataque apertado no "mesmo instante" da defesa (até um quadro de 60 Hz depois) é descartado: a defesa
## tem prioridade, mesmo que os dois eventos cheguem à física em passos vizinhos.
const SAME_INSTANT := 0.02
var _attack_ignore_until := -1.0
## Hitstop local do jogador (relógio de combate): congela corpo e buffers, nenhum aperto se perde.
var _freeze_until := -1.0
var _push_vel := Vector3.ZERO
var _push_left := 0.0


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	floor_snap_length = 0.4
	visual = HumanoidVisual.new()
	add_child(visual)
	visual.bind(self)
	combat = CombatController.new()
	combat.name = "Combat"
	add_child(combat)
	visual.setup_strikes(combat.combo)
	combat.strike_started.connect(_on_strike_started)
	combat.strike_ended.connect(_on_strike_ended)
	hit_detector = HitDetector.new(combat, visual)
	hit_detector.name = "HitDetector"
	add_child(hit_detector)
	defense = DefenseController.new()
	defense.name = "Defense"
	add_child(defense)
	vitals = CombatVitals.new()
	vitals.name = "Vitals"
	add_child(vitals)
	add_to_group(&"jogador")


func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func is_invulnerable() -> bool:
	return state == State.DODGE \
		and state_time >= tuning.dodge_iframe_start \
		and state_time <= tuning.dodge_iframe_end


func _physics_process(delta: float) -> void:
	var now := CombatClock.time
	var defend_held := Input.is_action_pressed("defend")
	# Aperto = evento recebido OU borda de "segurado" (cobre ações acionadas sem evento, como
	# Input.action_press de controles virtuais). Os dois no mesmo passo contam como um aperto só.
	var defend_pressed := _defend_pending or (defend_held and not _defend_was_held)
	_defend_pending = false
	_defend_was_held = defend_held
	if now < _freeze_until:
		# Hitstop local (parry ou defesa): o corpo congela e os apertos ficam guardados sem expirar.
		if Input.is_action_just_pressed("dodge"):
			_dodge_buffer = tuning.dodge_buffer_time
		if Input.is_action_just_pressed("attack"):
			combat.press_attack()
		if defend_pressed:
			_defend_buffer = defense.data.input_buffer
		if not defend_held and defense.guarding:
			defense.release(now)
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if Input.is_action_just_pressed("dodge"):
		_dodge_buffer = tuning.dodge_buffer_time
	else:
		_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	if defend_pressed:
		_defend_buffer = defense.data.input_buffer
		defense.note_input(now)
	else:
		_defend_buffer = maxf(_defend_buffer - delta, 0.0)
	if not defend_held and defense.guarding:
		defense.release(now)
	if Input.is_action_just_pressed("attack") and now > _attack_ignore_until:
		combat.press_attack()
	if state != State.ATTACK:
		combat.tick(delta)   # relógio do combate fora de um golpe: buffer expira e o reinício da cadeia conta
	defense.update(now)
	defense.update_opportunity(now)
	vitals.tick(delta)

	match state:
		State.MOVE:
			_tick_move(delta)
		State.DODGE:
			_tick_dodge(delta)
		State.RECOVERY:
			_tick_recovery(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.GUARD:
			_tick_guard(delta)
		State.STAGGER:
			_tick_stagger(delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= tuning.gravity * delta
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("defend") and not event.is_echo():
		_defend_pending = true


func _process(delta: float) -> void:
	var now := CombatClock.time
	visual.set_guard(state == State.GUARD or (state == State.MOVE and defense.perfect_open(now)))
	visual.update_pose(delta, velocity, -global_transform.basis.z, tuning.max_speed, state == State.DODGE)


func _input_direction() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return Vector3(v.x, 0.0, v.y).rotated(Vector3.UP, move_yaw)


func _tick_move(delta: float) -> void:
	var dir := _input_direction()
	if _dodge_buffer > 0.0:
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	if _try_start_defense():
		_tick_guard(delta)
		return
	if _try_start_attack():
		_tick_attack(delta)
		return
	_locomote(dir, delta)


## Locomoção normal: acelera/freia rumo à entrada e gira o corpo. Usada em MOVE e, quando a
## recuperação não trava o movimento, também em RECOVERY.
func _locomote(dir: Vector3, delta: float) -> void:
	var target := dir * tuning.max_speed
	var h := MotionMath.approach_velocity(horizontal_velocity(), target, tuning.accel(), tuning.decel(), tuning.reverse_accel_multiplier, delta)
	velocity.x = h.x
	velocity.z = h.z
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(tuning.turn_rate_deg) * delta)


func _start_dodge(input_dir: Vector3) -> void:
	var dir := input_dir
	if dir.length() < 0.1:
		dir = -global_transform.basis.z
	dodge_direction = Vector3(dir.x, 0.0, dir.z).normalized()
	# Só termina em velocidade de corrida se o jogador está dirigindo; parado, termina parado.
	_dodge_exit_fraction = 0.0
	if input_dir.length() >= 0.1:
		_dodge_exit_fraction = clampf(tuning.dodge_exit_speed_ratio * tuning.max_speed * tuning.dodge_duration / tuning.dodge_distance, 0.0, 1.0)
	rotation.y = atan2(-dodge_direction.x, -dodge_direction.z)
	_dodge_buffer = 0.0
	_enter(State.DODGE, 0.0)
	dodge_started.emit(dodge_direction)


func _tick_dodge(delta: float) -> void:
	var t0 := state_time
	var t1 := minf(state_time + delta, tuning.dodge_duration)
	var d0 := MotionMath.dodge_distance_at(t0 / tuning.dodge_duration, tuning.dodge_distance, _dodge_exit_fraction)
	var d1 := MotionMath.dodge_distance_at(t1 / tuning.dodge_duration, tuning.dodge_distance, _dodge_exit_fraction)
	var v := dodge_direction * ((d1 - d0) / delta)
	velocity.x = v.x
	velocity.z = v.z
	state_time += delta
	# Tolerância de ponto flutuante: sem ela, state_time = 0,2499999 gasta um tick extra com
	# velocidade zero (d1 - d0 = 0) e cria uma parada de 1 tick entre a esquiva e a corrida.
	if state_time >= tuning.dodge_duration - 0.0001:
		_enter(State.RECOVERY, maxf(state_time - tuning.dodge_duration, 0.0))
		dodge_finished.emit()


func _tick_recovery(delta: float) -> void:
	if tuning.dodge_recovery_locks_movement:
		var h := MotionMath.approach_velocity(horizontal_velocity(), Vector3.ZERO, tuning.accel(), tuning.decel(), 1.0, delta)
		velocity.x = h.x
		velocity.z = h.z
	else:
		_locomote(_input_direction(), delta)
	state_time += delta
	if _try_start_defense():
		return
	if _try_start_attack():
		return
	if state_time >= tuning.dodge_recovery:
		_enter(State.MOVE, 0.0)


func _enter(new_state: State, carry: float) -> void:
	state = new_state
	state_time = carry
	state_changed.emit(new_state)


# --- Ataque ---------------------------------------------------------------------------

## Começa (ou encadeia) um golpe se há ataque guardado. A esquiva tem prioridade sobre o ataque.
func _try_start_attack() -> bool:
	if _dodge_buffer > 0.0 or not combat.has_buffered_attack():
		return false
	# Contra-ataque de oportunidade: só com a oportunidade aberta por um parry perfeito (um J manual, nunca
	# automático). Gasta a oportunidade ao COMEÇAR. Fora dela, a cadeia normal vale como antes.
	var now := CombatClock.time
	if defense.opportunity_open(now) and not combat.is_attacking() and combat.has_buffered_attack():
		if defense.consume_opportunity(now) and combat.start_counter():
			_enter(State.ATTACK, 0.0)
			return true
	if combat.try_start(true):
		_enter(State.ATTACK, 0.0)
		return true
	return false


func _on_strike_started(data: StrikeData, index: int, _swing: int) -> void:
	visual.play_strike(data, index, combat.chained_from, combat.chained_from_clip_time)
	_aim_for_strike(data)


func _on_strike_ended(_data: StrikeData, _completed: bool) -> void:
	# Num encadeamento o corpo não volta à locomoção entre os dois golpes: o próximo `play_strike` assume.
	if combat.chaining:
		return
	visual.end_strike()


## Gira o corpo logo na saída para a direção pressionada ou, sem direção, para o alvo mais próximo
## na frente (assistência de mira). O giro continua na preparação (turn_lock), então o golpe sai
## na direção que o jogador mostrou, sem esperar a animação.
func _aim_for_strike(data: StrikeData) -> void:
	var dir := _input_direction()
	if dir.length() < 0.1:
		dir = _assist_direction()
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		var max_step := deg_to_rad(data.turn_rate_deg) * 0.04
		rotation.y = rotate_toward(rotation.y, target_yaw, max_step)


func _assist_direction() -> Vector3:
	var best := Vector3.ZERO
	var best_d := combat.combo.aim_assist_range
	var fwd := -global_transform.basis.z
	for t: Node in get_tree().get_nodes_in_group(HitDetector.HURTBOX_GROUP):
		var to := (t as Node3D).global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > best_d:
			continue
		if rad_to_deg(fwd.angle_to(to.normalized())) > combat.combo.aim_assist_angle_deg:
			continue
		best_d = d
		best = to.normalized()
	return best


func _tick_attack(delta: float) -> void:
	var dir := _input_direction()
	# Cancelamento por esquiva: vale assim que a janela do golpe abre.
	if _dodge_buffer > 0.0 and combat.dodge_cancel_open():
		combat.cancel()
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	# Cancelamento por defesa: usa a mesma janela da esquiva (os golpes aprovados não mudam).
	if _defend_buffer > 0.0 and combat.dodge_cancel_open():
		combat.cancel()
		_try_start_defense()
		_tick_guard(delta)
		return
	# Encadeamento: ataque guardado + janela aberta.
	if combat.has_buffered_attack() and combat.try_start(true):
		state_time = 0.0
	# Cancelamento da recuperação por movimento: o jogador nunca fica preso depois de atacar.
	if combat.move_cancel_open() and dir.length() > 0.1:
		combat.cancel()
		_enter(State.MOVE, 0.0)
		_locomote(dir, delta)
		return
	var data := combat.current
	var steering := not combat.in_hitstop() and combat.clip_time() < data.turn_lock
	if steering:
		var aim := dir
		if aim.length() < 0.1:
			aim = _assist_direction()
		if aim.length() > 0.1:
			rotation.y = rotate_toward(rotation.y, atan2(-aim.x, -aim.z), deg_to_rad(data.turn_rate_deg) * delta)
	var t0 := combat.time
	var finished := combat.tick(delta)
	var advance := combat.advance_between(t0, combat.time)
	var forward := -global_transform.basis.z
	if combat.in_hitstop():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		# O momento de corrida é absorvido pela frenagem normal; o avanço do golpe vem por cima.
		var target := forward * (advance / delta)
		var h := MotionMath.approach_velocity(horizontal_velocity(), target, tuning.accel(), tuning.decel(), 1.0, delta)
		velocity.x = h.x
		velocity.z = h.z
	state_time += delta
	if finished or not combat.is_attacking():
		_enter(State.MOVE, 0.0)


# --- Defesa e parry (C1) ---------------------------------------------------------------------

## Entra na guarda se há aperto de defesa guardado (abre a janela de parry) ou se o botão continua
## segurado (guarda sem janela, por exemplo depois de um golpe). A esquiva tem prioridade; um ataque
## apertado no mesmo passo é descartado (defesa > ataque).
func _try_start_defense() -> bool:
	if _dodge_buffer > 0.0:
		return false
	var now := CombatClock.time
	if _defend_buffer > 0.0:
		_defend_buffer = 0.0
		combat.consume_buffer()
		defense.press(now)
		_attack_ignore_until = now + SAME_INSTANT
		_enter(State.GUARD, 0.0)
		return true
	if defense.guarding and Input.is_action_pressed("defend"):
		_enter(State.GUARD, 0.0)
		return true
	return false


func _tick_guard(delta: float) -> void:
	var now := CombatClock.time
	var dir := _input_direction()
	if _dodge_buffer > 0.0:
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	if _defend_buffer > 0.0:
		# Novo aperto já de guarda: nova tentativa de parry (respeita o bloqueio de parry em falso).
		_defend_buffer = 0.0
		defense.press(now)
	if not defense.in_block_recovery(now):
		if _try_start_attack():
			_tick_attack(delta)
			return
		if not defense.guarding:
			_enter(State.MOVE, 0.0)
			_locomote(dir, delta)
			return
	# Andar de guarda: mais devagar, virado para o inimigo mais próximo (ou para a direção pressionada).
	var target := dir * defense.data.guard_move_speed
	var h := MotionMath.approach_velocity(horizontal_velocity(), target, tuning.accel(), tuning.decel(), tuning.reverse_accel_multiplier, delta)
	if _push_left > 0.0:
		_push_left = maxf(_push_left - delta, 0.0)
		h = _push_vel
	velocity.x = h.x
	velocity.z = h.z
	var face := _nearest_enemy_direction(6.0)
	if face.length() < 0.1:
		face = dir
	if face.length() > 0.1:
		rotation.y = rotate_toward(rotation.y, atan2(-face.x, -face.z), deg_to_rad(tuning.turn_rate_deg) * delta)
	state_time += delta


## Reação a golpe recebido: curta, a esquiva cancela; defesa e ataque ficam no buffer.
func _tick_stagger(delta: float) -> void:
	var dir := _input_direction()
	if _dodge_buffer > 0.0:
		_start_dodge(dir)
		_tick_dodge(delta)
		return
	var h := MotionMath.approach_velocity(horizontal_velocity(), Vector3.ZERO, tuning.accel(), tuning.decel(), 1.0, delta)
	if _push_left > 0.0:
		_push_left = maxf(_push_left - delta, 0.0)
		h = _push_vel
	velocity.x = h.x
	velocity.z = h.z
	state_time += delta
	if state_time >= defense.data.hit_reaction:
		_enter(State.MOVE, 0.0)


func _nearest_enemy_direction(max_dist: float) -> Vector3:
	var best := Vector3.ZERO
	var best_d := max_dist
	for e: Node in get_tree().get_nodes_in_group(&"inimigo"):
		var to := (e as Node3D).global_position - global_position
		to.y = 0.0
		if to.length() > 0.01 and to.length() < best_d:
			best_d = to.length()
			best = to.normalized()
	return best


## Golpe inimigo chegando ao jogador no instante `t` (relógio de combate). Decide parry, defesa ou
## golpe recebido e aplica as consequências. Devolve o resultado para o atacante.
func receive_enemy_attack(attack: EnemyAttackData, t: float, source: Node3D) -> Dictionary:
	if is_invulnerable():
		return {"result": -1, "evaded": true, "hitstop": 0.0}
	var away := global_position - source.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_transform.basis.z
	var can_defend := state in [State.GUARD, State.MOVE, State.RECOVERY]
	var info: Dictionary
	if can_defend and attack.parryable:
		info = defense.resolve(t, attack.damage)
	else:
		info = {"result": DefenseController.Result.HIT, "damage": attack.damage, "offset": t - defense._press_t, "time": t}
		defense.last_result = DefenseController.Result.HIT
	var d := defense.data
	var hitstop := 0.0
	match int(info["result"]):
		DefenseController.Result.PERFECT:
			hitstop = d.parry_hitstop
			visual.play_deflect()
			defense.grant_opportunity(t, DefenseController.Result.PERFECT, source)
			info["posture_pressure"] = d.parry_posture_pressure
			vitals.add_neural_energy(d.parry_neural_energy)
		DefenseController.Result.BLOCK:
			hitstop = d.block_hitstop
			vitals.damage(float(info["damage"]))
			_push_vel = away * (d.block_pushback / maxf(d.block_pushback_time, 0.01))
			_push_left = d.block_pushback_time
			if state != State.GUARD:
				_enter(State.GUARD, 0.0)
		_:
			vitals.damage(float(info["damage"]))
			if state == State.ATTACK:
				combat.cancel()
			_push_vel = away * (d.hit_knockback / 0.12)
			_push_left = 0.12
			_enter(State.STAGGER, 0.0)
	if hitstop > 0.0:
		_freeze_until = CombatClock.time + hitstop
		visual.freeze(hitstop)
	info["hitstop"] = hitstop
	info["source"] = source
	info["point"] = _contact_point(source, away)
	info["away"] = away
	attacked.emit(info)
	return info


## Ponto onde as lâminas se encontram: meio do menor segmento entre a katana do jogador e a lâmina do
## Instrutor. Se estiverem longe (pose ainda a caminho), cai para um ponto à frente do peito.
func _contact_point(source: Node3D, away: Vector3) -> Vector3:
	var fallback := global_position + Vector3.UP * 1.25 - away * 0.45
	if source is TrainingInstructor and visual.katana != null:
		var ins := source as TrainingInstructor
		var mine := visual.blade_segment()
		var theirs: Array[Vector3] = [ins.blade_base(), ins.blade_tip()]
		var pts := Geometry3D.get_closest_points_between_segments(mine[0], mine[1], theirs[0], theirs[1])
		if pts[0].distance_to(pts[1]) < 0.9:
			return (pts[0] + pts[1]) * 0.5
	return fallback
