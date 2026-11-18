extends SceneTree
## Dev tool: Phase 4 screenshots (menus, campaign, research, challenges, Delta night, Prism gates,
## results with rewards). Uses a throwaway profile:
##   godot --path . -s res://tools/capture_p4.gd -- --out=<dir> --profile=<dir>/p4_profile.json

var _out := "user://captures_p4"
var _stage := 0
var _wait := 4
var _node: Node
var _ctrl: MatchController
var _bot: SimBot


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var prog = root.get_node("/root/Progression")
	var router = root.get_node("/root/SceneRouter")
	match _stage:
		0:
			# demo profile: L1-L6 cleared, some Cores and research
			var pm: ProgressionModel = prog.model
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			for i in range(6):
				var l := pm.campaign.levels[i]
				pm.submit_match({"level_id": String(l.id), "won": true, "base_hp": l.base_hp - (0 if i < 2 else 3),
					"damage_taken": 0 if i < 2 else 3, "duration": 500.0, "tower_types": ["pulse", "nova"]}, "demo%d" % i)
			pm.buy_research(&"field_scanner")
			pm.buy_research(&"reserve_1")
			_show("res://ui/menus/main_menu.tscn")
			_next(1)
		1:
			_shot("p4_01_main_menu")
			_show("res://ui/menus/campaign_select.tscn")
			_next(2)
		2:
			_node.call("_select", prog.model.campaign.levels[6])
			_next(3)
		3:
			_shot("p4_02_campaign_select")
			_show("res://ui/menus/research_screen.tscn")
			_next(4)
		4:
			_shot("p4_03_research")
			_show("res://ui/menus/meta_screen.tscn")
			_next(5)
		5:
			_shot("p4_04_challenges_achievements")
			_start_match(prog.model.campaign.levels[3], router)
			_next(6)
		6:
			_attach_bot("balanced")
			_stage = 7
		7:
			if _ff(func() -> bool: return _ctrl.is_night and _ctrl.alive_enemy_count() >= 6):
				_next(8)
		8:
			_shot("p4_05_delta_night")
			_start_match(prog.model.campaign.levels[6], router)
			_next(9)
		9:
			_attach_bot("heavy")
			_stage = 10
		10:
			if _ff(func() -> bool: return _ctrl.state == MatchController.State.PREP and _ctrl.waves.index == 4 and _ctrl.waves.prep_remaining < 10.0):
				_next(11)
		11:
			_shot("p4_06_prism_gate_announce")
			_stage = 12
		12:
			if _ff(func() -> bool: return _ctrl.active_route == 1 and _ctrl.alive_enemy_count() >= 8):
				_next(13)
		13:
			_shot("p4_07_prism_route_south")
			_start_match(prog.model.campaign.levels[0], router)
			_next(14)
		14:
			_attach_bot("balanced")
			_stage = 15
		15:
			if _ff(func() -> bool: return _ctrl.is_over()):
				_next(16)
		16:
			_shot("p4_08_results_rewards")
			print("capture_p4: done -> ", ProjectSettings.globalize_path(_out))
			quit(0)
			return true
	return false


func _show(path: String) -> void:
	if _node != null:
		_node.queue_free()
	_node = load(path).instantiate()
	root.add_child(_node)


func _start_match(l: LevelDef, router: Node) -> void:
	router.pending_level = l
	router.pending_challenge = null
	router.pending_is_lab = false
	_show("res://gameplay/match/match_scene.tscn")


func _attach_bot(strategy: String) -> void:
	_ctrl = _node.get("controller")
	_ctrl.auto_process = false
	_bot = load("res://tools/sim/campaign_sim.gd").make_bot(_ctrl, strategy)


func _next(s: int) -> void:
	_stage = s
	_wait = 3


func _ff(cond: Callable) -> bool:
	for i in range(900):
		if cond.call() or _ctrl.is_over():
			return true
		_bot.step(1.0 / 60.0)
		_ctrl.step(1.0 / 60.0)
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("capture_p4: ", name)
