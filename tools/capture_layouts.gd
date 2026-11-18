extends SceneTree
## Dev tool: renders the same states at the current window size (aspect ratio) for layout checks.
##   godot --path . --resolution 1600x720 -s res://tools/capture_layouts.gd -- --out=<dir> --tag=20x9
##       --profile=<dir>/p.json [--fake-safe-area=60,0,30,0]

var _out := "user://captures_layout"
var _tag := "default"
var _lang := "en"
var _stage := 0
var _wait := 4
var _node: Node
var _ctrl: MatchController
var _bot: SimBot


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		if a.begins_with("--tag="):
			_tag = a.substr(6)
		if a.begins_with("--lang="):
			_lang = a.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root) # never write the real profile
	var prog = root.get_node("/root/Progression")
	var router = root.get_node("/root/SceneRouter")
	match _stage:
		0:
			root.get_node("/root/Settings").data.language = _lang
			I18n.apply(_lang)
			var pm: ProgressionModel = prog.model
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			for i in range(6):
				var l := pm.campaign.levels[i]
				pm.submit_match({"level_id": String(l.id), "won": true, "base_hp": l.base_hp, "damage_taken": 0,
					"duration": 500.0, "tower_types": ["pulse"]}, "lay%d" % i)
			_show("res://ui/menus/main_menu.tscn")
			_next(1)
		1:
			_shot("a_menu")
			_show("res://ui/menus/campaign_select.tscn")
			_next(2)
		2:
			_shot("b_campaign")
			router.pending_level = prog.model.campaign.levels[3]
			router.pending_challenge = null
			router.pending_is_lab = false
			_show("res://gameplay/match/match_scene.tscn")
			_next(3)
		3:
			_ctrl = _node.get("controller")
			_ctrl.auto_process = false
			var sim = load("res://tools/sim/campaign_sim.gd")
			sim.crosspath = true # show main + secondary upgrades in the tower panel
			_bot = sim.make_bot(_ctrl, "balanced")
			_ctrl.set_speed(2)
			_stage = 4
		4:
			if _ff(func() -> bool: return _ctrl.waves.index >= 4 and _ctrl.alive_enemy_count() >= 6):
				_next(5)
		5:
			var best: Tower = null
			for t in _ctrl.towers:
				if best == null or t.tier > best.tier:
					best = t
			_node.get("placement").select(best)
			_next(6)
		6:
			var tp: Control = _node.get("hud").get("_panel")
			if OS.get_cmdline_user_args().has("--debug-panel"):
				print("panel min ", tp.get_combined_minimum_size(), " size ", tp.size)
				for c in tp.get_child(0).get_children():
					print("  ", c.get_class(), " min ", c.get_combined_minimum_size())
			_shot("c_match_panel")
			_node.get("placement").select(null)
			var place: PlacementController = _node.get("placement")
			place.begin_from_palette(_ctrl.available_towers()[0], Vector2(10, 10))
			place.mode = PlacementController.Mode.TAP
			place._move_ghost(Vector2(560, 300))
			_next(7)
		7:
			_shot("d_match_tap_place")
			_node.get("placement").cancel()
			_ctrl.set_paused(true)
			_next(8)
		8:
			var hud = _node.get("hud")
			hud.call("_open_settings", hud.get("_pause_overlay"))
			_next(9)
		9:
			_shot("e_pause_settings")
			_ctrl.set_paused(false)
			_show("res://ui/menus/settings_screen.tscn")
			_next(10)
		10:
			_shot("f_settings_language")
			_show("res://ui/menus/research_screen.tscn")
			_next(11)
		11:
			_shot("g_research")
			_show("res://ui/menus/meta_screen.tscn")
			_next(12)
		12:
			_shot("h_meta")
			print("capture_layouts: done ", _tag)
			quit(0)
			return true
	return false


func _show(path: String) -> void:
	if _node != null:
		_node.queue_free()
	_node = load(path).instantiate()
	root.add_child(_node)


func _next(s: int) -> void:
	_stage = s
	_wait = 3 if _stage >= 3 and _stage <= 9 and _stage != 6 else 45 # menus: let entrance animations finish


func _ff(cond: Callable) -> bool:
	for i in range(900):
		if cond.call() or _ctrl.is_over():
			return true
		_bot.step(1.0 / 60.0)
		_ctrl.step(1.0 / 60.0)
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [_out, _tag, name])
