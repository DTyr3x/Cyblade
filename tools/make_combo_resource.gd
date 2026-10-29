extends SceneTree
## Grava os valores de partida dos golpes em game/data/katana_combo.tres (editável no inspetor).
## godot --headless --path . -s res://tools/make_combo_resource.gd
func _initialize() -> void:
	var err := ResourceSaver.save(ComboSet.katana_default(), ComboSet.DEFAULT_PATH)
	print("[combo] salvo: ", error_string(err))
	quit()
