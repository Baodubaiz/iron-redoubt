extends SceneTree
## Dev tool (content update): every campaign map, the region select screen (Rift tab) and each region
## boss frozen mid-telegraph. Also writes a contact sheet of all 19 maps.
##   godot --path . --resolution 1280x720 -s res://tools/capture_content.gd -- --out=<dir> [--lang=vi]

var _out := "user://captures_content"
var _lang := "en"
var _wait := 6
var _stage := 0
var _i := 0
var _node: Node
var _ctrl: MatchController
const BOSS_LEVELS := [[4, 0.8, 3], [9, 0.5, 11], [14, 0.5, 6], [19, 0.8, 14], [24, 0.5, 16], [29, 0.5, 2], [34, 0.5, 8], [39, 0.2, 10]] ## [level index, hp ratio, telegraph kind]


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
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	match _stage:
		0: # setup: everything owned, levels 1-13 cleared
			root.get_node("/root/Settings").data.language = _lang
			I18n.apply(_lang)
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			for r in pm.campaign.research:
				pm.profile.data["research"].append(String(r.id))
			pm.profile.data["owned_towers"] = ["pulse", "nova", "lance", "beacon"]
			for k in range(23):
				var l := pm.campaign.levels[k]
				pm.profile.data["levels"][String(l.id)] = {"cleared": true, "clears": 1,
					"best_hp": l.base_hp if k % 3 == 0 else l.base_hp - 4, "flawless": k % 3 == 0, "best_time": 300.0}
			_show("res://ui/menus/campaign_select.tscn")
			_stage = 1
			_wait = 20
		1:
			var tab := _node.find_child("Region_rift", true, false) as Button
			if tab != null:
				tab.pressed.emit()
			_stage = 2
			_wait = 30
		2:
			_shot("campaign_rift")
			var tab := _node.find_child("Region_circuit", true, false) as Button
			if tab != null:
				tab.pressed.emit()
			_stage = 3
			_wait = 30
		3:
			_shot("campaign_circuit")
			_i = 0
			_stage = 10
		10: # every map, empty, day
			if _i >= pm.campaign.levels.size():
				_sheet(pm.campaign.levels.size())
				_i = 0
				_stage = 20
				return false
			_play(pm.campaign.levels[_i])
			_stage = 11
			_wait = 8
		11:
			_shot("map_%02d" % (_i + 1))
			_i += 1
			_stage = 10
		20: # staged bosses
			if _i >= BOSS_LEVELS.size():
				print("capture_content: done")
				quit(0)
				return true
			_play(pm.campaign.levels[BOSS_LEVELS[_i][0]])
			_stage = 21
			_wait = 4
		21:
			_stage_boss(BOSS_LEVELS[_i])
			_stage = 22
			_wait = 40
		22:
			_shot("boss_%02d" % (BOSS_LEVELS[_i][0] + 1))
			_i += 1
			_stage = 20
	return false


func _show(path: String) -> void:
	if _node != null:
		_node.queue_free()
	_node = load(path).instantiate()
	root.add_child(_node)


func _play(l: LevelDef) -> void:
	var router = root.get_node("/root/SceneRouter")
	router.pending_level = l
	router.pending_challenge = null
	router.pending_is_lab = false
	_show("res://gameplay/match/match_scene.tscn")


func _stage_boss(spec: Array) -> void:
	_ctrl = _node.get("controller")
	_ctrl.auto_process = false
	var l := _ctrl.level
	var boss_def: EnemyDef = null
	for g in l.waves[l.waves.size() - 1].groups:
		if g.enemy.is_boss:
			boss_def = g.enemy
	var route: RoutePath = _ctrl.routes[0]
	var boss := _ctrl.spawn_enemy_on(boss_def, route, route.total_length * 0.45)
	boss.hp = boss.max_hp * float(spec[1])
	for i in range(5):
		_ctrl.spawn_enemy_on(load("res://data/enemies/%s.tres" % ["drone", "aegis", "brute", "plated", "dart"][i]),
			route, route.total_length * 0.45 - 40.0 - i * 26.0)
	_ctrl.step(1.0 / 60.0) # phase update
	boss.telegraph_kind = int(spec[2])
	boss.telegraph_total = 1.5
	boss.telegraph_timer = 0.6
	if boss_def.boss_kit == &"colossus": # show an escort under Bulwark too
		for e in _ctrl.enemies:
			if e != boss:
				e.overshield = 150.0
				e.overshield_timer = 5.0
				e.haste = 0.3
				e.haste_timer = 5.0
	if boss_def.boss_kit == &"carrier":
		boss.cloak_timer = 3.0
	if boss_def.boss_kit == &"refractor":
		boss.immune_type = Damage.Type.EXPLOSIVE
		boss.immune_timer = 3.0
	if boss_def.boss_kit == &"dynamo":
		boss.hit_cap = 50.0
		boss.hit_cap_timer = 3.0


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _lang, name])


func _sheet(n: int) -> void:
	var w := 240
	var h := 135
	var cols := 8
	var rows := int(ceil(n / float(cols)))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("070B16"))
	for k in range(n):
		var img := Image.load_from_file("%s/%s_map_%02d.png" % [_out, _lang, k + 1])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(w - 4, h - 4, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, w - 4, h - 4), Vector2i((k % cols) * w + 2, (k / cols) * h + 2))
	sheet.save_png("%s/%s_maps_sheet.png" % [_out, _lang])
