class_name DuelArena
extends TestArena
## Arena do confronto: a mesma base visual da arena de testes, reduzida a um pátio limpo e fechado. Sem
## obstáculos, para a luta ficar legível de cima e o robô não precisar desviar de nada.

const DUEL_HALF_SIZE := 17.0
const PLAYER_START := Vector3(0.0, 0.05, 8.0)
const ROBOT_START := Vector3(0.0, 0.0, -7.0)


func _build_floor_and_bounds() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(80, 1.0, 80), _floor)
	var edge := DUEL_HALF_SIZE + 0.5
	var side := DUEL_HALF_SIZE * 2.0 + 2.0
	_add_box(Vector3(0, 0.6, -edge), Vector3(side, 1.2, 1.0), _concrete)
	_add_box(Vector3(0, 0.6, edge), Vector3(side, 1.2, 1.0), _concrete)
	_add_box(Vector3(-edge, 0.6, 0), Vector3(1.0, 1.2, side), _concrete)
	_add_box(Vector3(edge, 0.6, 0), Vector3(1.0, 1.2, side), _concrete)
	# Filete de neon no topo do muro: marca o limite visto de cima.
	var inner := DUEL_HALF_SIZE
	_add_box(Vector3(0, 1.22, -inner), Vector3(side, 0.05, 0.08), _cyan, Vector3.ZERO, false)
	_add_box(Vector3(0, 1.22, inner), Vector3(side, 0.05, 0.08), _cyan, Vector3.ZERO, false)
	_add_box(Vector3(-inner, 1.22, 0), Vector3(0.08, 0.05, side), _red, Vector3.ZERO, false)
	_add_box(Vector3(inner, 1.22, 0), Vector3(0.08, 0.05, side), _red, Vector3.ZERO, false)


func _build_scale_ruler() -> void:
	pass


func _build_obstacles() -> void:
	pass


func _build_slalom() -> void:
	pass


func _build_ramp_and_platform() -> void:
	pass


func _build_lights() -> void:
	super._build_lights()
	for s: Array in [[Vector3(-9, 5, 0), Color(0.1, 0.8, 1.0)], [Vector3(9, 5, 0), Color(1.0, 0.1, 0.12)]]:
		var omni := OmniLight3D.new()
		omni.position = s[0]
		omni.light_color = s[1]
		omni.light_energy = 3.0
		omni.omni_range = 18.0
		add_child(omni)
