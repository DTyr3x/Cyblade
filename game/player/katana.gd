class_name Katana
extends RefCounted
## Katana procedural (original, feita de primitivas). Lâmina ao longo de +Y local.
## O encaixe na mão é feito por quem a monta (HumanoidVisual).

const BLADE_LENGTH := 0.78
const HANDLE_LENGTH := 0.26


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Katana"
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.86, 0.92)
	steel.metallic = 0.7
	steel.roughness = 0.42
	var wrap := StandardMaterial3D.new()
	wrap.albedo_color = Color(0.05, 0.05, 0.06)
	wrap.roughness = 0.8
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.8, 0.05, 0.08)
	accent.emission_enabled = true
	accent.emission = Color(1.0, 0.08, 0.1)
	accent.emission_energy_multiplier = 2.0
	_box(root, Vector3(0, HANDLE_LENGTH * 0.5 - 0.06, 0), Vector3(0.03, HANDLE_LENGTH, 0.035), wrap)
	_box(root, Vector3(0, HANDLE_LENGTH - 0.06, 0), Vector3(0.09, 0.012, 0.075), accent)
	_box(root, Vector3(0, HANDLE_LENGTH - 0.05 + BLADE_LENGTH * 0.5, 0), Vector3(0.012, BLADE_LENGTH, 0.034), steel)
	return root


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
