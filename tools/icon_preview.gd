extends SceneTree
## Dev tool: renders candidate launcher icons (SVG files) side by side at phone sizes for review.
##   godot --headless --path . -s res://tools/icon_preview.gd -- --dir=<folder with *.svg> --out=<png>
func _initialize() -> void:
	var dir := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): dir = a.substr(6)
		if a.begins_with("--out="): out = a.substr(6)
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".svg"): names.append(f)
	names.sort()
	var cell := 300
	var sheet := Image.create(cell * names.size(), 420, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2B3245"))
	for i in range(names.size()):
		var src := FileAccess.get_file_as_string(dir + "/" + names[i])
		for sz in [[192, 20], [96, 236], [48, 360]]:
			var img := Image.new()
			img.load_svg_from_string(src, float(sz[0]) / _width(src))
			img.convert(Image.FORMAT_RGBA8)
			var x := i * cell + (cell - img.get_width()) / 2
			sheet.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, sz[1]))
	sheet.save_png(out)
	print("icon_preview: ", names)
	quit(0)


func _width(svg: String) -> float:
	var rx := RegEx.new()
	rx.compile("width=\"([0-9]+)\"")
	var m := rx.search(svg)
	return float(m.get_string(1)) if m else 512.0
