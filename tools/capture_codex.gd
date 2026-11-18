extends SceneTree
## Dev tool: Codex screenshots (every tab, one locked profile view).
##   godot --path . --resolution 1280x720 -s res://tools/capture_codex.gd -- --out=<dir> [--lang=vi]

var _out := "user://captures_codex"
var _lang := "en"
var _wait := 6
var _stage := 0
var _node: Control
const SHOTS := [["towers", "Entry_storm"], ["towers", "Entry_chronos"], ["towers", "Entry_trap"], ["towers", "Entry_venom"], ["towers", "Entry_sniper"], ["towers", "Entry_bastion"],
	["enemies", "Entry_sludge"], ["towers", "Entry_lance"], ["enemies", "Entry_aegis"], ["bosses", "Entry_colossus"],
	["bosses", "Entry_leviathan"], ["effects", "Entry_freeze"], ["damage", "Entry_dmg_energy"], ["regions", "Entry_delta"]]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		if a.begins_with("--lang="): _lang = a.substr(7)
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
		pm.profile.add_to_set("seen_enemies", ["drone", "dart", "brute", "swarmling", "plated", "aegis", "glider", "sludge", "escort", "jammer",
			"warden", "carrier", "colossus", "leviathan", "dynamo"])
		_node = load("res://ui/menus/codex_screen.tscn").instantiate()
		root.add_child(_node)
		_stage = 1
		_wait = 20
		return false
	var i := _stage - 1
	if i >= SHOTS.size() * 2:
		print("capture_codex: done")
		quit(0)
		return true
	var s: Array = SHOTS[i / 2]
	if i % 2 == 0:
		(_node.find_child("Tab_%s" % s[0], true, false) as Button).pressed.emit()
		var e := _node.find_child(s[1], true, false) as Button
		if e != null:
			e.button_pressed = true
			e.pressed.emit()
		_wait = 40
	else:
		root.get_texture().get_image().save_png("%s/%s_codex_%d_%s.png" % [_out, _lang, i / 2, s[1].substr(6)])
		_wait = 2
	_stage += 1
	return false
