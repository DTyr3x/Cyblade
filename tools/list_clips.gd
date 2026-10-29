extends SceneTree
## Lista os clipes do pacote de animações (nome e duração). Uso:
## godot --headless --path . -s res://tools/list_clips.gd
func _initialize() -> void:
	var m := (load("res://assets/characters/ual/UAL1_Standard.glb") as PackedScene).instantiate()
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		print("%-28s %.2fs loop=%d" % [n, a.length, a.loop_mode])
	quit()
