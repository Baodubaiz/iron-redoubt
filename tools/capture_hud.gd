extends SceneTree
## Dev tool (Reforged Stage E): HUD states — toasts/banner, pause menu, victory and defeat screens.
##   godot --path . --resolution 1280x720 -s res://tools/capture_hud.gd -- --out=<dir> [--lang=vi]

var _out := "user://captures_hud"
var _lang := "en"
var _stage := 0
var _wait := 5
var _node: Node
var _ctrl: MatchController
var _bot: SimBot


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		if a.begins_with("--lang="):
			_lang = a.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root) # never write the real profile
	match _stage:
		0:
			root.get_node("/root/Settings").data.language = _lang
			I18n.apply(_lang)
			var pm: ProgressionModel = root.get_node("/root/Progression").model
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			_play(1)
			_stage = 1
			_wait = 3
		1:
			_bot_run(60 * 20) # 20 s in: a few towers, first wave
			var place: PlacementController = _node.get("placement")
			place.message.emit(I18n.t("Not enough currency"))
			_node.get("hud").call("_toast", I18n.f("Synergy: %s", "Shatter"), "bolt", VisualPalette.GREEN)
			_node.get("hud").call("_show_banner", I18n.f("Wave %d cleared", 1).to_upper(), "+40", VisualPalette.GREEN)
			_stage = 2
			_wait = 12
		2:
			_shot("toasts_banner")
			_ctrl.set_paused(true)
			_stage = 3
			_wait = 30
		3:
			_shot("pause_menu")
			_ctrl.set_paused(false)
			_bot_run(60 * 900) # play L1 to the end
			_stage = 4
			_wait = 90
		4:
			_shot("results_%s" % ("victory" if _ctrl.state == MatchController.State.WON else "defeat"))
			# defeat: start L1 again and let the base fall (no towers)
			_play(1)
			_stage = 5
			_wait = 3
		5:
			_ctrl = _node.get("controller")
			_ctrl.auto_process = false
			for k in range(60 * 900):
				if _ctrl.is_over():
					break
				if _ctrl.state == MatchController.State.WAITING_FIRST_WAVE or _ctrl.state == MatchController.State.PREP:
					_ctrl.request_next_wave()
				_ctrl.step(1.0 / 60.0)
			_stage = 6
			_wait = 90
		6:
			_shot("results_defeat")
			print("capture_hud: done")
			quit(0)
			return true
	return false


func _play(level_number: int) -> void:
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	var router = root.get_node("/root/SceneRouter")
	router.pending_level = pm.campaign.levels[level_number - 1]
	router.pending_challenge = null
	router.pending_is_lab = false
	if _node != null:
		_node.queue_free()
	_node = load("res://gameplay/match/match_scene.tscn").instantiate()
	root.add_child(_node)
	_bot = null


func _bot_run(steps: int) -> void:
	_ctrl = _node.get("controller")
	_ctrl.auto_process = false
	if _bot == null:
		var sim = load("res://tools/sim/campaign_sim.gd")
		_bot = sim.make_bot(_ctrl, "balanced")
	for k in range(steps):
		if _ctrl.is_over():
			break
		_bot.step(1.0 / 60.0)
		_ctrl.step(1.0 / 60.0)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _lang, name])
