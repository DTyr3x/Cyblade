class_name NinjaVisual
extends Node3D
## Ninja provisório feito só de primitivas (original, sem assets externos).
## Serve para avaliar escala (1,75 m), orientação e leitura de movimento.
## Frente do modelo = -Z local.

const LEAN_MAX_DEG := 8.0
const DODGE_CROUCH_SCALE := 0.72

var _armor: StandardMaterial3D
var _accent: StandardMaterial3D
var _body_root: Node3D


func _ready() -> void:
	_armor = StandardMaterial3D.new()
	_armor.albedo_color = Color(0.06, 0.065, 0.08)
	_armor.metallic = 0.7
	_armor.roughness = 0.4
	_accent = StandardMaterial3D.new()
	_accent.albedo_color = Color(0.8, 0.05, 0.08)
	_accent.emission_enabled = true
	_accent.emission = Color(1.0, 0.08, 0.1)
	_accent.emission_energy_multiplier = 2.5

	_body_root = Node3D.new()
	add_child(_body_root)
	_add_capsule(Vector3(-0.13, 0.43, 0), 0.14, 0.86, _armor)
	_add_capsule(Vector3(0.13, 0.43, 0), 0.14, 0.86, _armor)
	_add_box(Vector3(0, 1.15, 0), Vector3(0.56, 0.62, 0.32), _armor)
	_add_box(Vector3(0, 1.0, -0.17), Vector3(0.34, 0.05, 0.03), _accent)
	_add_capsule(Vector3(-0.36, 1.12, 0), 0.09, 0.56, _armor, Vector3(0, 0, 8))
	_add_capsule(Vector3(0.36, 1.12, 0), 0.09, 0.56, _armor, Vector3(0, 0, -8))
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	head.mesh = sphere
	head.material_override = _armor
	head.position = Vector3(0, 1.58, 0)
	_body_root.add_child(head)
	_add_box(Vector3(0, 1.6, -0.15), Vector3(0.24, 0.05, 0.05), _accent)
	# Cachecol vermelho e katana nas costas.
	_add_box(Vector3(0, 1.38, 0.2), Vector3(0.12, 0.05, 0.5), _accent, Vector3(15, 0, 0))
	_add_box(Vector3(0, 1.2, 0.2), Vector3(0.045, 0.045, 1.0), _armor, Vector3(0, 0, 35))
	_add_box(Vector3(0, 1.2, 0.2), Vector3(0.02, 0.02, 0.96), _accent, Vector3(0, 0, 35))


## `forward_speed_ratio`: velocidade ao longo da frente / velocidade máxima (-1..1).
func animate(delta: float, forward_speed_ratio: float, dodging: bool) -> void:
	if _body_root == null:
		return
	var lean := -deg_to_rad(LEAN_MAX_DEG) * clampf(forward_speed_ratio, 0.0, 1.0)
	_body_root.rotation.x = lerp_angle(_body_root.rotation.x, lean, MotionMath.smooth_alpha(delta, 0.06))
	var target_scale := DODGE_CROUCH_SCALE if dodging else 1.0
	_body_root.scale.y = lerpf(_body_root.scale.y, target_scale, MotionMath.smooth_alpha(delta, 0.04))


func _add_box(pos: Vector3, size: Vector3, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_body_root.add_child(mi)


func _add_capsule(pos: Vector3, radius: float, height: float, mat: Material, rot_deg := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	_body_root.add_child(mi)
