extends SceneTree
## Dev tool: frame-time probe of a heavy battle (desktop only — NOT representative of phones).
##   godot --path . --resolution 1280x720 -s res://tools/perf_probe.gd -- [--level=9] [--frames=900]

var _level := 9
var _extra := 0 ## --stress=N: inject N extra mixed enemies (heavy-scene probe)
var _frames := 900
var _node: Node
var _ctrl: MatchController
var _bot: SimBot
var _stage := 0
var _wait := 5
var _times: Array[float] = []
var _last := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="): _level = int(a.substr(8))
		if a.begins_with("--frames="): _frames = int(a.substr(9))
		if a.begins_with("--stress="): _extra = int(a.substr(9))


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	DevSandbox.isolate(root) # never write the real profile
	match _stage:
		0:
			var prog = root.get_node("/root/Progression")
			var pm: ProgressionModel = prog.model
			pm.profile.data = Profile.fresh(pm.campaign.starting_towers)
			for r in pm.campaign.research:
				pm.profile.data["research"].append(String(r.id))
			pm.profile.data["owned_towers"] = ["pulse", "nova", "lance", "beacon"]
			var router = root.get_node("/root/SceneRouter")
			router.pending_level = pm.campaign.levels[_level - 1]
			router.pending_challenge = null
			router.pending_is_lab = false
			_node = load("res://gameplay/match/match_scene.tscn").instantiate()
			root.add_child(_node)
			_stage = 1
			_wait = 3
		1:
			_ctrl = _node.get("controller")
			_ctrl.auto_process = false
			var sim = load("res://tools/sim/campaign_sim.gd")
			sim.crosspath = true
			_bot = sim.make_bot(_ctrl, "heavy")
			# fast-forward to a crowded late wave
			for k in range(60 * 60 * 12):
				if _ctrl.is_over() or _ctrl.alive_enemy_count() >= 22:
					break
				_bot.step(1.0 / 60.0)
				_ctrl.step(1.0 / 60.0)
			var kinds := ["drone", "swarmling", "dart", "brute", "plated", "aegis", "glider", "phantom", "mender"]
			for i in range(_extra):
				var def: EnemyDef = load("res://data/enemies/%s.tres" % kinds[i % kinds.size()])
				var route: RoutePath = _ctrl.air_routes[0] if def.flying else _ctrl.routes[mini(i % 2, _ctrl.routes.size() - 1)]
				var e := _ctrl.spawn_enemy_on(def, route, route.total_length * (0.05 + 0.6 * float(i) / maxf(_extra, 1)))
				e.max_hp *= 20.0 # keep them alive during the probe
				e.hp = e.max_hp
			_ctrl.auto_process = true
			_ctrl.set_speed(2)
			_bot = null
			_stage = 2
			_last = Time.get_ticks_usec()
		2:
			var now := Time.get_ticks_usec()
			_times.append((now - _last) / 1000.0)
			_last = now
			if _times.size() >= _frames:
				_times.sort()
				var sum := 0.0
				for t in _times: sum += t
				print("perf_probe L%d: wave %d, enemies %d, towers %d | frame ms avg %.2f  p50 %.2f  p95 %.2f  max %.2f  (%s)" % [
					_level, _ctrl.waves.index + 1, _ctrl.alive_enemy_count(), _ctrl.towers.size(), sum / _times.size(),
					_times[_times.size() / 2], _times[int(_times.size() * 0.95)], _times[_times.size() - 1],
					RenderingServer.get_video_adapter_name()])
				quit(0)
				return true
	return false
