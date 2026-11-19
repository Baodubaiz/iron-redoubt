extends SceneTree
## Dev tool (2026-11-19): frame-time benchmark of a crowded match (no balance meaning). Builds ~30 towers and
## keeps ~N enemies on the map, vsync off, then reports average FPS and per-frame CPU costs.
##   godot --path . --resolution 1280x720 -s res://tools/bench_fps.gd -- [--enemies=150] [--seconds=8] [--hide=enemies|towers|fx]

var _enemies := 150
var _seconds := 8.0
var _hide := ""
var _wait := 6
var _phase := 0
var _t := 0.0
var _frames := 0
var _proc := 0.0
var _phys := 0.0
var _draw_calls := 0.0
var _ctrl: MatchController


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--enemies="):
			_enemies = int(a.substr(10))
		elif a.begins_with("--seconds="):
			_seconds = float(a.substr(10))
		elif a.begins_with("--hide="):
			_hide = a.substr(7)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _process(delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root)
	var router = root.get_node("/root/SceneRouter")
	var pm: ProgressionModel = root.get_node("/root/Progression").model
	match _phase:
		0:
			for id in ["pulse", "nova", "lance", "beacon", "trap", "venom", "sniper", "spotter", "storm", "chronos"]:
				pm.profile.unlock_tower(StringName(id))
			var lvl: LevelDef = pm.campaign.levels[20]
			router.pending_level = lvl
			var ids: Array[StringName] = [&"pulse", &"nova", &"lance", &"beacon", &"venom", &"sniper"]
			router.start_match_with_loadout(ids)
			_phase = 1
			_wait = 30
		1:
			var ms = current_scene
			_ctrl = ms.get("controller")
			_ctrl.economy.credit(100000, "bench")
			_ctrl.base.max_hp = 100000
			_ctrl.base.hp = 100000
			var defs := _ctrl.level.available_towers
			var n := 0
			for y in range(100, 700, 60):
				for x in range(60, 1240, 60):
					if n >= 30:
						break
					var d: TowerDef = defs[n % defs.size()]
					var t := _ctrl.try_build(d, Vector2(x, y))
					if t != null:
						_ctrl.try_upgrade(t, 0)
						_ctrl.try_upgrade(t, 0)
						n += 1
			print("towers built: ", n)
			_ctrl.request_next_wave()
			_phase = 2
		2:
			_keep_crowd()
			_t += delta
			if _t > 2.0: # warm-up
				_phase = 3
				_t = 0.0
				_apply_hide()
		3:
			_keep_crowd()
			_t += delta
			_frames += 1
			_proc += Performance.get_monitor(Performance.TIME_PROCESS)
			_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			if _t >= _seconds * 0.5 and not has_meta("shot"):
				set_meta("shot", true)
				root.get_texture().get_image().save_png("user://bench_frame.png")
			if _t >= _seconds:
				print("RESULT hide=%s enemies=%d fps=%.1f frame=%.2fms process=%.2fms physics=%.2fms draw_calls=%.0f nodes=%d" % [
					_hide, _ctrl.alive_enemy_count(), _frames / _t, 1000.0 * _t / _frames, 1000.0 * _proc / _frames,
					1000.0 * _phys / _frames, _draw_calls / _frames, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
				quit()
				return true
	return false


func _keep_crowd() -> void:
	var defs := ["drone", "brute", "glider", "plated", "aegis", "dart", "swarmling"]
	var i := 0
	while _ctrl.alive_enemy_count() < _enemies and i < 20:
		var e := _ctrl.spawn_enemy(load("res://data/enemies/%s.tres" % defs[(_frames + i) % defs.size()]), 0)
		e.place_at_progress(randf() * 400.0)
		e.max_hp *= 50.0 # survive the towers: keeps the crowd size stable
		e.hp = e.max_hp
		i += 1


func _apply_hide() -> void:
	match _hide:
		"enemies":
			for e in _ctrl.enemies:
				for c in e.get_children():
					if c is CanvasItem:
						(c as CanvasItem).visible = false
		"enemies_off": # not drawn AND not processed: what the visuals cost in total
			for e in _ctrl.enemies:
				for c in e.get_children():
					if c is CanvasItem:
						(c as CanvasItem).visible = false
						c.set_process(false)
		"enemies_frozen": # drawn, but never re-drawn (no _process): cost of the per-frame redraw itself
			for e in _ctrl.enemies:
				for c in e.get_children():
					if c is CanvasItem:
						c.set_process(false)
		"towers":
			for t in _ctrl.towers:
				for c in t.get_children():
					if c is CanvasItem:
						(c as CanvasItem).visible = false
		"map":
			_ctrl.map_view.visible = false
		"fx":
			_ctrl.projectiles.visible = false
