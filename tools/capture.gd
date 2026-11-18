extends SceneTree
## Dev tool: renders real frames (NOT headless) and saves screenshots for phase reports.
##   godot --path . -s res://tools/capture.gd -- --out=<dir>
## Plays Level 1 with SimBot, fast-forwarding the simulation between shots.

var _out := "user://captures"
var _scene: Node
var _ctrl: MatchController
var _place: PlacementController
var _bot: SimBot
var _stage := 0
var _wait := 0
var _menu: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	_menu = load("res://ui/menus/main_menu.tscn").instantiate()
	root.add_child(_menu)
	_wait = 6


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _stage:
		0:
			_shot("01_main_menu")
			_menu.queue_free()
			root.get_node("/root/SceneRouter").pending_level = load("res://data/levels/level_01.tres")
			_scene = load("res://gameplay/match/match_scene.tscn").instantiate()
			root.add_child(_scene)
			_wait = 3
			_stage = 1
		1:
			_ctrl = _scene.get("controller")
			_place = _scene.get("placement")
			_ctrl.auto_process = false
			var order: Array[TowerDef] = []
			for id in [&"pulse", &"pulse", &"nova"]:
				for d in _ctrl.level.available_towers:
					if d.id == id:
						order.append(d)
			_bot = SimBot.new(_ctrl, order)
			_shot("02_match_start")
			# Tap-to-place ghost (before any spending) on a valid spot, then on the path.
			var def: TowerDef = _ctrl.level.available_towers[1]
			_place.begin_from_palette(def, Vector2(1200, 200))
			_place.mode = PlacementController.Mode.TAP
			_place._move_ghost(_bot.best_spot(def))
			_wait = 2
			_stage = 2
		2:
			_shot("03_tap_place_valid")
			_place._move_ghost(Vector2(500, 150))
			_wait = 2
			_stage = 3
		3:
			_shot("04_tap_place_invalid_on_path")
			_place.cancel()
			_stage = 4
		4:
			if _fast_forward(150.0):
				_wait = 2
				_stage = 5
		5:
			_shot("05_wave_combat")
			_ctrl.set_paused(true)
			_wait = 2
			_stage = 6
		6:
			_shot("06_pause_menu")
			_ctrl.set_paused(false)
			_stage = 7
		7:
			if _fast_forward(2000.0) or _ctrl.is_over():
				_wait = 3
				_stage = 8
		8:
			_shot("07_results")
			print("capture: done -> ", ProjectSettings.globalize_path(_out))
			quit(0)
			return true
	return false


## Advances bot + simulation up to 600 steps per frame; returns true once match_time >= t.
func _fast_forward(t: float) -> bool:
	for i in range(600):
		if _ctrl.match_time >= t or _ctrl.is_over():
			return true
		_bot.step(1.0 / 60.0)
		_ctrl.step(1.0 / 60.0)
	return false


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("capture: ", path)
