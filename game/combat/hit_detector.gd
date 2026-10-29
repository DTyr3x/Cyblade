class_name HitDetector
extends Node
## Detecção de acerto da lâmina. Durante a fase ACTIVE de um golpe, varre o segmento da lâmina
## (entre o tick anterior e o atual, em passos) contra os alvos do grupo "hurtbox".
## Cada alvo só pode ser acertado UMA vez por golpe (`swing_id`).
##
## Não aplica efeitos: emite `hit` com os dados e chama `receive_hit` do alvo.

signal hit(info: Dictionary)
signal swing_finished(swing_id: int, hits: int)

const HURTBOX_GROUP := &"hurtbox"
## Passos de varredura entre dois instantes de amostragem (lâmina rápida não atravessa o alvo).
const SWEEP_STEPS := 5

var controller: CombatController
var visual: HumanoidVisual

var _prev: Array[Vector3] = []
var _hit_ids := {}   # {swing_id: {alvo_id: true}}
var _hits_in_swing := 0
var _swing_for_count := -1
## Registro de depuração (últimos eventos), lido pelo HUD e pelos testes.
var event_log: Array[Dictionary] = []
var total_hits := 0
var total_misses := 0


func _init(ctrl: CombatController = null, vis: HumanoidVisual = null) -> void:
	controller = ctrl
	visual = vis


func _ready() -> void:
	if controller != null:
		controller.strike_started.connect(_on_started)
		controller.strike_ended.connect(_on_ended)


func _on_started(_data: StrikeData, _i: int, swing_id: int) -> void:
	_prev.clear()
	_swing_for_count = swing_id
	_hits_in_swing = 0
	_hit_ids[swing_id] = {}
	if _hit_ids.size() > 8:
		_hit_ids.erase(_hit_ids.keys()[0])


func _on_ended(data: StrikeData, _completed: bool) -> void:
	if _hits_in_swing == 0:
		total_misses += 1
		_push_log({"event": "erro", "strike": String(data.id), "swing": _swing_for_count})
	swing_finished.emit(_swing_for_count, _hits_in_swing)


func _physics_process(_delta: float) -> void:
	if controller == null or visual == null or controller.phase != CombatController.Phase.ACTIVE:
		_prev.clear()
		return
	if controller.in_hitstop():
		return
	var data := controller.current
	var seg := visual.blade_segment(data.blade_from, data.blade_to)
	if _prev.is_empty():
		_prev = seg
	for step in range(1, SWEEP_STEPS + 1):
		var f := step / float(SWEEP_STEPS)
		var a := _prev[0].lerp(seg[0], f)
		var b := _prev[1].lerp(seg[1], f)
		for target: Node in get_tree().get_nodes_in_group(HURTBOX_GROUP):
			if not target.has_method("segment_hit"):
				continue
			var done: Dictionary = _hit_ids.get(controller.swing_id, {})
			var tid := target.get_instance_id()
			if done.has(tid):
				continue
			var point: Vector3 = target.segment_hit(a, b, data.hit_radius)
			if point.is_finite():
				done[tid] = true
				_hit_ids[controller.swing_id] = done
				_register_hit(target, point, data)
	_prev = seg


func _register_hit(target: Node, point: Vector3, data: StrikeData) -> void:
	_hits_in_swing += 1
	total_hits += 1
	var from_dir: Vector3 = (target as Node3D).global_position - visual.global_position
	from_dir.y = 0.0
	var info := {
		"event": "acerto",
		"target": target,
		"point": point,
		"strike": String(data.id),
		"index": controller.index,
		"swing": controller.swing_id,
		"damage": data.damage,
		"knockback": data.knockback,
		"reaction": data.reaction,
		"direction": from_dir.normalized(),
		"hitstop": data.hitstop,
		"camera_shake": data.camera_shake,
	}
	_push_log({"event": "acerto", "strike": String(data.id), "swing": controller.swing_id, "damage": data.damage})
	controller.start_hitstop(data.hitstop)
	target.receive_hit(info)
	hit.emit(info)


func _push_log(entry: Dictionary) -> void:
	entry["t"] = snappedf(Time.get_ticks_msec() / 1000.0, 0.001)
	event_log.append(entry)
	if event_log.size() > 12:
		event_log.pop_front()
