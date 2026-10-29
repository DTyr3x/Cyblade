class_name TrainingDummy
extends StaticBody3D
## Boneco de treino: sem IA, não se move sozinho. Tem uma hurtbox analítica (cápsula vertical),
## colisão para o jogador e reações visuais distintas por golpe (mola amortecida, sem animação
## pré-gravada). Registra o dano e cada contato para o modo de depuração.

const HURT_RADIUS := 0.38
const HURT_BOTTOM := 0.25
const HURT_TOP := 1.65

signal damaged(entry: Dictionary)

var total_damage := 0.0
var hits: Array[Dictionary] = []

var _pivot: Node3D
var _mat: StandardMaterial3D
var _lean := Vector2.ZERO        # inclinação (x = em torno de X, y = em torno de Z), rad
var _lean_vel := Vector2.ZERO
var _twist := 0.0
var _twist_vel := 0.0
var _slide := Vector3.ZERO       # deslocamento visual (m)
var _slide_vel := Vector3.ZERO
var _freeze := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group(HitDetector.HURTBOX_GROUP)
	_build()


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = HURT_RADIUS
	cap.height = HURT_TOP + 0.1
	shape.shape = cap
	shape.position.y = (HURT_TOP + 0.1) * 0.5
	add_child(shape)

	_pivot = Node3D.new()
	add_child(_pivot)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.32, 0.33, 0.38)
	_mat.metallic = 0.4
	_mat.roughness = 0.55
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.25, 0.1)
	_mat.emission_energy_multiplier = 0.0
	var marker := StandardMaterial3D.new()
	marker.albedo_color = Color(0.9, 0.1, 0.1)
	marker.emission_enabled = true
	marker.emission = Color(1.0, 0.1, 0.1)
	marker.emission_energy_multiplier = 1.5
	_add_mesh(_make_cyl(0.42, 0.1), Vector3(0, 0.05, 0), _mat)
	_add_mesh(_make_cyl(0.07, 0.8), Vector3(0, 0.45, 0), _mat)
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.95
	_add_mesh(torso, Vector3(0, 1.05, 0), _mat)
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add_mesh(head, Vector3(0, 1.65, 0), _mat)
	var arms := BoxMesh.new()
	arms.size = Vector3(1.0, 0.1, 0.1)
	_add_mesh(arms, Vector3(0, 1.3, 0), _mat)
	var target := BoxMesh.new()
	target.size = Vector3(0.22, 0.22, 0.02)
	_add_mesh(target, Vector3(0, 1.1, 0.31), marker)


func _make_cyl(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	return c


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	_pivot.add_child(mi)


## Contato entre o segmento da lâmina (a, b) e o eixo da cápsula do alvo. Devolve o ponto na
## lâmina se a distância for menor que raio + tolerância, ou Vector3.INF.
func segment_hit(a: Vector3, b: Vector3, tolerance: float) -> Vector3:
	var base := global_position + Vector3(0, HURT_BOTTOM, 0)
	var top := global_position + Vector3(0, HURT_TOP, 0)
	var pts := Geometry3D.get_closest_points_between_segments(a, b, base, top)
	if pts[0].distance_to(pts[1]) <= HURT_RADIUS + tolerance:
		return pts[0]
	return Vector3.INF


## Recebe um acerto. `info` vem do HitDetector.
func receive_hit(info: Dictionary) -> void:
	total_damage += float(info["damage"])
	var entry := {
		"strike": info["strike"], "swing": info["swing"], "damage": info["damage"],
		"total": total_damage, "point": info["point"],
	}
	hits.append(entry)
	var dir: Vector3 = info["direction"]
	var push := Vector2(dir.z, -dir.x)
	match int(info["reaction"]):
		StrikeData.Reaction.LIGHT_LEFT:
			_twist_vel += 7.0
			_lean_vel += push * 3.0
			_flash = 0.6
		StrikeData.Reaction.LIGHT_RIGHT:
			_twist_vel -= 7.0
			_lean_vel += push * 3.0
			_flash = 0.6
		StrikeData.Reaction.HEAVY:
			_lean_vel += push * 8.5
			_twist_vel += 4.0
			_flash = 1.0
	_slide_vel += dir * float(info["knockback"]) * 9.0
	_freeze = float(info["hitstop"])
	damaged.emit(entry)


func _physics_process(delta: float) -> void:
	if _freeze > 0.0:
		_freeze = maxf(_freeze - delta, 0.0)
		return
	# Molas amortecidas: inclinação, giro e deslocamento voltam ao repouso.
	_lean_vel += (-140.0 * _lean - 14.0 * _lean_vel) * delta
	_lean += _lean_vel * delta
	_twist_vel += (-140.0 * _twist - 14.0 * _twist_vel) * delta
	_twist += _twist_vel * delta
	_slide_vel += (-90.0 * _slide - 16.0 * _slide_vel) * delta
	_slide += _slide_vel * delta
	_flash = maxf(_flash - delta * 9.0, 0.0)
	_pivot.rotation = Vector3(_lean.x, _twist, _lean.y)
	_pivot.position = _slide
	_mat.emission_energy_multiplier = _flash * 0.9
