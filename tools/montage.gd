extends SceneTree
## Monta uma folha com quadros espaçados de uma sequência PNG (verificação do vídeo).
##   godot --headless -s res://tools/montage.gd -- --dir=C:/pasta --step=20 --cols=5 --out=C:/saida.png
func _initialize() -> void:
	var dir := ""
	var step := 20
	var cols := 5
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.substr(6)
		elif a.begins_with("--step="): step = int(a.substr(7))
		elif a.begins_with("--cols="): cols = int(a.substr(7))
		elif a.begins_with("--out="): out = a.substr(6)
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var tiles: Array[Image] = []
	for i in range(0, files.size(), step):
		var img := Image.load_from_file(dir.path_join(files[i]))
		img.resize(img.get_width() / 2, img.get_height() / 2)
		tiles.append(img)
	var w := tiles[0].get_width()
	var h := tiles[0].get_height()
	var sheet := Image.create(cols * w, ceili(tiles.size() / float(cols)) * h, false, Image.FORMAT_RGB8)
	for i in tiles.size():
		tiles[i].convert(Image.FORMAT_RGB8)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(out)
	quit()
