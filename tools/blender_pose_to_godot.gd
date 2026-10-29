extends SceneTree
## Converte a pose autorada no Blender (JSON de tools/blender/author_katana_strike.py) em um recurso
## Animation do Godot para o esqueleto do UAL.
##
## Para cada osso: G = F · M · B · C, onde B é a matriz do Blender (mundo, Z para cima), M passa do
## Blender para o espaço glTF (Y para cima), F do espaço da cena para o do esqueleto e C é uma
## correção constante por osso calculada no repouso (C = (F·M·B_repouso)⁻¹ · G_repouso_Godot).
## Assim não importa como cada lado orienta os eixos locais dos ossos. Depois: local = G_pai⁻¹ · G.
##
##   godot --headless --path . -s res://tools/blender_pose_to_godot.gd -- <entrada.json> <res://saida.res>

const MODEL_PATH := "res://assets/characters/ual/UAL1_Standard.glb"
const TRACK_PREFIX := "Armature/Skeleton3D:"
## Ossos que recebem trilha de posição (os outros só rotação, comprimento dos ossos intacto).
const POSITION_BONES := ["pelvis"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src := args[0]
	var dst := args[1]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src))
	var model := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(model)
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	# Transformação do esqueleto no espaço do modelo (cadeia de nós; ainda fora da árvore).
	var s_tf := Transform3D.IDENTITY
	var n: Node = sk
	while n != model:
		s_tf = (n as Node3D).transform * s_tf
		n = n.get_parent()
	var f_tf := s_tf.affine_inverse()
	var m_basis := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var m_tf := Transform3D(m_basis, Vector3.ZERO)

	var rest: Dictionary = data["rest"]
	var corr := {}
	for bone_name: String in rest:
		var i := sk.find_bone(bone_name)
		if i < 0:
			continue
		var b_rest := _to_tf(rest[bone_name])
		corr[i] = (f_tf * m_tf * b_rest).affine_inverse() * sk.get_bone_global_rest(i)

	var fps: float = data["fps"]
	var frames: Array = data["frames"]
	var anim := Animation.new()
	anim.length = (frames.size() - 1) / fps
	anim.loop_mode = Animation.LOOP_NONE
	var rot_tracks := {}
	var pos_tracks := {}
	for i: int in corr:
		var path := NodePath(TRACK_PREFIX + sk.get_bone_name(i))
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, path)
		rot_tracks[i] = t
		if sk.get_bone_name(i) in POSITION_BONES:
			var p := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(p, path)
			pos_tracks[i] = p

	for fi in frames.size():
		var fr: Dictionary = frames[fi]
		var g := {}
		for i: int in corr:
			g[i] = f_tf * m_tf * _to_tf(fr[sk.get_bone_name(i)]) * corr[i]
		var time := fi / fps
		for i: int in corr:
			var parent := sk.get_bone_parent(i)
			var parent_g: Transform3D = g[parent] if g.has(parent) else (sk.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY)
			var local: Transform3D = parent_g.affine_inverse() * g[i]
			anim.rotation_track_insert_key(rot_tracks[i], time, local.basis.orthonormalized().get_rotation_quaternion())
			if pos_tracks.has(i):
				anim.position_track_insert_key(pos_tracks[i], time, local.origin)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst.get_base_dir()))
	var err := ResourceSaver.save(anim, dst)
	print("[pose->godot] %s: %d quadros, %d ossos, %s" % [dst, frames.size(), corr.size(), error_string(err)])
	quit()


## Matriz 4x4 do Blender (lista de linhas) -> Transform3D.
func _to_tf(rows: Array) -> Transform3D:
	var b := Basis(
		Vector3(rows[0][0], rows[1][0], rows[2][0]),
		Vector3(rows[0][1], rows[1][1], rows[2][1]),
		Vector3(rows[0][2], rows[1][2], rows[2][2]))
	return Transform3D(b, Vector3(rows[0][3], rows[1][3], rows[2][3]))
