extends SceneTree
## Dev tool: renders real frames of the Combat Lab (Phase 3 content) and saves screenshots.
##   godot --path . -s res://tools/capture_lab.gd -- --out=<dir>

var _out := "user://captures_lab"
var _scene: Node
var _ctrl: MatchController
var _place: PlacementController
var _bot: SimBot
var _stage := -2
var _wait := 3


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		-2:
			root.get_node("/root/SceneRouter").pending_level = load("res://data/levels/combat_lab.tres")
			root.get_node("/root/SceneRouter").pending_is_lab = true
			_scene = load("res://gameplay/match/match_scene.tscn").instantiate()
			root.add_child(_scene)
			_next(-1)
		-1:
			_ctrl = _scene.get("controller")
			_place = _scene.get("placement")
			_ctrl.auto_process = false
			var order: Array[TowerDef] = []
			for id in [&"pulse", &"nova", &"beacon", &"lance", &"pulse", &"lance"]:
				for d in _ctrl.level.available_towers:
					if d.id == id:
						order.append(d)
			_bot = SimBot.new(_ctrl, order)
			_bot.branch_pref = {&"lance": 0, &"nova": 1, &"beacon": 0, &"pulse": 0}
			_stage = 0
		0:
			if _ff(func() -> bool: return _ctrl.waves.index >= 3 and _ctrl.alive_enemy_count() >= 8):
				_next(1)
		1:
			_shot("p3_01_combat_fliers")
			_select(&"lance")
			_next(2)
		2:
			_shot("p3_02_tower_panel_lance")
			_select(&"beacon")
			_next(3)
		3:
			_shot("p3_03_beacon_amplifier_links")
			_place.select(null)
			_next(4)
		4:
			if _ff(func() -> bool:
				var b := _ctrl.current_boss()
				return b != null and b.telegraph_kind == EnemyAbilities.EMP_KIND and b.telegraph_timer < 0.8):
				_next(5)
		5:
			_shot("p3_04_boss_emp_telegraph")
			_next(6)
		6:
			if _ff(func() -> bool:
				var b := _ctrl.current_boss()
				return b != null and b.max_boss_phases >= 3 and b.boss_phase == 1 and b.progress > 250):
				_next(7)
		7:
			_shot("p3_05_final_boss")
			_next(8)
		8:
			if _ff(func() -> bool: return _ctrl.is_over()):
				_next(9)
		9:
			_shot("p3_06_results")
			print("capture_lab: done -> ", ProjectSettings.globalize_path(_out))
			quit(0)
			return true
	return false


func _next(s: int) -> void:
	_stage = s
	_wait = 2


func _select(id: StringName) -> void:
	var best: Tower = null
	for t in _ctrl.towers:
		if t.def.id == id and (best == null or t.tier > best.tier):
			best = t
	_place.select(best)


func _ff(cond: Callable) -> bool:
	for i in range(600):
		if cond.call() or _ctrl.is_over():
			return true
		_bot.step(1.0 / 60.0)
		_ctrl.step(1.0 / 60.0)
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("capture_lab: ", path)
