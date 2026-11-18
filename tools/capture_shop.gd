extends SceneTree
## Dev tool: Armory screenshot (sample profile: some shards on Storm, Chronos complete).
##   godot --path . --resolution 1280x720 -s res://tools/capture_shop.gd -- --out=<dir> [--lang=vi]

var _out := "user://captures_shop"
var _lang := "en"
var _wait := 6
var _stage := 0
var _scene := "res://ui/menus/shop_screen.tscn"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		if a.begins_with("--lang="): _lang = a.substr(7)
		if a.begins_with("--scene="): _scene = a.substr(8)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root)
	if _stage == 0:
		root.get_node("/root/Settings").data.language = _lang
		I18n.apply(_lang)
		var pm: ProgressionModel = root.get_node("/root/Progression").model
		pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
		pm.profile.add_shards("s", &"storm", 37)
		pm.profile.add_shards("c", &"chronos", 100)
		pm.profile.credit("c", 480)
		pm.profile.add_item("i1", &"airstrike", 2)
		root.add_child(load(_scene).instantiate())
		_stage = 1
		_wait = 40
		return false
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _lang, _scene.get_file().get_basename()])
	print("capture_shop: done")
	quit(0)
	return true
