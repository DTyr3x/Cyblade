extends SceneTree
## Compara as poses de TRANSIÇÃO Kesa → Kiriage no modelo, de frente e de lado.
## Linha 1 e 3: Kesa nos quadros 13, 15, 17 (início da janela de encadeamento), 19 e 21.
## Linha 2 e 4: Kiriage nos quadros 0 (= pose do Kesa no 17), 2, 4, 6 e 8.
##   godot --path . --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/pose_compare.gd -- --out=docs/h2-2/estudo
const TILE := Vector2i(300, 380)
var _a_clip := "kesa"
var _b_clip := "kiriage"
var _a_frames := [13, 15, 17, 19, 21]
var _b_frames := [0, 2, 4, 6, 8]
var _name := "transicao_kesa_kiriage.png"
var _extra := {}


func _initialize() -> void:
	var out := "res://docs/h2-2/estudo"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = "res://" + a.substr(6)
		elif a.begins_with("--a="):
			_a_clip = a.substr(4)
		elif a.begins_with("--b="):
			_b_clip = a.substr(4)
		elif a.begins_with("--af="):
			_a_frames = Array(a.substr(5).split(",")).map(func(s): return int(s))
		elif a.begins_with("--bf="):
			_b_frames = Array(a.substr(5).split(",")).map(func(s): return int(s))
		elif a.begins_with("--name="):
			_name = a.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	_run(out)


func _run(out: String) -> void:
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
	var lib := ap.get_animation_library("")
	for n: String in [_a_clip, _b_clip]:
		if not lib.has_animation(n):
			lib.add_animation(n, load("res://assets/animations/katana/katana_%s.res" % n))
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	sk.add_child(att)
	var grip := Node3D.new()
	grip.basis = HumanoidVisual.STRIKE_GRIP
	att.add_child(grip)
	grip.add_child(Katana.build())
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.make_current()
	var sheet := Image.create(5 * TILE.x, 4 * TILE.y, false, Image.FORMAT_RGB8)
	var rows := [
		[_a_clip, _a_frames, Vector3(2.6, 1.4, 4.6)], [_b_clip, _b_frames, Vector3(2.6, 1.4, 4.6)],
		[_a_clip, _a_frames, Vector3(6.0, 1.1, 0.0)], [_b_clip, _b_frames, Vector3(6.0, 1.1, 0.0)],
	]
	for r in rows.size():
		var clip: String = rows[r][0]
		cam.look_at_from_position(rows[r][2], Vector3(0, 0.9, 0.3))
		for i in 5:
			ap.play(clip)
			ap.seek((rows[r][1][i] as int) / 60.0, true)
			ap.pause()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var crop := img.get_region(Rect2i(img.get_width() / 2 - TILE.x / 2, img.get_height() / 2 - TILE.y / 2 - 20, TILE.x, TILE.y))
			crop.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(crop, Rect2i(0, 0, TILE.x, TILE.y), Vector2i(i * TILE.x, r * TILE.y))
	sheet.save_png(ProjectSettings.globalize_path(out).path_join(_name))
	print("[pose_compare] ok")
	quit()
