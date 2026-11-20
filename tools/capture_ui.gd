extends SceneTree
## Dev tool (2026-11-19): screenshots of every menu screen and the match HUD, for a quick visual check of text
## overflow / clipping in both languages. Never touches the real profile (DevSandbox).
##   godot --path . --resolution 1280x720 -s res://tools/capture_ui.gd -- --out=<dir> [--lang=vi|en]

var _out := "user://captures_ui"
var _lang := "vi"
var _wait := 6
var _step := 0
var _frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--lang="):
			_lang = a.substr(7)
		elif a.begins_with("--ui-scale="):
			root.content_scale_factor = float(a.substr(11))
	DirAccess.make_dir_recursive_absolute(_out)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _lang, name])


func _rich_profile(pm: ProgressionModel) -> void:
	var d := Profile.fresh(pm.campaign.starting_towers)
	for l in pm.campaign.levels.slice(0, 12):
		d["levels"][String(l.id)] = {"cleared": true, "clears": 1, "best_hp": 18, "best_time": 400.0, "flawless": false}
	d["ledger"]["dev:cores"] = 5000
	for r in pm.campaign.research.slice(0, 6):
		d["research"].append(String(r.id))
	for it in pm.campaign.consumables:
		d["items"]["dev:%s" % it.id] = [String(it.id), 3]
	pm.profile.data = d
	for t in ["pulse", "nova", "lance", "beacon", "trap", "venom", "sniper", "spotter"]:
		pm.profile.unlock_tower(StringName(t))


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _frames > 0:
		_frames -= 1
		return false
	DevSandbox.isolate(root)
	var router = root.get_node("/root/SceneRouter")
	var prog = root.get_node("/root/Progression")
	var pm: ProgressionModel = prog.model
	TranslationServer.set_locale(_lang)
	match _step:
		0:
			_rich_profile(pm)
			router.to_menu()
		1: _shot("01_menu"); router.to_campaign()
		2: _shot("02_campaign"); router.to_research()
		3:
			_shot("03_research")
			var rs := root.get_tree().current_scene
			rs.set("_category", &"tower")
			rs.call("_build")
		4:
			_shot("04_research_towers")
			var rs := root.get_tree().current_scene
			rs.set("_category", &"support")
			rs.call("_build")
		5: _shot("05_research_support"); router.to_meta()
		6: _shot("06_challenges"); router.to_codex()
		7: _shot("07_codex"); router.to_shop()
		8: _shot("08_armory"); router.to_settings()
		9:
			_shot("09_settings")
			router.pending_level = pm.campaign.levels[2]
			router.to_loadout()
		10:
			_shot("10_loadout")
			var ids: Array[StringName] = [&"pulse", &"nova", &"lance", &"beacon"]
			router.pending_level = pm.campaign.levels[2]
			router.start_match_with_loadout(ids)
		11:
			_shot("11_match_start")
			var ms := root.get_tree().current_scene
			var c: MatchController = ms.get("controller")
			c.economy.credit(5000, "dev")
			var t := c.try_build(c.level.available_towers[2], Vector2(640, 300))
			if t == null:
				for x in range(160, 1100, 40):
					for y in range(120, 660, 40):
						if t == null:
							t = c.try_build(c.level.available_towers[2], Vector2(x, y))
			if t != null:
				c.try_upgrade(t, 0)
				c.try_upgrade(t, 2)
				(ms.get("placement") as PlacementController).select(t)
			c.request_next_wave()
			_frames = 120
		12:
			_shot("12_match_tower_panel")
			var ms := root.get_tree().current_scene
			(ms.get("placement") as PlacementController).select(null)
			var c: MatchController = ms.get("controller")
			c.set_paused(true)
		13:
			_shot("13_match_paused")
			var ms := root.get_tree().current_scene
			var c: MatchController = ms.get("controller")
			c.set_paused(false)
			c.base.apply_damage(9999)
			_frames = 30
		14:
			_shot("14_match_defeat")
			print("captures in ", ProjectSettings.globalize_path(_out))
			quit()
			return true
	_step += 1
	_frames = maxi(_frames, 20)
	return false
