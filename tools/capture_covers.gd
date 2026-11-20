extends SceneTree
## Dev tool (2026-11-20): staged, busy battle for store covers / trailer clips. Never touches the real profile.
##   Stills: godot --path . --resolution 1920x1080 -s res://tools/capture_covers.gd -- --out=<dir> [--level=24] [--hud=0]
##   Video : add  --write-movie <dir>/raw.avi --fixed-fps 30  and  -- --video=22  (seconds of action to record)
## Builds upgraded / evolved towers along the route, floods it with tough enemies (and a boss) so every tower is
## firing, then saves frames (full 16:9 plus 1:1 and 2:3 crops) or just runs while the movie writer records.

var _out := "user://covers"
var _level := 24
var _hud := false
var _video := 0.0
var _wait := 8
var _step := 0
var _t := 0.0
var _shot := 0
var _ctrl: MatchController
var _scene: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): _out = a.substr(6)
		elif a.begins_with("--level="): _level = int(a.substr(8))
		elif a.begins_with("--hud="): _hud = a.substr(6) == "1"
		elif a.begins_with("--video="): _video = float(a.substr(8))
	DirAccess.make_dir_recursive_absolute(_out)


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root)
	var router = root.get_node("/root/SceneRouter")
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	match _step:
		0:
			TranslationServer.set_locale("en")
			for id in ["pulse", "nova", "lance", "beacon", "trap", "venom", "sniper", "spotter", "storm", "chronos", "bastion"]:
				pm.profile.unlock_tower(StringName(id))
			for r in pm.campaign.research:
				pm.profile.data["research"].append(String(r.id))
			pm.profile.data["levels"][String(pm.campaign.levels[0].id)] = {"cleared": true, "clears": 1, "best_hp": 20, "best_time": 300.0, "flawless": false}
			router.first_run_done = true
			router.pending_level = pm.campaign.levels[_level]
			var ids: Array[StringName] = [&"storm", &"lance", &"nova", &"pulse", &"beacon", &"sniper"]
			router.start_match_with_loadout(ids)
			_step = 1
			_wait = 40
		1:
			_scene = current_scene
			_ctrl = _scene.get("controller")
			_stage_battle()
			if not _hud:
				(_scene.get("hud") as CanvasLayer).visible = false
			_step = 2
			_t = 0.0
		2:
			_keep_busy()
			_t += 1.0 / 30.0 if _video > 0.0 else delta # movie mode: count frames (30 fps), not wall time
			if _video > 0.0:
				if _t >= _video + 3.0:
					quit()
					return true
			elif _t >= 3.0 + _shot * 1.4:
				_save_frame()
				_shot += 1
				if _shot >= 6:
					print("covers saved to ", ProjectSettings.globalize_path(_out))
					quit()
					return true
	return false


## Build spots: valid ground 45-120 px from a route, at least 70 px apart.
func _spots() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var probe: TowerDef = _ctrl.level.available_towers[0]
	for y in range(90, 690, 34):
		for x in range(60, 1220, 34):
			var p := Vector2(x, y)
			var d := _route_distance(p)
			if d < 45.0 or d > 120.0:
				continue
			if _ctrl.validate_placement(probe, p) != PlacementRules.Result.OK:
				continue
			var ok := true
			for q in out:
				if q.distance_to(p) < 70.0:
					ok = false
					break
			if ok:
				out.append(p)
	return out


func _route_distance(p: Vector2) -> float:
	var best := INF
	for r in _ctrl.routes:
		for i in range(r.points.size() - 1):
			best = minf(best, Geometry2D.get_closest_point_to_segment(p, r.points[i], r.points[i + 1]).distance_to(p))
	return best


func _stage_battle() -> void:
	_ctrl.economy.credit(1000000, "covers")
	_ctrl.base.max_hp = 100000
	_ctrl.base.hp = 100000
	var u := _ctrl.unlocks
	var defs := _ctrl.available_towers()
	var spots := _spots()
	spots.shuffle()
	var n := 0
	for p in spots:
		if n >= 18:
			break
		var d: TowerDef = defs[n % defs.size()]
		var t := _ctrl.try_build(d, p)
		if t == null:
			continue
		n += 1
		var main := n % d.branches.size()
		var sec := (main + 1) % d.branches.size()
		for k in range(3):
			_ctrl.try_upgrade(t, main)
		for k in range(2):
			_ctrl.try_upgrade(t, sec)
		if n % 2 == 0:
			t.waves_since_t3 = 5
			if u != null:
				u.evolutions[d.id] = true
			_ctrl.try_evolve(t)
	print("towers: ", n)
	_ctrl.request_next_wave()
	var boss: EnemyDef = load("res://data/enemies/colossus.tres")
	var b := _ctrl.spawn_enemy(boss, 0)
	b.place_at_progress(300.0)
	b.max_hp *= 20.0
	b.hp = b.max_hp


const CROWD := ["drone", "brute", "glider", "plated", "aegis", "dart", "phantom", "sprinter", "vanguard", "mender"]


func _keep_busy() -> void:
	var i := 0
	while _ctrl.alive_enemy_count() < 70 and i < 6:
		var e := _ctrl.spawn_enemy(load("res://data/enemies/%s.tres" % CROWD[randi() % CROWD.size()]), 0)
		e.place_at_progress(randf() * 900.0)
		e.max_hp *= 30.0
		e.hp = e.max_hp * randf_range(0.4, 1.0)
		i += 1


func _save_frame() -> void:
	var img := root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	img.save_png("%s/frame%d_landscape_%dx%d.png" % [_out, _shot, w, h])
	var land := img.duplicate() as Image
	land.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	land.save_png("%s/frame%d_cover_1920x1080.png" % [_out, _shot])
	var sq := img.get_region(Rect2i((w - h) / 2, 0, h, h))
	sq.resize(800, 800, Image.INTERPOLATE_LANCZOS)
	sq.save_png("%s/frame%d_cover_800x800.png" % [_out, _shot])
	var pw := int(h * 2.0 / 3.0)
	var pt := img.get_region(Rect2i((w - pw) / 2, 0, pw, h))
	pt.resize(800, 1200, Image.INTERPOLATE_LANCZOS)
	pt.save_png("%s/frame%d_cover_800x1200.png" % [_out, _shot])
