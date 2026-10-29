extends SceneTree
## Folha de contato de UM clipe do pacote (ou de uma biblioteca nossa), modelo sozinho, câmera lateral.
## godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/clip_sheet.gd -- --clip=Sword_Attack --out=docs/h2/pesquisa [--tiles=12]
const TILE := Vector2i(300, 380)
func _initialize() -> void:
	var clip := "Sword_Attack"
	var out := "res://docs/h2/pesquisa"
	var tiles := 12
	var mirror := 0
	var t_from := -1.0
	var t_to := -1.0
	var res_path := ""
	var with_katana := false
	var cam_pos := Vector3(6.0, 1.1, 0.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="): clip = a.substr(7)
		elif a.begins_with("--out="): out = "res://" + a.substr(6)
		elif a.begins_with("--tiles="): tiles = int(a.substr(8))
		elif a.begins_with("--mirror="): mirror = int(a.substr(9))
		elif a.begins_with("--from="): t_from = float(a.substr(7))
		elif a.begins_with("--to="): t_to = float(a.substr(5))
		elif a.begins_with("--res="): res_path = a.substr(6)
		elif a.begins_with("--katana"): with_katana = true
		elif a.begins_with("--cam="): cam_pos = str_to_var("Vector3(" + a.substr(6) + ")")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_run(clip, out, tiles, mirror, t_from, t_to, res_path, with_katana, cam_pos)

func _run(clip: String, out: String, count: int, mirror := 0, t_from := -1.0, t_to := -1.0, res_path := "", with_katana := false, cam_pos := Vector3(6.0, 1.1, 0.0)) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.12, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.65, 0.75)
	root.add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-45, 30, 0)
	root.add_child(l)
	var m := (load("res://assets/characters/ual/UAL1_Standard.glb") as PackedScene).instantiate() as Node3D
	root.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(cam_pos, Vector3(0, 0.9, 0.3))
	cam.make_current()
	var label := clip
	if res_path != "":
		ap.get_animation_library("").add_animation("autoral", load(res_path))
		clip = "autoral"
		label = res_path.get_file().get_basename()
	if with_katana:
		var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
		var att := BoneAttachment3D.new()
		att.bone_name = "hand_r"
		sk.add_child(att)
		var grip := Node3D.new()
		grip.basis = HumanoidVisual.STRIKE_GRIP
		att.add_child(grip)
		grip.add_child(Katana.build())
	if t_from >= 0.0:
		var lib := ap.get_animation_library("")
		lib.add_animation("derivado", KatanaClips.derive(ap.get_animation(clip), t_from, t_to, mirror as KatanaClips.Mirror))
		clip = "derivado"
		label = "derivado_m%d" % mirror
	var len := ap.get_animation(clip).length
	var sheet := Image.create(6 * TILE.x, ceili(count / 6.0) * TILE.y, false, Image.FORMAT_RGB8)
	for i in count:
		ap.play(clip)
		ap.seek(len * i / float(count), true)
		ap.pause()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var crop := img.get_region(Rect2i(img.get_width() / 2 - TILE.x / 2, img.get_height() / 2 - TILE.y / 2 - 20, TILE.x, TILE.y))
		crop.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(crop, Rect2i(0, 0, TILE.x, TILE.y), Vector2i((i % 6) * TILE.x, (i / 6) * TILE.y))
	sheet.save_png(ProjectSettings.globalize_path(out).path_join("clip_%s_%s.png" % [label, "lado" if cam_pos.z == 0.0 else "frente"]))
	quit()
