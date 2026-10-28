class_name TestArena
extends Node3D
## Arena de testes original. Monta tudo em código: piso com grade de 1 m, régua de escala,
## obstáculos, slalom, rampa e plataforma elevada, pilares monumentais ao fundo.
## Objetivo do Marco 1: avaliar escala, profundidade e movimentação, não beleza final.

const GRID_SHADER := preload("res://game/materials/grid.gdshader")
const HALF_SIZE := 40.0
const SPAWN_POSITION := Vector3(0.0, 0.05, 8.0)

var _metal: StandardMaterial3D
var _concrete: StandardMaterial3D
var _red: StandardMaterial3D
var _cyan: StandardMaterial3D
var _floor: ShaderMaterial


func _ready() -> void:
	_make_materials()
	_build_environment()
	_build_floor_and_bounds()
	_build_scale_ruler()
	_build_obstacles()
	_build_slalom()
	_build_ramp_and_platform()
	_build_skyline()
	_build_lights()


func _make_materials() -> void:
	_metal = StandardMaterial3D.new()
	_metal.albedo_color = Color(0.1, 0.11, 0.13)
	_metal.metallic = 0.8
	_metal.roughness = 0.45
	_concrete = StandardMaterial3D.new()
	_concrete.albedo_color = Color(0.16, 0.17, 0.19)
	_concrete.roughness = 0.9
	_red = StandardMaterial3D.new()
	_red.albedo_color = Color(0.8, 0.05, 0.08)
	_red.emission_enabled = true
	_red.emission = Color(1.0, 0.08, 0.1)
	_red.emission_energy_multiplier = 2.5
	_cyan = StandardMaterial3D.new()
	_cyan.albedo_color = Color(0.05, 0.6, 0.8)
	_cyan.emission_enabled = true
	_cyan.emission = Color(0.1, 0.8, 1.0)
	_cyan.emission_energy_multiplier = 2.0
	_floor = ShaderMaterial.new()
	_floor.shader = GRID_SHADER


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.4)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.08, 0.11, 0.16)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_floor_and_bounds() -> void:
	_add_box(Vector3(0, -0.5, 0), Vector3(HALF_SIZE * 2.0, 1.0, HALF_SIZE * 2.0), _floor)
	var edge := HALF_SIZE - 0.5
	var long_side := HALF_SIZE * 2.0
	_add_box(Vector3(0, 0.75, -edge), Vector3(long_side, 1.5, 1.0), _concrete)
	_add_box(Vector3(0, 0.75, edge), Vector3(long_side, 1.5, 1.0), _concrete)
	_add_box(Vector3(-edge, 0.75, 0), Vector3(1.0, 1.5, long_side), _concrete)
	_add_box(Vector3(edge, 0.75, 0), Vector3(1.0, 1.5, long_side), _concrete)


## Postes de 1,75 m (humano), 3,5 m, 7 m e 14 m para dar noção de escala.
func _build_scale_ruler() -> void:
	var heights := [1.75, 3.5, 7.0, 14.0]
	var labels := ["1,75 m", "3,5 m", "7 m", "14 m"]
	for i in heights.size():
		var h: float = heights[i]
		var pos := Vector3(-8.0, h * 0.5, 2.0 - i * 4.0)
		_add_box(pos, Vector3(0.4, h, 0.4), _metal)
		_add_box(Vector3(pos.x, h + 0.05, pos.z), Vector3(0.5, 0.1, 0.5), _red)
		var label := Label3D.new()
		label.text = labels[i]
		label.font_size = 96
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.6, 0.95, 1.0)
		label.outline_size = 12
		label.position = Vector3(pos.x, h + 0.8, pos.z)
		add_child(label)


func _build_obstacles() -> void:
	_add_box(Vector3(10, 0.6, 10), Vector3(2, 1.2, 2), _metal)
	_add_box(Vector3(14, 0.4, 5), Vector3(3, 0.8, 1.5), _metal, Vector3(0, 20, 0))
	_add_box(Vector3(8, 0.9, 2), Vector3(1.2, 1.8, 1.2), _concrete)
	_add_box(Vector3(16, 0.5, 12), Vector3(5, 1.0, 1), _concrete, Vector3(0, -15, 0))
	_add_cylinder(Vector3(4, 1.0, -6), 0.9, 2.0, _concrete)
	_add_cylinder(Vector3(-3, 1.5, -10), 1.2, 3.0, _metal)


## Fileira de postes para testar mudança de direção em espaço curto.
func _build_slalom() -> void:
	for i in 8:
		var pos := Vector3(-24.0 + (i % 2) * 3.0, 1.0, 12.0 - i * 4.0)
		_add_cylinder(pos, 0.4, 2.0, _cyan)


## Rampa de ~20° até uma plataforma a 4 m. A superfície da rampa cruza y=2 no centro.
func _build_ramp_and_platform() -> void:
	var slope_deg := 20.0
	var run := 11.0
	var length := sqrt(run * run + 16.0)
	var thickness := 0.5
	var center := Vector3(20.0, 2.0 - 0.5 * thickness / cos(deg_to_rad(slope_deg)), -5.5)
	_add_box(center, Vector3(6.0, thickness, length), _concrete, Vector3(slope_deg, 0, 0))
	_add_box(Vector3(20, 2.0, -17.5), Vector3(14, 4.0, 14), _metal)
	_add_box(Vector3(20, 4.05, -24.0), Vector3(14, 0.1, 0.3), _red)


func _build_skyline() -> void:
	var spots := [
		Vector3(-34, 0, -34), Vector3(34, 0, -34), Vector3(-34, 0, 34), Vector3(34, 0, 34),
		Vector3(0, 0, -37), Vector3(-37, 0, 0), Vector3(37, 0, 0),
	]
	for spot: Vector3 in spots:
		_add_box(spot + Vector3(0, 20, 0), Vector3(5, 40, 5), _metal)
		var toward_center := Vector3(-signf(spot.x), 0, -signf(spot.z)) * 2.55
		_add_box(spot + Vector3(toward_center.x, 15, 0), Vector3(0.15, 28, 0.15), _red, Vector3.ZERO, false)
		_add_box(spot + Vector3(0, 15, toward_center.z), Vector3(0.15, 28, 0.15), _red, Vector3.ZERO, false)


func _build_lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color(0.8, 0.85, 1.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	var spots := [
		[Vector3(-30, 6, -30), Color(1.0, 0.1, 0.12)],
		[Vector3(30, 6, -30), Color(0.1, 0.8, 1.0)],
		[Vector3(-30, 6, 30), Color(0.1, 0.8, 1.0)],
		[Vector3(30, 6, 30), Color(1.0, 0.1, 0.12)],
		[Vector3(20, 8, -17), Color(1.0, 0.1, 0.12)],
		[Vector3(-8, 5, -6), Color(0.1, 0.8, 1.0)],
	]
	for s: Array in spots:
		var omni := OmniLight3D.new()
		omni.position = s[0]
		omni.light_color = s[1]
		omni.light_energy = 4.0
		omni.omni_range = 26.0
		add_child(omni)


func _add_box(pos: Vector3, size: Vector3, mat: Material, rot_deg := Vector3.ZERO, collide := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
	add_child(body)
	return body


func _add_cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body
