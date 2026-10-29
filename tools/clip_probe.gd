extends SceneTree
## Sonda de clipe: imprime a posição (no espaço do esqueleto) de ossos-chave ao longo do clipe.
## godot --headless --path . -s res://tools/clip_probe.gd -- --clip=Sword_Attack
func _initialize() -> void:
	var clip := "Sword_Attack"
	var res := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clip="): clip = a.substr(7)
		if a.begins_with("--res="): res = a.substr(6)
	var m := (load("res://assets/characters/ual/UAL1_Standard.glb") as PackedScene).instantiate() as Node3D
	root.add_child(m)
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if res != "":
		ap.get_animation_library("").add_animation("autoral", load(res))
		clip = "autoral"
	var anim := ap.get_animation(clip)
	print("trilhas: %d" % anim.get_track_count())
	for i in anim.get_track_count():
		if i < 6: print("  ", anim.track_get_path(i), " tipo ", anim.track_get_type(i))
	var names := ["root", "pelvis", "foot_l", "foot_r", "hand_r", "hand_l"]
	var ids := names.map(func(n): return sk.find_bone(n))
	for k in 13:
		var t := anim.length * k / 12.0
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
		await process_frame
		var s := "t=%.2f " % t
		for j in names.size():
			var p := sk.get_bone_global_pose(ids[j]).origin
			s += "%s(%.2f,%.2f,%.2f) " % [names[j], p.x, p.y, p.z]
		print(s)
	quit()
